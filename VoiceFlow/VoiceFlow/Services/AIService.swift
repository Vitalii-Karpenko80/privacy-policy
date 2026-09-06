import Foundation

/// Turns raw command text into a validated `ParsedIntent`.
///
/// The AI layer only ever returns structure — it never touches the calendar,
/// reminders or contacts. Swift validates the result and performs the actions.
protocol AIService {
    func parse(command: String, contactCandidates: [String], now: Date) async throws -> ParsedIntent
}

enum AIServiceError: LocalizedError {
    case missingAPIKey
    case badResponse(status: Int, body: String)
    case refused(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Не задан API-ключ. Добавьте его в Настройках."
        case .badResponse(let status, _): return "Сервер AI ответил ошибкой (\(status))."
        case .refused(let reason): return "Запрос отклонён: \(reason)"
        case .decoding(let detail): return "Не удалось разобрать ответ AI: \(detail)"
        }
    }
}

// MARK: - Prompt

enum IntentPrompt {
    /// System prompt: instructs the model to emit ONLY the ParsedIntent JSON.
    static func system(now: Date, contactCandidates: [String]) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        let today = iso.string(from: now)

        let weekdayFmt = DateFormatter()
        weekdayFmt.locale = Locale(identifier: "ru_RU")
        weekdayFmt.dateFormat = "EEEE"
        let weekday = weekdayFmt.string(from: now)

        let candidates = contactCandidates.isEmpty
            ? "(нет кандидатов)"
            : contactCandidates.joined(separator: ", ")

        return """
        Ты — парсер намерений голосового органайзера. Пользователь диктует задачи на \
        естественном языке (обычно по-русски). Преобразуй его команду в СТРОГО \
        структурированный JSON и верни ТОЛЬКО JSON, без пояснений и без markdown.

        Сегодня: \(today) (\(weekday)). Разрешай относительные даты («завтра», «в пятницу», \
        «через час») относительно этой даты в часовом поясе устройства.

        Кандидаты из контактов пользователя: \(candidates).
        Если в команде упомянут человек, соотнеси имя с наиболее подходящим кандидатом; \
        имя из контактов используй как есть, иначе оставь как в речи.

        Схема ответа:
        {
          "events":   [{ "title": string, "date": "yyyy-MM-dd"|null, "time": "HH:mm"|null, "notes": string|null, "reminderMinutes": number|null }],
          "tasks":    [{ "title": string, "dueRelation": "before_event"|"today"|"tomorrow"|null, "dueDate": "yyyy-MM-dd"|null, "dueTime": "HH:mm"|null }],
          "contacts": [{ "name": string }],
          "notes":    [{ "text": string }]
        }

        Правила:
        - Возвращай пустые массивы, если чего-то нет. Никогда не выдумывай события.
        - «напомни за час» → reminderMinutes: 60; «за 15 минут» → 15.
        - Короткие пометки «обсудить X» клади в notes события или в отдельную заметку.
        - Время в 24-часовом формате.
        """
    }
}

// MARK: - Anthropic (Claude Messages API) implementation

/// Calls the Claude Messages API over raw HTTPS (no official Swift SDK).
///
/// Privacy: only the command text and contact *candidate names* are sent — never
/// the full address book (ТЗ §19).
struct AnthropicAIService: AIService {
    var apiKey: String
    var model: String
    var endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    var anthropicVersion = "2023-06-01"

    func parse(command: String, contactCandidates: [String], now: Date) async throws -> ParsedIntent {
        guard !apiKey.isEmpty else { throw AIServiceError.missingAPIKey }

        let body = RequestBody(
            model: model,
            max_tokens: 1024,
            system: IntentPrompt.system(now: now, contactCandidates: contactCandidates),
            messages: [.init(role: "user", content: command)],
            output_config: .init(effort: "low")
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIServiceError.badResponse(status: -1, body: "")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AIServiceError.badResponse(status: http.statusCode,
                                             body: String(data: data, encoding: .utf8) ?? "")
        }

        let decoded = try JSONDecoder().decode(APIResponse.self, from: data)
        if decoded.stop_reason == "refusal" {
            throw AIServiceError.refused(decoded.stop_details?.explanation ?? "safety")
        }
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text else {
            throw AIServiceError.decoding("пустой ответ")
        }

        let json = Self.extractJSON(from: text)
        guard let jsonData = json.data(using: .utf8) else {
            throw AIServiceError.decoding("нечитаемый JSON")
        }
        do {
            return try JSONDecoder().decode(ParsedIntent.self, from: jsonData)
        } catch {
            throw AIServiceError.decoding(error.localizedDescription)
        }
    }

