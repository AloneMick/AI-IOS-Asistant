import SwiftUI
import AVFoundation

// MARK: - SettingsView

struct SettingsView: View {

    @Bindable var settings: AppSettings
    @State private var showAPIKey = false
    @State private var testingConnection = false
    @State private var connectionStatus: ConnectionStatus?
    @State private var showProviderInfo = false

    enum ConnectionStatus { case success, failure(String) }

    var body: some View {
        NavigationStack {
            List {

                // MARK: Provider picker
                providerSection

                // MARK: Model picker
                modelSection

                // MARK: AI Behavior
                Section {
                    NavigationLink("System Prompt") {
                        systemPromptEditorView
                    }
                    temperatureRow
                    maxTokensRow
                    contextWindowRow
                    Toggle("Respuestas en streaming", isOn: $settings.streamingEnabled)
                } header: {
                    Label("Comportamiento IA", systemImage: "brain")
                }

                // MARK: Voice
                Section {
                    Toggle("Voz habilitada", isOn: $settings.voiceEnabled)
                    if settings.voiceEnabled {
                        Toggle("Responder automáticamente en voz", isOn: $settings.autoSpeak)
                        voicePickerRow
                        speechRateRow
                    }
                } header: {
                    Label("Voz", systemImage: "waveform")
                }

                // MARK: Interface
                Section {
                    Toggle("Feedback háptico", isOn: $settings.hapticFeedback)
                } header: {
                    Label("Interfaz", systemImage: "iphone")
                }

                // MARK: About
                Section {
                    aboutRow
                } header: {
                    Label("Acerca de", systemImage: "info.circle")
                }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Provider section

    private var providerSection: some View {
        Section {
            // Provider picker grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(AIProvider.allCases) { provider in
                    providerCard(provider)
                }
            }
            .padding(.vertical, 4)
            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))

            // Info about selected provider
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                    .padding(.top, 2)
                Text(settings.selectedProvider.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // API Key row (only for providers that need it)
            if settings.selectedProvider.requiresAPIKey {
                apiKeyRow

                if !settings.selectedProvider.apiKeyURL.isEmpty {
                    Link(destination: URL(string: settings.selectedProvider.apiKeyURL)!) {
                        HStack {
                            Image(systemName: "safari")
                                .foregroundStyle(.blue)
                            Text("Obtener API Key →")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }

            // Host override for custom endpoint
            if settings.selectedProvider == .custom {
                hostRow(label: "Endpoint base", placeholder: "https://tu-servidor.com/v1", binding: $settings.customEndpoint)
            }

            // Connection test
            Button {
                Task { await testConnection() }
            } label: {
                HStack {
                    if testingConnection {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: "wifi")
                    }
                    Text(testingConnection ? "Probando…" : "Probar conexión")
                }
            }
            .disabled(testingConnection || !settings.isConfigured)

            if let status = connectionStatus { connectionStatusRow(status) }

        } header: {
            Label("Proveedor de IA", systemImage: "cpu.fill")
        }
    }

    private func providerCard(_ provider: AIProvider) -> some View {
        let isSelected = settings.selectedProvider == provider
        return Button {
            settings.selectedProvider = provider
            connectionStatus = nil
        } label: {
            VStack(spacing: 6) {
                Image(systemName: provider.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : .primary)
                Text(provider.displayName)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                if provider.isOpenSource {
                    Text("Open Source")
                        .font(.system(size: 9))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.25) : Color.green.opacity(0.15))
                        .foregroundStyle(isSelected ? .white : .green)
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected
                        ? LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color(UIColor.secondarySystemGroupedBackground)], startPoint: .top, endPoint: .bottom)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color(UIColor.separator).opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Model section

    private var modelSection: some View {
        Section {
            ForEach(settings.selectedProvider.availableModels) { model in
                Button {
                    settings.selectedModelID = model.id
                } label: {
                    HStack(spacing: 12) {
                        // Selection indicator
                        Image(systemName: settings.selectedModelID == model.id ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(settings.selectedModelID == model.id ? .purple : .secondary)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(model.displayName)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                if model.supportsVision {
                                    Image(systemName: "eye.fill")
                                        .font(.caption)
                                        .foregroundStyle(.teal)
                                }
                                Spacer()
                                Text("\(model.contextWindow / 1000)K ctx")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            Text(model.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            }

            // For Custom endpoint: allow free-text model ID
            if settings.selectedProvider == .custom {
                customModelRow
            }

        } header: {
            Label("Modelo", systemImage: "sparkles")
        } footer: {
            if settings.selectedProvider == .openRouter {
                Text("Los modelos marcados :free no tienen coste. Consulta openrouter.ai para el catálogo completo.")
            } else if settings.selectedProvider == .custom {
                Text("Introduce el ID exacto del modelo que expone tu servidor remoto.")
            }
        }
    }

    private var customModelRow: some View {
        HStack {
            Image(systemName: "keyboard")
                .foregroundStyle(.orange)
            TextField("ID de modelo personalizado", text: $settings.selectedModelID)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(.caption)
        }
    }

    // MARK: - API Key

    private var apiKeyRow: some View {
        HStack {
            Image(systemName: "key")
                .foregroundStyle(.orange)
            if showAPIKey {
                TextField(settings.selectedProvider.apiKeyPlaceholder, text: $settings.apiKey)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } else {
                SecureField(settings.selectedProvider.apiKeyPlaceholder, text: $settings.apiKey)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            Button {
                showAPIKey.toggle()
            } label: {
                Image(systemName: showAPIKey ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Host row (Custom endpoint)

    private func hostRow(label: String, placeholder: String, binding: Binding<String>) -> some View {
        HStack {
            Image(systemName: "network")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(placeholder, text: binding)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.body)
            }
        }
    }

    // MARK: - Temperature

    private var temperatureRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "thermometer.medium")
                    .foregroundStyle(.red)
                Text("Temperatura")
                Spacer()
                Text(String(format: "%.1f", settings.temperature))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $settings.temperature, in: 0...2, step: 0.1)
            HStack {
                Text("Preciso").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("Creativo").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Max tokens

    private var maxTokensRow: some View {
        HStack {
            Image(systemName: "text.word.spacing")
                .foregroundStyle(.green)
            Text("Tokens máx.")
            Spacer()
            Picker("", selection: $settings.maxTokens) {
                ForEach([512, 1024, 2048, 4096, 8192, 16384], id: \.self) { t in
                    Text("\(t)").tag(t)
                }
            }
            .labelsHidden()
        }
    }

    // MARK: - Context window

    private var contextWindowRow: some View {
        HStack {
            Image(systemName: "list.number")
                .foregroundStyle(.purple)
            Text("Mensajes de contexto")
            Spacer()
            Picker("", selection: $settings.contextWindowSize) {
                ForEach([5, 10, 20, 40, 80], id: \.self) { n in
                    Text("\(n)").tag(n)
                }
            }
            .labelsHidden()
        }
    }

    // MARK: - System prompt editor

    private var systemPromptEditorView: some View {
        VStack {
            TextEditor(text: $settings.systemPrompt)
                .font(.body)
                .padding(8)
            HStack {
                Button("Restablecer por defecto") {
                    settings.systemPrompt = AppSettings.defaultSystemPrompt
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .navigationTitle("System Prompt")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Voice picker

    private var voicePickerRow: some View {
        HStack {
            Image(systemName: "person.wave.2")
                .foregroundStyle(.teal)
            Picker("Voz", selection: $settings.selectedVoiceIdentifier) {
                Text("Automática").tag("")
                ForEach(AVSpeechSynthesisVoice.speechVoices().prefix(20), id: \.identifier) { voice in
                    Text("\(voice.name) (\(voice.language))").tag(voice.identifier)
                }
            }
        }
    }

    // MARK: - Speech rate

    private var speechRateRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "gauge.with.dots.needle.50percent")
                    .foregroundStyle(.indigo)
                Text("Velocidad de voz")
                Spacer()
                Text(speechRateLabel)
                    .foregroundStyle(.secondary)
            }
            Slider(value: $settings.speechRate, in: AVSpeechUtteranceMinimumSpeechRate...AVSpeechUtteranceMaximumSpeechRate)
        }
    }

    private var speechRateLabel: String {
        let min = AVSpeechUtteranceMinimumSpeechRate
        let max = AVSpeechUtteranceMaximumSpeechRate
        let pct = (settings.speechRate - min) / (max - min)
        if pct < 0.33 { return "Lenta" }
        if pct < 0.66 { return "Normal" }
        return "Rápida"
    }

    // MARK: - Connection test

    private func testConnection() async {
        testingConnection = true
        connectionStatus = nil
        do {
            let testMsg = Message(role: .user, content: "Responde solo con: OK")
            let result = try await AIService.shared.completion(messages: [testMsg], settings: settings)
            connectionStatus = result.contains("OK") || !result.isEmpty ? .success : .failure("Respuesta inesperada")
        } catch {
            connectionStatus = .failure(error.localizedDescription)
        }
        testingConnection = false
    }

    private func connectionStatusRow(_ status: ConnectionStatus) -> some View {
        HStack {
            switch status {
            case .success:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Conexión exitosa").foregroundStyle(.green)
            case .failure(let msg):
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                Text(msg).foregroundStyle(.red).font(.caption)
            }
        }
    }

    // MARK: - About

    private var aboutRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("AI iOS Assistant")
                .font(.headline)
            Text("Versión 1.0 • Multi-proveedor: OpenAI, Groq, OpenRouter, Together AI, Custom")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Más potente que Apple Intelligence · iOS 18+ · Open Source friendly")
                .font(.caption2)
                .foregroundStyle(.purple)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    SettingsView(settings: AppSettings())
}
