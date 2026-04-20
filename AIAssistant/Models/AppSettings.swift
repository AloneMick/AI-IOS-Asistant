import Foundation
import Observation

// MARK: - AI Model

struct AIModel: Identifiable, Hashable {
    let id: String
    let displayName: String
    let supportsVision: Bool
    let contextWindow: Int
    let description: String
}

extension AIModel {
    static let gpt4o = AIModel(
        id: "gpt-4o",
        displayName: "GPT-4o",
        supportsVision: true,
        contextWindow: 128_000,
        description: "Más rápido y potente. Soporta imágenes."
    )
    static let gpt4oMini = AIModel(
        id: "gpt-4o-mini",
        displayName: "GPT-4o Mini",
        supportsVision: true,
        contextWindow: 128_000,
        description: "Rápido y económico."
    )
    static let gpt4turbo = AIModel(
        id: "gpt-4-turbo",
        displayName: "GPT-4 Turbo",
        supportsVision: true,
        contextWindow: 128_000,
        description: "Alta capacidad de razonamiento."
    )
    static let gpt35turbo = AIModel(
        id: "gpt-3.5-turbo",
        displayName: "GPT-3.5 Turbo",
        supportsVision: false,
        contextWindow: 16_385,
        description: "Respuestas muy rápidas."
    )

    static let all: [AIModel] = [.gpt4o, .gpt4oMini, .gpt4turbo, .gpt35turbo]
}

// MARK: - AppSettings

@Observable
final class AppSettings {

    // MARK: Keys
    private enum Keys {
        static let apiKey           = "openai_api_key"
        static let selectedModelID  = "selected_model_id"
        static let systemPrompt     = "system_prompt"
        static let temperature      = "temperature"
        static let maxTokens        = "max_tokens"
        static let voiceEnabled     = "voice_enabled"
        static let autoSpeak        = "auto_speak"
        static let hapticFeedback   = "haptic_feedback"
        static let contextWindow    = "context_window"
        static let streamingEnabled = "streaming_enabled"
        static let selectedVoice    = "selected_voice"
        static let speechRate       = "speech_rate"
        static let accentColor      = "accent_color"
        static let darkModeForced   = "dark_mode_forced"
    }

    // MARK: Properties
    var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: Keys.apiKey) }
    }
    var selectedModelID: String {
        didSet { UserDefaults.standard.set(selectedModelID, forKey: Keys.selectedModelID) }
    }
    var systemPrompt: String {
        didSet { UserDefaults.standard.set(systemPrompt, forKey: Keys.systemPrompt) }
    }
    var temperature: Double {
        didSet { UserDefaults.standard.set(temperature, forKey: Keys.temperature) }
    }
    var maxTokens: Int {
        didSet { UserDefaults.standard.set(maxTokens, forKey: Keys.maxTokens) }
    }
    var voiceEnabled: Bool {
        didSet { UserDefaults.standard.set(voiceEnabled, forKey: Keys.voiceEnabled) }
    }
    var autoSpeak: Bool {
        didSet { UserDefaults.standard.set(autoSpeak, forKey: Keys.autoSpeak) }
    }
    var hapticFeedback: Bool {
        didSet { UserDefaults.standard.set(hapticFeedback, forKey: Keys.hapticFeedback) }
    }
    var contextWindowSize: Int {
        didSet { UserDefaults.standard.set(contextWindowSize, forKey: Keys.contextWindow) }
    }
    var streamingEnabled: Bool {
        didSet { UserDefaults.standard.set(streamingEnabled, forKey: Keys.streamingEnabled) }
    }
    var selectedVoiceIdentifier: String {
        didSet { UserDefaults.standard.set(selectedVoiceIdentifier, forKey: Keys.selectedVoice) }
    }
    var speechRate: Float {
        didSet { UserDefaults.standard.set(speechRate, forKey: Keys.speechRate) }
    }

    // MARK: Computed
    var selectedModel: AIModel {
        AIModel.all.first { $0.id == selectedModelID } ?? .gpt4o
    }

    var isConfigured: Bool { !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    // MARK: Init
    init() {
        let ud = UserDefaults.standard
        apiKey              = ud.string(forKey: Keys.apiKey) ?? ""
        selectedModelID     = ud.string(forKey: Keys.selectedModelID) ?? AIModel.gpt4o.id
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
}
