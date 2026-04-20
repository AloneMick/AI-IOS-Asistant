import Foundation

// MARK: - AIProvider

/// Represents a cloud backend that serves chat completions.
/// All providers listed here expose an OpenAI-compatible `/v1/chat/completions` endpoint,
/// which means the same AIService request builder works for all of them — only the
/// base URL, authentication header, and available models differ.
///
/// Note: This app targets iOS 18+. Local desktop servers such as Ollama and LM Studio
/// run on macOS/Linux/Windows and are therefore not supported.
enum AIProvider: String, CaseIterable, Identifiable, Codable {
    case openAI      = "openai"
    case groq        = "groq"
    case openRouter  = "openrouter"
    case together    = "together"
    case custom      = "custom"

    var id: String { rawValue }

    // MARK: Display

    var displayName: String {
        switch self {
        case .openAI:     return "OpenAI"
        case .groq:       return "Groq"
        case .openRouter: return "OpenRouter"
        case .together:   return "Together AI"
        case .custom:     return "Endpoint personalizado"
        }
    }

    var icon: String {
        switch self {
        case .openAI:     return "sparkles"
        case .groq:       return "bolt.fill"
        case .openRouter: return "arrow.triangle.2.circlepath"
        case .together:   return "person.2.fill"
        case .custom:     return "gear.badge"
        }
    }

    var isOpenSource: Bool {
        switch self {
        case .openAI:                          return false
        case .groq, .openRouter, .together,
             .custom:                          return true
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .custom: return false
        default:      return true
        }
    }

    var apiKeyPlaceholder: String {
        switch self {
        case .openAI:     return "sk-..."
        case .groq:       return "gsk_..."
        case .openRouter: return "sk-or-..."
        case .together:   return "together-..."
        default:          return "API Key"
        }
    }

    var apiKeyURL: String {
        switch self {
        case .openAI:     return "https://platform.openai.com/api-keys"
        case .groq:       return "https://console.groq.com/keys"
        case .openRouter: return "https://openrouter.ai/keys"
        case .together:   return "https://api.together.ai/settings/api-keys"
        default:          return ""
        }
    }

    /// Default base URL (can be overridden by the user for custom endpoints)
    var defaultBaseURL: String {
        switch self {
        case .openAI:     return "https://api.openai.com/v1"
        case .groq:       return "https://api.groq.com/openai/v1"
        case .openRouter: return "https://openrouter.ai/api/v1"
        case .together:   return "https://api.together.xyz/v1"
        case .custom:     return ""
        }
    }

    // MARK: Provider description

    var description: String {
        switch self {
        case .openAI:
            return "GPT-4o, GPT-4 Turbo y GPT-3.5. Modelos privados de OpenAI."
        case .groq:
            return "Llama 3, Mixtral, Gemma. Inferencia ultra-rápida en la nube. Tier gratuito disponible."
        case .openRouter:
            return "Más de 200 modelos: Llama, Mistral, Claude, Gemini. Un solo key para todos."
        case .together:
            return "Llama 3, Mistral, Qwen. Modelos open-source en la nube. Tier gratuito."
        case .custom:
            return "Cualquier endpoint remoto compatible con la API de OpenAI (vLLM, Llama.cpp en VPS, etc.)"
        }
    }

    // MARK: Available models

    var availableModels: [AIModel] {
        switch self {
        case .openAI:     return AIModel.openAIModels
        case .groq:       return AIModel.groqModels
        case .openRouter: return AIModel.openRouterModels
        case .together:   return AIModel.togetherModels
        case .custom:     return AIModel.customModels
        }
    }

    var defaultModelID: String {
        availableModels.first?.id ?? ""
    }
}

// MARK: - AIModel catalogs per provider

extension AIModel {

    // OpenAI
    static let openAIModels: [AIModel] = [
        AIModel(id: "gpt-4o",        displayName: "GPT-4o",        supportsVision: true,  contextWindow: 128_000, description: "Más rápido y potente"),
        AIModel(id: "gpt-4o-mini",   displayName: "GPT-4o Mini",   supportsVision: true,  contextWindow: 128_000, description: "Rápido y económico"),
        AIModel(id: "gpt-4-turbo",   displayName: "GPT-4 Turbo",   supportsVision: true,  contextWindow: 128_000, description: "Alta capacidad"),
        AIModel(id: "gpt-3.5-turbo", displayName: "GPT-3.5 Turbo", supportsVision: false, contextWindow: 16_385,  description: "Muy rápido")
    ]

