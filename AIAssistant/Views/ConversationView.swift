import SwiftUI
import PhotosUI

// MARK: - ConversationView

struct ConversationView: View {

    @Bindable var viewModel: ChatViewModel
    @State private var scrollProxy: ScrollViewProxy?
    @State private var showImagePicker = false
    @State private var showPhotosPicker = false
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var showClearConfirm = false
    @State private var showVoiceMode = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(UIColor.systemBackground), Color(UIColor.secondarySystemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Messages list
                    messagesScrollView

                    // Error banner
                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                    }

                    Divider()

                    // Input bar
                    inputBar
                }
            }
            .navigationTitle(viewModel.currentConversation?.title ?? "AI Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) {
                // Subtle provider/model banner below the nav bar
                HStack(spacing: 6) {
                    Image(systemName: viewModel.settings.selectedProvider.icon)
                        .font(.caption2)
                    Text("\(viewModel.settings.selectedProvider.displayName) · \(viewModel.settings.selectedModel.displayName)")
                        .font(.caption2)
                    if viewModel.settings.selectedModel.supportsVision {
                        Image(systemName: "eye.fill")
                            .font(.caption2)
                            .foregroundStyle(.teal)
                    }
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
            }
            .toolbar { toolbarContent }
            .sheet(isPresented: $showVoiceMode) {
                VoiceModeView(viewModel: viewModel)
            }
            .confirmationDialog("Borrar conversación", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Borrar todo", role: .destructive) { viewModel.clearConversation() }
                Button("Cancelar", role: .cancel) {}
            }
            .onChange(of: photosPickerItem) { _, item in
                Task { await loadPickedPhoto(item) }
            }
        }
    }

    // MARK: - Messages

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if viewModel.messages.isEmpty {
                        emptyState
                    }
                    ForEach(viewModel.messages, id: \.id) { message in
                        MessageBubbleView(
                            message: message,
                            settings: viewModel.settings,
                            onSpeak: { viewModel.speak(message) },
                            onCopy: {
                                UIPasteboard.general.string = message.content
                                if viewModel.settings.hapticFeedback {
                                    HapticFeedback.notification(.success)
                                }
                            }
                        )
                        .id(message.id)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    // Scroll anchor
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, 8)
                .animation(.easeOut(duration: 0.2), value: viewModel.messages.count)
            }
            .onAppear { scrollProxy = proxy }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation { proxy.scrollTo("bottom") }
            }
            .onChange(of: viewModel.isStreaming) { _, streaming in
                if streaming { withAnimation { proxy.scrollTo("bottom") } }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 60)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 80, height: 80)
                Image(systemName: "sparkles")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
            .shadow(color: .purple.opacity(0.4), radius: 20)

            Text("AI Assistant")
                .font(.title2)
                .fontWeight(.bold)

            Text("Más potente que Apple Intelligence.\nCon OpenAI, Llama, Mistral, Gemma y más.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(suggestionChips, id: \.self) { chip in
                    suggestionChipView(chip)
                }
            }
            .padding(.horizontal)

            Spacer(minLength: 20)
        }
    }

    private let suggestionChips = [
        "Explícame la IA cuántica",
        "Escribe un poema en haiku",
        "Analiza esta imagen 📷",
        "Crea un plan de negocio",
        "Convierte esto a Python",
        "Dame ideas creativas"
    ]

    private func suggestionChipView(_ text: String) -> some View {
        Button {
            viewModel.inputText = text
            Task { await viewModel.sendMessage() }
        } label: {
            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .glassMorphism(cornerRadius: 12)
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            // Selected image preview
            if let img = viewModel.selectedImage {
                selectedImagePreview(img)
            }

            HStack(alignment: .bottom, spacing: 10) {
                // Attach image button
                Menu {
                    Button { showPhotosPicker = true } label: {
                        Label("Galería de fotos", systemImage: "photo.on.rectangle")
                    }
                    Button { showImagePicker = true } label: {
                        Label("Cámara", systemImage: "camera")
                    }
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                }
                .opacity(viewModel.settings.selectedModel.supportsVision ? 1 : 0.3)
                .disabled(!viewModel.settings.selectedModel.supportsVision)

                // Text field
                ZStack(alignment: .leading) {
                    if viewModel.inputText.isEmpty && !viewModel.speech.isRecording {
                        Text("Escribe o habla…")
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 6)
                    }
                    TextField("", text: $viewModel.inputText, axis: .vertical)
                        .focused($inputFocused)
                        .lineLimit(1...6)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.inputBg, in: RoundedRectangle(cornerRadius: 20))

                // Mic / Voice mode button
                Button {
                    if viewModel.settings.hapticFeedback { HapticFeedback.impact(.light) }
                    if viewModel.speech.isRecording {
                        viewModel.toggleRecording()
                    } else {
                        showVoiceMode = true
                    }
                } label: {
                    Image(systemName: viewModel.speech.isRecording ? "waveform" : "mic")
                        .font(.system(size: 20))
                        .foregroundStyle(viewModel.speech.isRecording ? .red : .secondary)
                        .frame(width: 36, height: 36)
                        .symbolEffect(.pulse, isActive: viewModel.speech.isRecording)
                }

                // Send button
                Button {
                    if viewModel.settings.hapticFeedback { HapticFeedback.impact(.medium) }
                    inputFocused = false
                    Task { await viewModel.sendMessage() }
                } label: {
                    Group {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(
                                (viewModel.inputText.isEmpty && viewModel.selectedImage == nil) || viewModel.isLoading
                                ? LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom)
                                : LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                    )
                }
                .disabled(viewModel.inputText.isEmpty && viewModel.selectedImage == nil || viewModel.isLoading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
        .photosPicker(isPresented: $showPhotosPicker, selection: $photosPickerItem, matching: .images)
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView(image: $viewModel.selectedImage)
        }
    }

    private func selectedImagePreview(_ image: UIImage) -> some View {
        HStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Spacer()
            Button {
                viewModel.selectedImage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                viewModel.startNewConversation()
            } label: {
                Image(systemName: "square.and.pencil")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Label("Borrar conversación", systemImage: "trash")
                }
                Button {
                    Task { await viewModel.retryLastMessage() }
                } label: {
                    Label("Reintentar", systemImage: "arrow.counterclockwise")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - Error banner

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
            Spacer()
            Button {
                viewModel.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.15))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Photos picker

    private func loadPickedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            viewModel.selectedImage = image
        }
    }
}
