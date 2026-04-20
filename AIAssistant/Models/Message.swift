import Foundation
import SwiftData

// MARK: - Role

enum MessageRole: String, Codable {
    case system
    case user
    case assistant
    case tool
}

// MARK: - Message

@Model
final class Message {
    var id: UUID
    var role: String          // MessageRole.rawValue
    var content: String
    var imageData: Data?
    var timestamp: Date
    var isStreaming: Bool
    var tokenCount: Int
    var modelUsed: String

    @Relationship(inverse: \Conversation.messages)
    var conversation: Conversation?

    init(
        role: MessageRole,
        content: String,
        imageData: Data? = nil,
        modelUsed: String = "",
        isStreaming: Bool = false
    ) {
        self.id = UUID()
        self.role = role.rawValue
        self.content = content
        self.imageData = imageData
        self.timestamp = Date()
        self.isStreaming = isStreaming
        self.tokenCount = 0
        self.modelUsed = modelUsed
    }

    var messageRole: MessageRole {
        MessageRole(rawValue: role) ?? .user
    }

    /// Convert to the OpenAI API message dict (text-only or multimodal)
    func toAPIPayload(imageBase64: String? = nil) -> [String: Any] {
        if let base64 = imageBase64, !base64.isEmpty {
            return [
                "role": role,
                "content": [
                    ["type": "text", "text": content],
                    [
                        "type": "image_url",
                        "image_url": ["url": "data:image/jpeg;base64,\(base64)", "detail": "high"]
                    ]
                ]
            ]
        }
        return ["role": role, "content": content]
    }
}
