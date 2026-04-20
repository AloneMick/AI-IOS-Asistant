import Foundation

// MARK: - Errors

enum AIServiceError: LocalizedError {
    case missingAPIKey
    case missingEndpoint
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API Key no configurada. Ve a Ajustes → selecciona tu proveedor y añade la Key."
        case .missingEndpoint:
            return "Endpoint no configurado. Revisa Ajustes → URL del servidor local."
        case .invalidResponse:
            return "Respuesta inválida del servidor."
        case .httpError(let code, let msg):
            return "Error HTTP \(code): \(msg)"
        case .networkError(let err):
            return "Error de red: \(err.localizedDescription)"
        }
    }
}

// MARK: - Decodable helpers

private struct StreamChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable { let content: String? }
        let delta: Delta
        let finish_reason: String?
    }
    let choices: [Choice]
}

private struct NonStreamResponse: Decodable {
    struct Choice: Decodable {
        struct Msg: Decodable { let content: String }
        let message: Msg
    }
    let choices: [Choice]
}

private struct APIErrorBody: Decodable {
    struct Inner: Decodable { let message: String }
    let error: Inner
}

// MARK: - AIService

actor AIService {

    static let shared = AIService()

    private let session: URLSession

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 60
        cfg.timeoutIntervalForResource = 300
        session = URLSession(configuration: cfg)
    }

    // MARK: - Streaming

    /// Streams the response token by token. Returns the full accumulated text.
    func streamCompletion(
        messages: [Message],
        settings: AppSettings,
        imageData: Data? = nil,
        onToken: @escaping @Sendable (String) -> Void
    ) async throws -> String {

        let request = try buildURLRequest(
            messages: messages, settings: settings, imageData: imageData, stream: true)

        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIServiceError.invalidResponse }
        guard http.statusCode == 200 else {
            throw AIServiceError.httpError(statusCode: http.statusCode, message: "HTTP \(http.statusCode)")
        }

        var fullText = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let json = String(line.dropFirst(6))
            if json == "[DONE]" { break }
            guard
                let data = json.data(using: .utf8),
                let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data),
                let delta = chunk.choices.first?.delta.content
            else { continue }
            fullText += delta
            onToken(delta)
        }

        return fullText
    }

    // MARK: - Non-streaming

    func completion(
        messages: [Message],
        settings: AppSettings,
        imageData: Data? = nil
    ) async throws -> String {

        let request = try buildURLRequest(
            messages: messages, settings: settings, imageData: imageData, stream: false)

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let msg = (try? JSONDecoder().decode(APIErrorBody.self, from: data))?.error.message ?? "Unknown"
            throw AIServiceError.httpError(statusCode: http.statusCode, message: msg)
        }

        let decoded = try JSONDecoder().decode(NonStreamResponse.self, from: data)
        return decoded.choices.first?.message.content ?? ""
    }

    // MARK: - Request builder

    private func buildURLRequest(
        messages: [Message],
        settings: AppSettings,
        imageData: Data?,
        stream: Bool
    ) throws -> URLRequest {

        // Validate endpoint
        let baseURL = settings.activeBaseURL
        guard !baseURL.isEmpty, let endpoint = URL(string: baseURL + "/chat/completions") else {
            throw AIServiceError.missingEndpoint
        }

        // Validate API key (only for providers that require it)
        let trimmedKey = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if settings.selectedProvider.requiresAPIKey && trimmedKey.isEmpty {
            throw AIServiceError.missingAPIKey
        }

        // Build messages array
        var apiMessages: [[String: Any]] = [
            ["role": "system", "content": settings.systemPrompt]
        ]

        let slice = messages
            .filter { $0.role != MessageRole.system.rawValue }
            .suffix(settings.contextWindowSize)

        for (idx, msg) in slice.enumerated() {
            let isLastUser = idx == slice.count - 1
                && msg.role == MessageRole.user.rawValue
                && imageData != nil
                && settings.selectedModel.supportsVision

            if isLastUser, let imgData = imageData {
                let b64 = imgData.base64EncodedString()
                apiMessages.append([
                    "role": msg.role,
                    "content": [
                        ["type": "text", "text": msg.content],
                        ["type": "image_url",
                         "image_url": ["url": "data:image/jpeg;base64,\(b64)", "detail": "high"]]
                    ]
                ])
            } else {
                apiMessages.append(["role": msg.role, "content": msg.content])
            }
        }

        // Body — some providers don't accept max_tokens with vision; keep it safe
        var body: [String: Any] = [
            "model": settings.selectedModelID,
            "messages": apiMessages,
            "temperature": settings.temperature,
            "stream": stream
        ]

        // Ollama uses "num_predict" instead of max_tokens, but also accepts max_tokens via the compat layer
        body["max_tokens"] = settings.maxTokens

        // OpenRouter requires an extra header for attribution (recommended, not required)
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Auth header — local providers (Ollama, LM Studio) work without one, but also accept Bearer
        if !trimmedKey.isEmpty {
            req.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        }

        // OpenRouter attribution headers (optional but appreciated)
        if settings.selectedProvider == .openRouter {
            req.setValue("AI-IOS-Asistant", forHTTPHeaderField: "X-Title")
            req.setValue("https://github.com/AloneMick/AI-IOS-Asistant", forHTTPHeaderField: "HTTP-Referer")
        }

        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }
}
