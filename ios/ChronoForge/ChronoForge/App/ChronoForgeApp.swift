import SwiftUI

@main
struct ChronoForgeApp: App {
    @StateObject private var container = DependencyContainer(
        useFakeMode: ProcessInfo.processInfo.arguments.contains("--fake-mode")
    )
    @StateObject private var authManager = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
                .environmentObject(authManager)
        }
    }
}
