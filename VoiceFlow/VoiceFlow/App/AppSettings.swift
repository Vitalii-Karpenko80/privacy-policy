import Foundation
import Observation

/// User-configurable settings (AI provider, model). API key lives in the Keychain.
@Observable
final class AppSettings {
    private enum Keys {
        static let useMock = "vf.useMockAI"
        static let model = "vf.model"
        static let apiKey = "vf.apiKey" // Keychain account
    }

    /// Default model per Anthropic guidance. Users may pick a cheaper/faster model
    /// (e.g. claude-sonnet-5, claude-haiku-4-5) in Settings.
    static let defaultModel = "claude-opus-5"

    var useMockAI: Bool {
        didSet { UserDefaults.standard.set(useMockAI, forKey: Keys.useMock) }
    }

    var model: String {
        didSet { UserDefaults.standard.set(model, forKey: Keys.model) }
    }

    var apiKey: String {
        didSet {
            if apiKey.isEmpty { Keychain.remove(Keys.apiKey) }
            else { Keychain.set(apiKey, for: Keys.apiKey) }
        }
    }

    init() {
        let defaults = UserDefaults.standard
        // Default to the offline mock until an API key is provided.
        self.useMockAI = defaults.object(forKey: Keys.useMock) as? Bool ?? true
        self.model = defaults.string(forKey: Keys.model) ?? Self.defaultModel
        self.apiKey = Keychain.get(Keys.apiKey) ?? ""
    }

    var hasAPIKey: Bool { !apiKey.isEmpty }

    /// Builds the active AI service from current settings.
    func makeAIService() -> AIService {
        if useMockAI || apiKey.isEmpty {
            return MockAIService()
        }
        return AnthropicAIService(apiKey: apiKey, model: model)
    }
}
