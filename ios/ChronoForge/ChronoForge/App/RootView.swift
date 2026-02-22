import SwiftUI

struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var container: DependencyContainer

    var body: some View {
        Group {
            if authManager.isAuthenticated || container.useFakeMode {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .animation(.easeInOut, value: authManager.isAuthenticated)
    }
}

struct MainTabView: View {
    @EnvironmentObject var container: DependencyContainer

    var body: some View {
        TabView {
            DashboardView(viewModel: DashboardViewModel(repository: container.repository))
                .tabItem {
                    Label("Today", systemImage: "clock.fill")
                }

            GoalsListView(viewModel: GoalsViewModel(repository: container.repository))
                .tabItem {
                    Label("Goals", systemImage: "target")
                }

            PlanView(viewModel: PlanViewModel(repository: container.repository))
                .tabItem {
                    Label("Plan", systemImage: "calendar")
                }
        }
        .tint(.orange)
    }
}
