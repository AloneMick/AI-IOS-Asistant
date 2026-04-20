import SwiftUI
import AVFoundation

// MARK: - SettingsView

struct SettingsView: View {

    @Bindable var settings: AppSettings
    @State private var showAPIKey = false
    @State private var showSystemPromptEditor = false
    @State private var testingConnection = false
    @State private var connectionStatus: ConnectionStatus?

    enum ConnectionStatus { case success, failure(String) }

    var body: some View {
        NavigationStack {
            List {

                // MARK: API
                Section {
                    apiKeyRow
                    modelPickerRow
                    Button("Probar conexión") { Task { await testConnection() } }
                        .disabled(testingConnection || !settings.isConfigured)
                    if let status = connectionStatus { connectionStatusRow(status) }
                } header: {
                    Label("API de OpenAI", systemImage: "key.fill")
                } footer: {
                    Text("Obtén tu API Key en platform.openai.com")
                }

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

    // MARK: - API Key

    private var apiKeyRow: some View {
        HStack {
            Image(systemName: "key")
                .foregroundStyle(.orange)
            if showAPIKey {
                TextField("sk-...", text: $settings.apiKey)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } else {
                SecureField("API Key", text: $settings.apiKey)
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

    // MARK: - Model picker

    private var modelPickerRow: some View {
        HStack {
            Image(systemName: "cpu")
                .foregroundStyle(.blue)
            Picker("Modelo", selection: $settings.selectedModelID) {
                ForEach(AIModel.all) { model in
                    VStack(alignment: .leading) {
                        Text(model.displayName)
                        Text(model.description).font(.caption).foregroundStyle(.secondary)
                    }
                    .tag(model.id)
                }
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
            Text("Versión 1.0 • Powered by OpenAI GPT-4o")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Más potente que Apple Intelligence")
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
