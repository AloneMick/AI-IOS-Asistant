import Foundation
import Speech
import AVFoundation
import Observation

// MARK: - SpeechManager

@Observable
@MainActor
final class SpeechManager: NSObject {

    // MARK: State
    var isRecording = false
    var isSpeaking = false
    var transcribedText = ""
    var audioLevel: Float = 0      // 0.0 – 1.0 for waveform animation
    var permissionGranted = false

    // MARK: Private
    private let recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    private var levelTimer: Timer?

    // MARK: Init
    override init() {
        recognizer = SFSpeechRecognizer(locale: Locale.autoupdatingCurrent)
        super.init()
        synthesizer.delegate = self
        requestPermissions()
    }

    // MARK: - Permissions

    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.permissionGranted = (status == .authorized)
            }
        }
    }

    // MARK: - Recording (Speech → Text)

    func startRecording() throws {
        guard permissionGranted else { return }
        guard !isRecording else { return }

        // Cancel any previous task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Audio session
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false

        // Input node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            // Compute audio level for waveform
            if let channelData = buffer.floatChannelData?[0] {
                let frames = buffer.frameLength
                var sum: Float = 0
                for i in 0..<Int(frames) { sum += abs(channelData[i]) }
                let avg = sum / Float(frames)
                DispatchQueue.main.async { self?.audioLevel = min(avg * 10, 1.0) }
            }
        }

        audioEngine.prepare()
        try audioEngine.start()

        transcribedText = ""
        isRecording = true

        recognitionTask = recognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            if let result {
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                }
            }
            if error != nil || (result?.isFinal == true) {
                DispatchQueue.main.async { self.stopRecording() }
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
        audioLevel = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Speech synthesis (Text → Speech)

    func speak(_ text: String, settings: AppSettings) {
        guard settings.voiceEnabled else { return }

        stopSpeaking()

        let cleaned = removeMDSyntax(from: text)
        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.rate = settings.speechRate

        // Use the user-selected voice, or the best available for the current locale
        if !settings.selectedVoiceIdentifier.isEmpty,
           let voice = AVSpeechSynthesisVoice(identifier: settings.selectedVoiceIdentifier) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.language.languageCode?.identifier ?? "en")
        }

        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { }

        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }

    // MARK: - Helpers

    /// Available voices for settings UI
    var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(Locale.current.language.languageCode?.identifier ?? "en") }
            .sorted { $0.name < $1.name }
    }

    /// Strip markdown syntax so TTS sounds natural
    private func removeMDSyntax(from text: String) -> String {
        var result = text
        // Remove code blocks
        result = result.replacingOccurrences(of: #"```[\s\S]*?```"#, with: "código omitido.", options: .regularExpression)
        // Remove inline code
        result = result.replacingOccurrences(of: #"`[^`]+`"#, with: "", options: .regularExpression)
        // Remove headers
        result = result.replacingOccurrences(of: #"#{1,6} "#, with: "", options: .regularExpression)
        // Remove bold/italic
        result = result.replacingOccurrences(of: #"\*{1,3}([^\*]+)\*{1,3}"#, with: "$1", options: .regularExpression)
        // Remove URLs
        result = result.replacingOccurrences(of: #"\[([^\]]+)\]\([^\)]+\)"#, with: "$1", options: .regularExpression)
        return result
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in isSpeaking = false }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in isSpeaking = false }
    }
}
