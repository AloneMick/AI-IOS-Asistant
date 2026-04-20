import SwiftUI
import SwiftData

// MARK: - HistoryView

struct HistoryView: View {

    @Environment(\.modelContext) private var context
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]

    var onSelect: (Conversation) -> Void

    @State private var searchText = ""
    @State private var showDeleteAll = false

    private var filtered: [Conversation] {
        if searchText.isEmpty { return conversations }
        let q = searchText.lowercased()
        return conversations.filter {
            $0.title.lowercased().contains(q)
            || $0.messages.contains { $0.content.lowercased().contains(q) }
        }
    }

    private var pinned: [Conversation] { filtered.filter(\.isPinned) }
    private var unpinned: [Conversation] { filtered.filter { !$0.isPinned } }

    var body: some View {
        NavigationStack {
            Group {
                if conversations.isEmpty {
                    emptyState
                } else {
                    conversationList
                }
            }
            .navigationTitle("Historial")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Buscar conversaciones")
            .toolbar {
                if !conversations.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            showDeleteAll = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .confirmationDialog("¿Borrar todo el historial?", isPresented: $showDeleteAll, titleVisibility: .visible) {
                Button("Borrar todo", role: .destructive) { deleteAll() }
                Button("Cancelar", role: .cancel) {}
            }
        }
    }

    // MARK: - List

    private var conversationList: some View {
        List {
            if !pinned.isEmpty {
                Section("Fijadas") {
                    ForEach(pinned) { conv in
                        conversationRow(conv)
                    }
                }
            }
            Section(pinned.isEmpty ? "Conversaciones" : "Recientes") {
                ForEach(unpinned) { conv in
                    conversationRow(conv)
                }
                .onDelete { offsets in
                    for i in offsets { context.delete(unpinned[i]) }
                    try? context.save()
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func conversationRow(_ conv: Conversation) -> some View {
        Button {
            onSelect(conv)
        } label: {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                    Image(systemName: "bubble.left.and.bubble.right")
                        .foregroundStyle(.purple)
                        .font(.system(size: 18))
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(conv.title)
                            .font(.headline)
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                        if conv.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                        Spacer()
                        Text(conv.updatedAt.relativeString)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(conv.lastMessagePreview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Text("\(conv.messages.count) mensajes")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                conv.isPinned.toggle()
                try? context.save()
            } label: {
                Label(conv.isPinned ? "Desfijar" : "Fijar", systemImage: conv.isPinned ? "pin.slash" : "pin")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                context.delete(conv)
                try? context.save()
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
            Button {
                // Could open a rename sheet – for now copy title
                UIPasteboard.general.string = conv.title
            } label: {
                Label("Copiar", systemImage: "doc.on.doc")
            }
            .tint(.blue)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Sin historial")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Tus conversaciones aparecerán aquí")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Delete all

    private func deleteAll() {
        for conv in conversations { context.delete(conv) }
        try? context.save()
    }
}
