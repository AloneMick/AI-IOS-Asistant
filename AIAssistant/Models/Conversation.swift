import Foundation
import SwiftData

// MARK: - Conversation

@Model
final class Conversation {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool

    @Relationship(deleteRule: .cascade)
    var messages: [Message]

    init(title: String = "Nueva conversación") {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isPinned = false
        self.messages = []
    }

    /// Returns messages sorted by timestamp for display
    var sortedMessages: [Message] {
        messages.sorted { $0.timestamp < $1.timestamp }
    }

    /// Last assistant message content (used for preview in history)
    var lastMessagePreview: String {
        sortedMessages.last(where: { $0.role != MessageRole.system.rawValue })?.content ?? ""
    }

    /// Auto-generates a title from the first user message
    func autoTitle() -> String {
        let firstUser = sortedMessages.first(where: { $0.role == MessageRole.user.rawValue })
        guard let text = firstUser?.content, !text.isEmpty else { return "Nueva conversación" }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(60))
    }
}