    // Groq — free inference API, open-source models
    static let groqModels: [AIModel] = [
        AIModel(id: "llama-3.3-70b-versatile",  displayName: "Llama 3.3 70B",       supportsVision: false, contextWindow: 128_000, description: "Meta · Mejor calidad en Groq"),
        AIModel(id: "llama-3.1-8b-instant",      displayName: "Llama 3.1 8B Instant",supportsVision: false, contextWindow: 128_000, description: "Meta · Ultra-rápido"),
        AIModel(id: "llama3-70b-8192",            displayName: "Llama 3 70B",          supportsVision: false, contextWindow: 8_192,   description: "Meta · Alta calidad"),
        AIModel(id: "llama3-8b-8192",             displayName: "Llama 3 8B",           supportsVision: false, contextWindow: 8_192,   description: "Meta · Rápido"),
        AIModel(id: "mixtral-8x7b-32768",         displayName: "Mixtral 8x7B",         supportsVision: false, contextWindow: 32_768,  description: "Mistral AI · MoE"),
        AIModel(id: "gemma2-9b-it",               displayName: "Gemma 2 9B",           supportsVision: false, contextWindow: 8_192,   description: "Google · Open"),
        AIModel(id: "gemma-7b-it",                displayName: "Gemma 7B",             supportsVision: false, contextWindow: 8_192,   description: "Google · Compacto")
    ]

    // OpenRouter — aggregator, many free models
    static let openRouterModels: [AIModel] = [
        AIModel(id: "meta-llama/llama-3.3-70b-instruct",        displayName: "Llama 3.3 70B",       supportsVision: false, contextWindow: 128_000, description: "Meta · Gratis"),
        AIModel(id: "meta-llama/llama-3.2-11b-vision-instruct:free", displayName: "Llama 3.2 11B Vision", supportsVision: true, contextWindow: 128_000, description: "Meta · Visión · Gratis"),
        AIModel(id: "mistralai/mistral-7b-instruct:free",        displayName: "Mistral 7B",          supportsVision: false, contextWindow: 32_768,  description: "Mistral AI · Gratis"),
        AIModel(id: "mistralai/mixtral-8x7b-instruct",           displayName: "Mixtral 8x7B",        supportsVision: false, contextWindow: 32_768,  description: "Mistral AI · MoE"),
        AIModel(id: "google/gemma-2-9b-it:free",                 displayName: "Gemma 2 9B",          supportsVision: false, contextWindow: 8_192,   description: "Google · Gratis"),
        AIModel(id: "microsoft/phi-3-mini-128k-instruct:free",   displayName: "Phi-3 Mini 128K",     supportsVision: false, contextWindow: 128_000, description: "Microsoft · Gratis"),
        AIModel(id: "deepseek/deepseek-r1:free",                 displayName: "DeepSeek R1",         supportsVision: false, contextWindow: 65_536,  description: "DeepSeek · Razonamiento · Gratis"),
        AIModel(id: "qwen/qwen-2.5-72b-instruct",                displayName: "Qwen 2.5 72B",        supportsVision: false, contextWindow: 128_000, description: "Alibaba · Potente"),
        AIModel(id: "anthropic/claude-3.5-sonnet",               displayName: "Claude 3.5 Sonnet",   supportsVision: true,  contextWindow: 200_000, description: "Anthropic · Premium")
    ]

    // Together AI
    static let togetherModels: [AIModel] = [
        AIModel(id: "meta-llama/Meta-Llama-3.1-405B-Instruct-Turbo", displayName: "Llama 3.1 405B", supportsVision: false, contextWindow: 131_072, description: "Meta · El más potente"),
        AIModel(id: "meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo",  displayName: "Llama 3.1 70B",  supportsVision: false, contextWindow: 131_072, description: "Meta · Equilibrado"),
        AIModel(id: "meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo",   displayName: "Llama 3.1 8B",   supportsVision: false, contextWindow: 131_072, description: "Meta · Rápido"),
        AIModel(id: "mistralai/Mixtral-8x7B-Instruct-v0.1",           displayName: "Mixtral 8x7B",   supportsVision: false, contextWindow: 32_768,  description: "Mistral AI · MoE"),
        AIModel(id: "Qwen/Qwen2.5-72B-Instruct-Turbo",                displayName: "Qwen 2.5 72B",   supportsVision: false, contextWindow: 32_768,  description: "Alibaba · Multilingüe"),
        AIModel(id: "deepseek-ai/DeepSeek-R1",                        displayName: "DeepSeek R1",    supportsVision: false, contextWindow: 65_536,  description: "DeepSeek · Razonamiento")
    ]

    // Custom / self-hosted remote endpoint (vLLM, Llama.cpp server on a VPS, etc.)
    static let customModels: [AIModel] = [
        AIModel(id: "custom-model", displayName: "Modelo del endpoint", supportsVision: false, contextWindow: 4_096, description: "El modelo activo en tu servidor remoto")
    ]
}
