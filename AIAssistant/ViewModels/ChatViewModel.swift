import Foundation
import SwiftData
import UIKit
import Observation

// MARK: - ChatViewModel

@Observable
@MainActor
final class ChatViewModel {

    // MARK: Published state
    var messages: [Message] = []
    var inputText = ""
    var isLoading = false
    var isStreaming = false
    var errorMessage: String?
    var selectedImage: UIImage?
    var showVoiceMode = false
    var currentConversation: Conversation?

    // MARK: Dependencies
    let settings: AppSettings
    let speech: SpeechManager
    let device: DeviceIntegrationService
    private let ai = AIService.shared

    // MARK: SwiftData context (injected)
    var modelContext: ModelContext?

    // MARK: Init
    init(settings: AppSettings, speech: SpeechManager, device: DeviceIntegrationService) {
        self.settings = settings
        self.speech = speech
        self.device = device
    }

    // MARK: - Load / New conversation

    func startNewConversation() {
        messages = []
        selectedImage = nil
        inputText = ""
        errorMessage = nil

        let conv = Conversation(title: "Nueva conversación")
        currentConversation = conv
        modelContext?.insert(conv)
        saveContext()
    }

    func load(conversation: Conversation) {
        currentConversation = conversation
        messages = conversation.sortedMessages
    }

    // MARK: - Send message

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || selectedImage != nil else { return }
        guard settings.isConfigured else {
            errorMessage = "Añade tu API Key en Ajustes ⚙️"
            return
        }
        guard !isLoading else { return }

        // Stop any ongoing TTS
        speech.stopSpeaking()

        // Capture and clear input
        let messageText = text
        let image = selectedImage
        inputText = ""
        selectedImage = nil

        // Create user message
        let imageData = image.flatMap { compressImage($0) }
        let userMsg = Message(role: .user, content: messageText, imageData: imageData)
        messages.append(userMsg)
        persistMessage(userMsg)

        // Update conversation
        if currentConversation == nil { startNewConversation() }
        if messages.count == 1 {
            currentConversation?.title = userMsg.content.prefix(60).description
        }
        currentConversation?.updatedAt = Date()

        // Placeholder for streaming
        let assistantMsg = Message(role: .assistant, content: "", modelUsed: settings.selectedModelID, isStreaming: true)
        messages.append(assistantMsg)
        isLoading = true
        isStreaming = settings.streamingEnabled
        errorMessage = nil

        do {
            var fullResponse = ""

            if settings.streamingEnabled {
                fullResponse = try await ai.streamCompletion(
                    messages: Array(messages.dropLast()),   // exclude the placeholder
                    settings: settings,
                    imageData: imageData
                ) { [weak self] token in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        if let idx = self.messages.firstIndex(where: { $0.id == assistantMsg.id }) {
                            self.messages[idx].content += token
                        }
                    }
                }
            } else {
                fullResponse = try await ai.completion(
                    messages: Array(messages.dropLast()),
                    settings: settings,
                    imageData: imageData
                )
                if let idx = messages.firstIndex(where: { $0.id == assistantMsg.id }) {
                    messages[idx].content = fullResponse
                }
            }

            // Finalize the message
            if let idx = messages.firstIndex(where: { $0.id == assistantMsg.id }) {
                messages[idx].isStreaming = false
                messages[idx].content = fullResponse
            }

            persistMessage(assistantMsg)

            // TTS if enabled
            if settings.autoSpeak {
                speech.speak(fullResponse, settings: settings)
            }

        } catch {
            // Remove placeholder on error
            messages.removeAll { $0.id == assistantMsg.id }
            errorMessage = error.localizedDescription
        }

        isLoading = false
        isStreaming = false
    }

    // MARK: - Voice input

    func toggleRecording() {
        if speech.isRecording {
            speech.stopRecording()
            if !speech.transcribedText.isEmpty {
                inputText = speech.transcribedText
            }
        } else {
            do {
                speech.transcribedText = ""
                try speech.startRecording()
            } catch {
                errorMessage = "Error al iniciar el micrófono: \(error.localizedDescription)"
            }
        }
    }

    func sendVoiceMessage() async {
        guard !speech.transcribedText.isEmpty else { return }
        inputText = speech.transcribedText
        speech.stopRecording()
        await sendMessage()
    }

    // MARK: - Speak assistant message

    func speak(_ message: Message) {
        speech.speak(message.content, settings: settings)
    }

    // MARK: - Delete message

    func deleteMessage(_ message: Message) {
        messages.removeAll { $0.id == message.id }
        modelContext?.delete(message)
        saveContext()
    }

    // MARK: - Retry last

    func retryLastMessage() async {
        // Remove last assistant message and re-send
        if let last = messages.last, last.messageRole == .assistant {
            messages.removeLast()
            modelContext?.delete(last)
        }
        if let lastUser = messages.last, lastUser.messageRole == .user {
            inputText = lastUser.content
            selectedImage = lastUser.imageData.flatMap { UIImage(data: $0) }
            messages.removeLast()
            modelContext?.delete(lastUser)
        }
        await sendMessage()
    }

    // MARK: - Clear conversation

    func clearConversation() {
        for msg in messages { modelContext?.delete(msg) }
        messages = []
        saveContext()
    }

    // MARK: - Private helpers

    private func persistMessage(_ message: Message) {
        guard let conversation = currentConversation else { return }
        message.conversation = conversation
        conversation.messages.append(message)
        modelContext?.insert(message)
        saveContext()
    }

    private func saveContext() {
        try? modelContext?.save()
    }

    private func compressImage(_ image: UIImage) -> Data? {
        let maxSize: CGFloat = 1024
        let scale = min(maxSize / image.size.width, maxSize / image.size.height, 1.0)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
