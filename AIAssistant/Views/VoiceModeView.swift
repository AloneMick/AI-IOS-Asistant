import SwiftUI

// MARK: - VoiceModeView (Hands-free full-screen voice conversation)

struct VoiceModeView: View {

    @Bindable var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var waveformLevels: [Float] = Array(repeating: 0.1, count: 30)
    @State private var waveformTimer: Timer?
    @State private var statusText = "Toca el micrófono para hablar"
    @State private var autoMode = false

    var body: some View {
        ZStack {
            // Background
            backgroundGradient.ignoresSafeArea()

            VStack(spacing: 32) {

                // Header
                HStack {
                    Button("Cerrar") { stopAndDismiss() }
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Text("Modo Voz")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Toggle("Auto", isOn: $autoMode)
                        .toggleStyle(.button)
                        .tint(.white.opacity(0.3))
                        .foregroundStyle(.white.opacity(0.8))
                        .font(.caption)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                Spacer()

                // AI avatar orb
                ZStack {
                    // Pulsing rings
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(
                                LinearGradient(colors: [.purple.opacity(0.4), .blue.opacity(0.2)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                            .frame(width: CGFloat(100 + i * 40), height: CGFloat(100 + i * 40))
                            .scaleEffect(viewModel.speech.isSpeaking || viewModel.speech.isRecording ? 1.15 : 1.0)
                            .animation(
                                .easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(Double(i) * 0.3),
                                value: viewModel.speech.isSpeaking || viewModel.speech.isRecording
                            )
                    }

                    // Center orb
                    Circle()
                        .fill(
                            LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 90, height: 90)
                        .shadow(color: .purple.opacity(0.6), radius: viewModel.speech.isSpeaking ? 30 : 12)
                        .overlay {
                            Image(systemName: currentOrbIcon)
                                .font(.system(size: 36))
                                .foregroundStyle(.white)
                                .symbolEffect(.bounce, isActive: viewModel.speech.isRecording)
                        }
                }

                // Waveform
                HStack(spacing: 3) {
                    ForEach(waveformLevels.indices, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.white.opacity(0.7))
                            .frame(width: 3, height: max(4, CGFloat(waveformLevels[i]) * 60))
                            .animation(.easeInOut(duration: 0.1), value: waveformLevels[i])
                    }
                }
                .frame(height: 60)

                // Transcription / status
                VStack(spacing: 8) {
                    if viewModel.speech.isRecording && !viewModel.speech.transcribedText.isEmpty {
                        Text(viewModel.speech.transcribedText)
                            .font(.body)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .transition(.opacity)
                    } else if viewModel.isLoading {
                        HStack(spacing: 6) {
                            ProgressView().tint(.white)
                            Text("Pensando…")
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    } else {
                        Text(statusText)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    // Last assistant message
                    if let last = viewModel.messages.last(where: { $0.messageRole == .assistant }) {
                        Text(last.content.prefix(120) + (last.content.count > 120 ? "…" : ""))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .lineLimit(3)
                    }
                }

                Spacer()

                // Controls
                HStack(spacing: 40) {
                    // Stop speaking
                    circleButton(icon: "speaker.slash", color: .white.opacity(0.2)) {
                        viewModel.speech.stopSpeaking()
                    }

                    // Main mic button
                    Button {
                        HapticFeedback.impact(.heavy)
                        handleMicTap()
                    } label: {
                        Circle()
                            .fill(viewModel.speech.isRecording ? Color.red : Color.white)
                            .frame(width: 72, height: 72)
                            .overlay {
                                Image(systemName: viewModel.speech.isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(viewModel.speech.isRecording ? .white : .purple)
                            }
                            .shadow(color: (viewModel.speech.isRecording ? Color.red : Color.white).opacity(0.5), radius: 16)
                    }

                    // Send transcription
                    circleButton(icon: "paperplane.fill", color: .white.opacity(0.2)) {
                        Task { await viewModel.sendVoiceMessage() }
                    }
                    .opacity(viewModel.speech.transcribedText.isEmpty ? 0.4 : 1.0)
                    .disabled(viewModel.speech.transcribedText.isEmpty)
                }
                .padding(.bottom, 48)
            }
        }
        .onAppear { startWaveformTimer() }
        .onDisappear { stopWaveformTimer() }
        .onChange(of: viewModel.speech.audioLevel) { _, level in
            updateWaveform(with: level)
        }
        .onChange(of: viewModel.isLoading) { _, loading in
            statusText = loading ? "Procesando…" : "Toca el micrófono para hablar"
        }
        .onChange(of: viewModel.speech.isSpeaking) { _, speaking in
            statusText = speaking ? "Escuchando la respuesta…" : "Toca el micrófono para hablar"
            if !speaking && autoMode && !viewModel.isLoading {
                // Auto-restart recording after speaking finishes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    handleMicTap()
                }
            }
        }
    }

    // MARK: - Actions

    private func handleMicTap() {
        if viewModel.speech.isRecording {
            viewModel.speech.stopRecording()
            if !viewModel.speech.transcribedText.isEmpty {
                Task { await viewModel.sendVoiceMessage() }
            }
        } else {
            do {
                try viewModel.speech.startRecording()
                statusText = "Escuchando…"
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }

    private func stopAndDismiss() {
        viewModel.speech.stopRecording()
        viewModel.speech.stopSpeaking()
        dismiss()
    }

    // MARK: - Waveform animation

    private func startWaveformTimer() {
        waveformTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            if !viewModel.speech.isRecording && !viewModel.speech.isSpeaking {
                // Idle animation
                withAnimation {
                    for i in waveformLevels.indices {
                        waveformLevels[i] = Float.random(in: 0.05...0.15)
                    }
                }
            }
        }
    }

    private func stopWaveformTimer() {
        waveformTimer?.invalidate()
        waveformTimer = nil
    }

    private func updateWaveform(with level: Float) {
        var newLevels = waveformLevels
        newLevels.removeFirst()
        newLevels.append(level)
        waveformLevels = newLevels
    }

    // MARK: - Helpers

    private var currentOrbIcon: String {
        if viewModel.speech.isRecording { return "mic.fill" }
        if viewModel.isLoading { return "ellipsis" }
        if viewModel.speech.isSpeaking { return "speaker.wave.3.fill" }
        return "sparkles"
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.0, blue: 0.15),
                Color(red: 0.05, green: 0.05, blue: 0.30)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func circleButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                }
        }
    }
}
