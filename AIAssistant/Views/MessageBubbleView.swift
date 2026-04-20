import SwiftUI

// MARK: - MessageBubbleView

struct MessageBubbleView: View {
    let message: Message
    let settings: AppSettings
    let onSpeak: () -> Void
    let onCopy: () -> Void

    @State private var isCopied = false

    private var isUser: Bool { message.messageRole == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 40) }

            if !isUser {
                // AI avatar
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.white)
                            .font(.system(size: 14, weight: .semibold))
                    }
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                // Image attachment
                if let imageData = message.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: 220, maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // Message content
                if !message.content.isEmpty {
                    bubbleContent
                }

                // Streaming indicator
                if message.isStreaming {
                    TypingIndicatorView()
                        .padding(.leading, 4)
                }

                // Timestamp + actions
                HStack(spacing: 12) {
                    Text(message.timestamp.shortTimeString)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if !isUser && !message.content.isEmpty {
                        Button(action: {
                            onCopy()
                            isCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { isCopied = false }
                        }) {
                            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Button(action: onSpeak) {
                            Image(systemName: "speaker.wave.2")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }

            if !isUser { Spacer(minLength: 40) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    // MARK: - Bubble content

    @ViewBuilder
    private var bubbleContent: some View {
        if message.content.hasCodeBlock {
            codeAwareBubble
        } else {
            plainBubble(text: message.content)
        }
    }

    private var codeAwareBubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(message.content.splitCodeBlocks().indices, id: \.self) { idx in
                let segment = message.content.splitCodeBlocks()[idx]
                if segment.isCode {
                    codeBlock(segment.content, language: segment.language)
                } else {
                    Text(segment.content)
                        .textSelection(.enabled)
                        .font(.body)
                        .foregroundStyle(isUser ? .white : .primary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(isUser
                    ? LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color.messageBg], startPoint: .top, endPoint: .bottom)
                )
        )
    }

    private func plainBubble(text: String) -> some View {
        Text(text)
            .textSelection(.enabled)
            .font(.body)
            .foregroundStyle(isUser ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isUser
                        ? LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.messageBg], startPoint: .top, endPoint: .bottom)
                    )
            )
    }

    private func codeBlock(_ code: String, language: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if !language.isEmpty {
                    Text(language)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                } label: {
                    Label("Copiar", systemImage: "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Divider()
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
        }
        .padding(10)
        .background(Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Typing indicator

struct TypingIndicatorView: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 6, height: 6)
                    .scaleEffect(phase == i ? 1.4 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15),
                        value: phase
                    )
            }
        }
        .onAppear {
            withAnimation { phase = (phase + 1) % 3 }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        MessageBubbleView(
            message: Message(role: .user, content: "Hola, ¿cómo estás?"),
            settings: AppSettings(),
            onSpeak: {},
            onCopy: {}
        )
        MessageBubbleView(
            message: Message(role: .assistant, content: "Estoy muy bien, ¡listo para ayudarte!\n\n```swift\nprint(\"Hello, world!\")\n```"),
            settings: AppSettings(),
            onSpeak: {},
            onCopy: {}
        )
    }
    .padding()
}
