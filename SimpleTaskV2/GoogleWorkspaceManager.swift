import Foundation
import SwiftUI
import GoogleSignIn
internal import Combine

class GoogleWorkspaceManager: ObservableObject {
    static let shared = GoogleWorkspaceManager()
    
    @Published var isSignedIn = false
    @Published var currentUserEmail: String? = nil
    
    // Placeholder access token for API calls
    public var accessToken: String? = nil
    
    init() {}
    
    // MARK: - Authentication
    
    @MainActor
    private func getRootViewController() -> UIViewController? {
        guard let screen = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = screen.windows.first?.rootViewController else {
            return nil
        }
        var topController = root
        while let presented = topController.presentedViewController {
            topController = presented
        }
        return topController
    }
    
    @MainActor
    func signIn() async throws {
        guard let presentingVC = getRootViewController() else {
            print("Could not find root view controller")
            return
        }
        
        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: presentingVC,
            hint: nil,
            additionalScopes: ["https://www.googleapis.com/auth/gmail.readonly", "https://www.googleapis.com/auth/cloud-platform"]
        )
        
        self.accessToken = result.user.accessToken.tokenString
        self.currentUserEmail = result.user.profile?.email
        self.isSignedIn = true
        print("Google Sign-In flow completed.")
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        self.isSignedIn = false
        self.currentUserEmail = nil
        self.accessToken = nil
    }
    
    // MARK: - Gmail API
    
    /// Fetches recent important or starred emails from the last 24 hours.
    func fetchRecentImportantEmails() async throws -> String {
        guard let token = accessToken else {
            // Throw error or handle unauthenticated state
            print("No access token for Gmail API.")
            return "[]"
        }
        
        let urlString = "https://gmail.googleapis.com/gmail/v1/users/me/messages?q=is:important OR is:starred newer_than:1d"
        guard let url = URL(string: urlString) else { return "[]" }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Execute request and decode... (stubbed)
        // let (data, _) = try await URLSession.shared.data(for: request)
        // return String(data: data, encoding: .utf8) ?? "[]"
        
        return "[\"Stubbed Gmail Response\"]"
    }
    
    // MARK: - Google Drive API
    
    /// Fetches recently modified Google Docs
    func fetchRecentDocs() async throws -> String {
        guard let token = accessToken else {
            print("No access token for Drive API.")
            return "[]"
        }
        
        let urlString = "https://www.googleapis.com/drive/v3/files?q=mimeType='application/vnd.google-apps.document' and modifiedTime > '2026-06-16T00:00:00Z'"
        guard let url = URL(string: urlString) else { return "[]" }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Execute request and decode... (stubbed)
        // let (data, _) = try await URLSession.shared.data(for: request)
        // return String(data: data, encoding: .utf8) ?? "[]"
        
        return "[\"Stubbed Drive Response\"]"
    }
}
