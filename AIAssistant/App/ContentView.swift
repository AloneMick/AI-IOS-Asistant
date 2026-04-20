import SwiftUI
import SwiftData

// MARK: - ContentView (Root navigation)

struct ContentView: View {

    @State private var selectedTab = 0
    @State private var viewModel: ChatViewModel
    @Environment(\.modelContext) private var context

    init(settings: AppSettings, speech: SpeechManager, device: DeviceIntegrationService) {
        _viewModel = State(initialValue: ChatViewModel(settings: settings, speech: speech, device: device))
    }

    var body: some View {
        TabView(selection: $selectedTab) {

            // MARK: Chat tab
            ConversationView(viewModel: viewModel)
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(0)

            // MARK: History tab
            HistoryView { conversation in
                viewModel.load(conversation: conversation)
                selectedTab = 0
            }
            .tabItem {
                Label("Historial", systemImage: "clock.fill")
            }
            .tag(1)

            // MARK: Settings tab
            SettingsView(settings: viewModel.settings)
                .tabItem {
                    Label("Ajustes", systemImage: "gear")
                }
                .tag(2)
        }
        .tint(.purple)
        .onAppear {
            viewModel.modelContext = context
            if viewModel.currentConversation == nil {
                viewModel.startNewConversation()
            }
        }
    }
}
