import SwiftUI

struct SettingsView: View {
    @Environment(AppServices.self) private var services

    var body: some View {
        @Bindable var settings = services.settings
        NavigationStack {
            Form {
                Section {
                    Toggle("Офлайн-режим (демо-парсер)", isOn: $settings.useMockAI)
                } header: {
                    Text("AI")
                } footer: {
                    Text("В офлайн-режиме команды разбираются простым локальным парсером — без ключа и без сети. Для полноценного разбора выключите режим и укажите ключ.")
                }

                if !settings.useMockAI {
                    Section("Claude API") {
                        SecureField("API-ключ", text: $settings.apiKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                        TextField("Модель", text: $settings.model)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    Section {
                        Text("Модель по умолчанию — claude-opus-5. Для скорости и цены можно указать claude-sonnet-5 или claude-haiku-4-5.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section("Приватность") {
                    Label("Заметки, история и связи хранятся только на устройстве.", systemImage: "lock.fill")
                        .font(.subheadline)
                    Label("В AI уходит только текст команды и имена кандидатов из контактов — не вся телефонная книга.", systemImage: "hand.raised.fill")
                        .font(.subheadline)
                }

                Section {
                    LabeledContent("Версия", value: "0.1.0 (MVP)")
                }
            }
            .navigationTitle("Настройки")
        }
    }
}
