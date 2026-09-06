# VoiceFlow (iOS)

Голосовой AI-органайзер для iPhone.
**Сказал → AI понял → показал → подтвердил → готово.**

Пользователь говорит естественным языком; приложение расшифровывает речь,
отправляет **только текст команды** в AI, получает **строго структурированные данные**
(события, задачи, контакты, заметки) и после подтверждения пользователем
раскладывает их по системным приложениям (Calendar, Reminders) и собственному
хранилищу заметок.

> Ключевой архитектурный принцип: **LLM не управляет календарём напрямую.**
> LLM возвращает структуру → Swift-код её проверяет → и сам выполняет действия.

## Требования

- Xcode 16+
- iOS 18.0+ (SwiftUI + SwiftData)
- Реальное устройство рекомендуется для записи речи (Speech + микрофон).

## Как открыть проект

Готовый `VoiceFlow.xcodeproj` уже лежит в репозитории — **просто откройте его**:

```bash
git clone https://github.com/Vitalii-Karpenko80/privacy-policy.git
cd privacy-policy && git checkout claude/voiceflow-ios-app
open VoiceFlow/VoiceFlow.xcodeproj
```

или дважды кликните по `VoiceFlow/VoiceFlow.xcodeproj` в Finder. Затем в Xcode
выберите симулятор (например, iPhone 16) и нажмите ▶️ (Cmd+R).

> Проект использует формат «синхронизированных папок» Xcode 16 — все `.swift`
> файлы подхватываются из папки `VoiceFlow/` автоматически, ничего добавлять
> вручную не нужно. Нужен **Xcode 16+** (для iOS 18 SDK).

### Запуск на своём iPhone

Для записи речи нужен реальный iPhone (в симуляторе микрофон/распознавание
не работают). В Xcode: таргет **VoiceFlow → Signing & Capabilities →**
выберите свой **Team** (Apple ID) и при необходимости поменяйте
`Bundle Identifier` на уникальный (например, `com.твоёимя.voiceflow`).

### Альтернатива: XcodeGen

Проект также описан в `project.yml`. Если предпочитаете генерировать `.xcodeproj`:
`brew install xcodegen && cd VoiceFlow && xcodegen generate`.

## Структура

```
VoiceFlow/
  App/            — точка входа, корневая навигация, DI-контейнер
  Models/         — ParsedIntent (схема ответа AI), VoiceCommand, VoiceNote…
  Services/       — Speech, AI, Calendar, Reminder, Contacts, Permissions
  Features/       — Home, Recording, Review, History, Contacts, Settings (MVVM)
  DesignSystem/   — палитра и переиспользуемые компоненты
  Resources/      — Info.plist, Assets
```

## Основной цикл (MVP)

`Voice → Speech-to-Text → AIService → ParsedIntent → Review → Execute`

1. **Home** — таймлайн «Сегодня» + большая кнопка микрофона.
2. **Recording** — запись, живая расшифровка, затем `Processing…`.
3. **Review** — «Я понял так»: карточки события/задачи/контакта, кнопка «Добавить всё».
4. **Execute** — EventKit (событие + напоминание), Reminders (задача),
   VoiceFlow Notes, связь с контактом; команда сохраняется в Историю.

## AIService

- Протокол `AIService` c единственным методом `parse(command:contactCandidates:now:)`.
- `MockAIService` — офлайн-эвристика, чтобы приложение запускалось **без ключа и сети**
  (для демо основного потока). Помечен как заглушка.
- `AnthropicAIService` — реальный вызов Claude Messages API, возвращающий JSON строго
  по схеме `ParsedIntent`. Выбирается в **Settings**; ключ хранится в Keychain.

## Privacy (по ТЗ — приватность как часть продукта)

- Local-first: заметки, история и связи хранятся локально (SwiftData).
- В AI уходит **только текст команды** + при необходимости имена контактов-кандидатов,
  а не вся телефонная книга.
- Разрешения запрашиваются по мере необходимости, а не все сразу при первом запуске.

## Статус

Это стартовый **скелет MVP**: основной поток реализован, часть путей помечена `TODO`.
Собирается в Xcode; на Linux/CI без Xcode компиляция не проверялась.
