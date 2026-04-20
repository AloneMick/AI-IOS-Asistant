import Foundation
import SwiftData

// MARK: - HistoryManager

@MainActor
final class HistoryManager {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: Fetch

    func fetchAll() throws -> [Conversation] {
        let descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchPinned() throws -> [Conversation] {
        let descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.isPinned },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func search(query: String) throws -> [Conversation] {
        let all = try fetchAll()
        guard !query.isEmpty else { return all }
        let q = query.lowercased()
        return all.filter {
            $0.title.lowercased().contains(q)
            || $0.messages.contains { $0.content.lowercased().contains(q) }
        }
    }

    // MARK: Create

    @discardableResult
    func newConversation(title: String = "Nueva conversación") -> Conversation {
        let conv = Conversation(title: title)
        context.insert(conv)
        save()
        return conv
    }

    // MARK: Update

    func pin(_ conversation: Conversation) {
        conversation.isPinned.toggle()
        save()
    }

    func rename(_ conversation: Conversation, to title: String) {
        conversation.title = title
        save()
    }

    // MARK: Delete

    func delete(_ conversation: Conversation) {
        context.delete(conversation)
        save()
    }

    func deleteAll() throws {
        let all = try fetchAll()
        for conv in all { context.delete(conv) }
        save()
    }

    // MARK: Private

    private func save() {
        try? context.save()
    }
}
