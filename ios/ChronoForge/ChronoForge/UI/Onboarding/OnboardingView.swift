import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var container: DependencyContainer
    @State private var integrationStatus = IntegrationStatus(google: false, canvas: false)
    @State private var canvasToken = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerSection
                Spacer().frame(height: 40)
                integrationCards
                Spacer()
                if let error = errorMessage {
                    errorBanner(error)
                }
                skipButton
            }
            .padding()
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange.gradient)

            Text("ChronoForge")
                .font(.system(size: 36, weight: .black, design: .rounded))

            Text("Connect your accounts to forge\nyour optimal schedule.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }

    private var integrationCards: some View {
        VStack(spacing: 16) {
            IntegrationCard(
                title: "Google",
                subtitle: "Calendar & Gmail",
                icon: "envelope.fill",
                isConnected: integrationStatus.google,
                action: connectGoogle
            )

            IntegrationCard(
                title: "Canvas LMS",
                subtitle: "Assignments & Deadlines",
                icon: "graduationcap.fill",
                isConnected: integrationStatus.canvas,
                action: nil
            )

            if !integrationStatus.canvas {
                VStack(spacing: 8) {
                    TextField("Paste Canvas access token", text: $canvasToken)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)

                    Button("Save Canvas Token") {
                        Task { await saveCanvasToken() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(canvasToken.isEmpty)
                }
                .padding(.horizontal)
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }

    private var skipButton: some View {
        Button {
            container.authManager.setToken("fake-token", email: "demo@chronoforge.app")
        } label: {
            Text("Skip for now (Demo Mode)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 20)
    }

    private func connectGoogle() {
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                let response: AuthStartResponse = try await container.repository.getIntegrationStatus() as! AuthStartResponse
                if let url = URL(string: response.authUrl) {
                    await UIApplication.shared.open(url)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func saveCanvasToken() async {
        isLoading = true
        defer { isLoading = false }
        integrationStatus = IntegrationStatus(google: integrationStatus.google, canvas: true)
    }
}

struct IntegrationCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isConnected: Bool
    let action: (() -> Void)?

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(isConnected ? .green : .orange)
                .frame(width: 44, height: 44)
                .background(
                    (isConnected ? Color.green : Color.orange).opacity(0.15),
                    in: RoundedRectangle(cornerRadius: 12)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            } else if let action {
                Button("Connect", action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.small)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