    /// Strips markdown fences and grabs the outermost JSON object if the model wrapped it.
    static func extractJSON(from text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            s = s.replacingOccurrences(of: "```json", with: "")
                 .replacingOccurrences(of: "```", with: "")
                 .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let open = s.firstIndex(of: "{"), let close = s.lastIndex(of: "}") {
            return String(s[open...close])
        }
        return s
    }

    // Wire types
    private struct RequestBody: Encodable {
        let model: String
        let max_tokens: Int
        let system: String
        let messages: [Message]
        let output_config: OutputConfig
        struct Message: Encodable { let role: String; let content: String }
        struct OutputConfig: Encodable { let effort: String }
    }

    private struct APIResponse: Decodable {
        let content: [Block]
        let stop_reason: String?
        let stop_details: StopDetails?
        struct Block: Decodable { let type: String; let text: String? }
        struct StopDetails: Decodable { let explanation: String? }
    }
}

// MARK: - Offline mock (demo without a key or network)

/// Lightweight heuristic parser so the core flow is demoable without a backend.
///
/// This is intentionally a **stub** — real parsing is `AnthropicAIService`.
struct MockAIService: AIService {
    func parse(command: String, contactCandidates: [String], now: Date) async throws -> ParsedIntent {
        try? await Task.sleep(for: .milliseconds(600)) // mimic "Processing…"
        let lower = command.lowercased()
        var intent = ParsedIntent()

        // Reminder ("напомни за час / за N минут")
        var reminderMinutes: Int?
        if lower.contains("напомни") {
            if lower.contains("за час") { reminderMinutes = 60 }
            else if let m = Self.firstNumber(after: "за", in: lower, unitHint: "минут") { reminderMinutes = m }
            else { reminderMinutes = 60 }
        }

        // Contact: prefer a known candidate whose name appears in the text.
        let matchedContact = contactCandidates.first { lower.contains($0.lowercased()) }
        if let name = matchedContact {
            intent.contacts.append(.init(name: name))
        }

        // Event: meeting / site visit keywords.
        if ["встреч", "объект", "созвон", "приём", "прием"].contains(where: lower.contains) {
            var title = "Встреча"
            if let name = matchedContact { title = "Встреча с \(name)" }
            intent.events.append(.init(
                title: title,
                date: nil,
                time: nil,
                notes: nil,
                reminderMinutes: reminderMinutes
            ))
        }

        // Task: "надо / нужно / проверить / заказать / купить …"
        for verb in ["проверить", "заказать", "купить", "отправить", "позвонить"] {
            if let range = command.range(of: verb, options: .caseInsensitive) {
                let tail = command[range.lowerBound...]
                    .split(separator: ",").first.map(String.init) ?? verb
                intent.tasks.append(.init(
                    title: tail.trimmingCharacters(in: .whitespaces).capitalizedFirst,
                    dueRelation: lower.contains("до встречи") ? "before_event" : nil,
                    dueDate: nil,
                    dueTime: nil
                ))
                break
            }
        }

        if intent.isEmpty {
            intent.notes.append(.init(text: command))
        }
        return intent
    }

    private static func firstNumber(after keyword: String, in text: String, unitHint: String) -> Int? {
        let tokens = text.split(separator: " ")
        guard let idx = tokens.firstIndex(where: { $0.contains(keyword) }) else { return nil }
        for token in tokens[idx...] {
            if let n = Int(token) { return n }
        }
        return nil
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
