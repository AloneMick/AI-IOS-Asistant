import SwiftUI
import SwiftData

// MARK: - AIAssistantApp

@main
struct AIAssistantApp: App {

    // Singleton services
    @State private var settings = AppSettings()
    @State private var speech = SpeechManager()
    @State private var device = DeviceIntegrationService()

    // SwiftData container
    private let container: ModelContainer = {
        let schema = Schema([Conversation.self, Message.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(settings: settings, speech: speech, device: device)
                .modelContainer(container)
                .task {
                    // Request device permissions on launch
                    await device.requestAllPermissions()
                    speech.requestPermissions()
                }
        }
    }
}
