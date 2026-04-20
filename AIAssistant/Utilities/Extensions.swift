import SwiftUI
import UIKit

// MARK: - Color extensions

extension Color {
    static let aiPrimary   = Color("AIPrimary",   bundle: nil)
    static let aiBubble    = Color("AIBubble",    bundle: nil)
    static let userBubble  = Color("UserBubble",  bundle: nil)
    static let background  = Color("AIBackground", bundle: nil)

    // Fallback system colors used when assets aren't set up
    static let messageBg   = Color(UIColor.secondarySystemBackground)
    static let inputBg     = Color(UIColor.tertiarySystemBackground)
}

// MARK: - View extensions

extension View {
    /// Applies a glass-morphism background
    func glassMorphism(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
    }

    /// Hides the keyboard
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// Conditionally applies a modifier
    @ViewBuilder
    func `if`<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition { transform(self) } else { self }
    }
}

// MARK: - String markdown helpers

extension String {
    /// True if the string contains a fenced code block
    var hasCodeBlock: Bool {
        contains("```")
    }

    /// Splits content into text and code segments
    func splitCodeBlocks() -> [(isCode: Bool, content: String, language: String)] {
        var segments: [(isCode: Bool, content: String, language: String)] = []
        let parts = self.components(separatedBy: "```")
        for (idx, part) in parts.enumerated() {
            if idx % 2 == 0 {
                if !part.isEmpty { segments.append((false, part, "")) }
            } else {
                // First line is the language identifier
                let lines = part.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
                let lang = lines.first.map(String.init) ?? ""
                let code = lines.dropFirst().joined(separator: "\n")
                segments.append((true, code, lang))
            }
        }
        return segments
    }
}

// MARK: - Date formatting

extension Date {
    var shortTimeString: String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: self)
    }

    var relativeString: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Haptics

struct HapticFeedback {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

// MARK: - Waveform shape

struct WaveformShape: Shape {
    var levels: [Float]
    var animatableData: AnimatablePair<CGFloat, CGFloat> = .init(0, 0)

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !levels.isEmpty else { return path }

        let barWidth = rect.width / CGFloat(levels.count)
        let midY = rect.midY

        for (idx, level) in levels.enumerated() {
            let x = CGFloat(idx) * barWidth + barWidth / 2
            let height = max(4, CGFloat(level) * rect.height)
            path.addRoundedRect(
                in: CGRect(x: x - 2, y: midY - height / 2, width: 4, height: height),
                cornerSize: CGSize(width: 2, height: 2)
            )
        }
        return path
    }
}
