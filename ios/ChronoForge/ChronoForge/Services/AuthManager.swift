import Foundation
import SwiftUI

/// Manages JWT token and authentication state.
@MainActor
final class AuthManager: ObservableObject {
    @AppStorage("auth_token") private(set) var token: String = ""
    @AppStorage("user_email") private(set) var email: String = ""
    @Published var isAuthenticated: Bool = false

    static let shared = AuthManager()

    private init() {
        isAuthenticated = !token.isEmpty
    }

    func setToken(_ newToken: String, email: String?) {
        self.token = newToken
        self.email = email ?? ""
        self.isAuthenticated = true
    }

    func logout() {
        self.token = ""
        self.email = ""
        self.isAuthenticated = false
    }

    var currentToken: String? {
        token.isEmpty ? nil : token
    }
}
