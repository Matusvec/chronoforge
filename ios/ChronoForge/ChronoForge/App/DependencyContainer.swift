import Foundation

/// Protocol-based dependency injection container.
@MainActor
final class DependencyContainer: ObservableObject {
    let repository: ChronoRepositoryProtocol
    let authManager: AuthManager
    let useFakeMode: Bool

    init(useFakeMode: Bool = false) {
        self.useFakeMode = useFakeMode
        self.authManager = AuthManager.shared

        let api: APIClientProtocol
        if useFakeMode {
            api = MockAPIClient()
        } else {
            api = APIClient(
                baseURL: "http://localhost:8000",
                tokenProvider: { [weak authManager] in
                    // Capture value at call time, not init time
                    return AuthManager.shared.currentToken
                }
            )
        }
        self.repository = ChronoRepository(api: api)
    }
}
