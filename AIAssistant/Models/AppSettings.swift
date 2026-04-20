import Foundation
import Observation

// MARK: - AppSettings

@Observable
final class AppSettings {

    // MARK: UserDefaults Keys
    private enum Keys {
        static let selectedProvider     = "selected_provider"
        static let selectedModelID      = "selected_model_id"
        static let apiKeys              = "provider_api_keys"   // JSON dict [provider.rawValue: key]
        static let customEndpoint       = "custom_endpoint"
        static let systemPrompt         = "system_prompt"
        static let temperature          = "temperature"
        static let maxTokens            = "max_tokens"
        static let voiceEnabled         = "voice_enabled"
        static let autoSpeak            = "auto_speak"
        static let hapticFeedback       = "haptic_feedback"
        static let contextWindow        = "context_window"
        static let streamingEnabled     = "streaming_enabled"
        static let selectedVoice        = "selected_voice"
        static let speechRate           = "speech_rate"
    }

    // MARK: Provider & model
    var selectedProvider: AIProvider {
        didSet {
            UserDefaults.standard.set(selectedProvider.rawValue, forKey: Keys.selectedProvider)
            // Auto-select the first model of the new provider if the current model doesn't belong to it
            if !selectedProvider.availableModels.contains(where: { $0.id == selectedModelID }) {
                selectedModelID = selectedProvider.defaultModelID
            }
        }
    }

    var selectedModelID: String {
        didSet { UserDefaults.standard.set(selectedModelID, forKey: Keys.selectedModelID) }
    }

    // MARK: Per-provider API keys
    /// Stored as JSON dictionary in UserDefaults so each provider has its own key.
    var apiKeys: [String: String] {
        didSet { saveAPIKeys() }
    }

    /// Convenience: API key for the currently selected provider
    var apiKey: String {
        get { apiKeys[selectedProvider.rawValue] ?? "" }
        set {
            apiKeys[selectedProvider.rawValue] = newValue
            saveAPIKeys()
        }
    }

    // MARK: Custom endpoints
    var customEndpoint: String {
        didSet { UserDefaults.standard.set(customEndpoint, forKey: Keys.customEndpoint) }
    }

    // MARK: AI behavior
    var systemPrompt: String {
        didSet { UserDefaults.standard.set(systemPrompt, forKey: Keys.systemPrompt) }
    }
    var temperature: Double {
        didSet { UserDefaults.standard.set(temperature, forKey: Keys.temperature) }
    }
    var maxTokens: Int {
        didSet { UserDefaults.standard.set(maxTokens, forKey: Keys.maxTokens) }
    }
    var contextWindowSize: Int {
        didSet { UserDefaults.standard.set(contextWindowSize, forKey: Keys.contextWindow) }
    }
    var streamingEnabled: Bool {
        didSet { UserDefaults.standard.set(streamingEnabled, forKey: Keys.streamingEnabled) }
    }

    // MARK: Voice
    var voiceEnabled: Bool {
        didSet { UserDefaults.standard.set(voiceEnabled, forKey: Keys.voiceEnabled) }
    }
    var autoSpeak: Bool {
        didSet { UserDefaults.standard.set(autoSpeak, forKey: Keys.autoSpeak) }
    }
    var selectedVoiceIdentifier: String {
        didSet { UserDefaults.standard.set(selectedVoiceIdentifier, forKey: Keys.selectedVoice) }
    }
    var speechRate: Float {
        didSet { UserDefaults.standard.set(speechRate, forKey: Keys.speechRate) }
    }

    // MARK: Interface
    var hapticFeedback: Bool {
        didSet { UserDefaults.standard.set(hapticFeedback, forKey: Keys.hapticFeedback) }
    }

    // MARK: Computed helpers

    var selectedModel: AIModel {
        selectedProvider.availableModels.first { $0.id == selectedModelID }
            ?? selectedProvider.availableModels.first
            ?? AIModel(id: selectedModelID, displayName: selectedModelID,
                       supportsVision: false, contextWindow: 4096, description: "")
    }

    /// The effective base URL for the current provider (respects user-overridden custom endpoint)
    var activeBaseURL: String {
        switch selectedProvider {
        case .custom: return customEndpoint
        default:      return selectedProvider.defaultBaseURL
        }
    }

    var isConfigured: Bool {
        if !selectedProvider.requiresAPIKey { return !activeBaseURL.isEmpty }
        return !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Init
    init() {
        let ud = UserDefaults.standard

        let providerRaw = ud.string(forKey: Keys.selectedProvider) ?? AIProvider.openAI.rawValue
        selectedProvider    = AIProvider(rawValue: providerRaw) ?? .openAI
        selectedModelID     = ud.string(forKey: Keys.selectedModelID) ?? AIProvider.openAI.defaultModelID
        apiKeys             = AppSettings.loadAPIKeys()
        customEndpoint      = ud.string(forKey: Keys.customEndpoint) ?? ""
        systemPrompt        = ud.string(forKey: Keys.systemPrompt) ?? AppSettings.defaultSystemPrompt
        temperature         = ud.object(forKey: Keys.temperature) as? Double ?? 0.7
        maxTokens           = ud.object(forKey: Keys.maxTokens) as? Int ?? 4096
        voiceEnabled        = ud.object(forKey: Keys.voiceEnabled) as? Bool ?? true
        autoSpeak           = ud.object(forKey: Keys.autoSpeak) as? Bool ?? false
        hapticFeedback      = ud.object(forKey: Keys.hapticFeedback) as? Bool ?? true
        contextWindowSize   = ud.object(forKey: Keys.contextWindow) as? Int ?? 20
        streamingEnabled    = ud.object(forKey: Keys.streamingEnabled) as? Bool ?? true
        selectedVoiceIdentifier = ud.string(forKey: Keys.selectedVoice) ?? ""
        speechRate          = ud.object(forKey: Keys.speechRate) as? Float ?? 0.5
    }

    // MARK: Default system prompt
    static let defaultSystemPrompt = """
    Eres un asistente de IA de última generación, más inteligente y capaz que cualquier asistente existente. \
    Tienes acceso a conocimiento avanzado en todas las áreas: ciencia, tecnología, arte, filosofía, matemáticas, medicina, derecho y más. \
    Respondes de forma clara, precisa y adaptada al nivel del usuario. \
    Puedes analizar imágenes, resolver problemas complejos, escribir código, generar texto creativo, y ayudar con tareas del dispositivo. \
    Siempre buscas dar la respuesta más útil, completa y honesta posible. \
    Hablas el idioma que el usuario use contigo.
    """

    // MARK: Private

    private func saveAPIKeys() {
        guard let data = try? JSONSerialization.data(withJSONObject: apiKeys) else { return }
        UserDefaults.standard.set(data, forKey: Keys.apiKeys)
    }

    private static func loadAPIKeys() -> [String: String] {
        guard
            let data = UserDefaults.standard.data(forKey: Keys.apiKeys),
            let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else { return [:] }
        return dict
    }
}
