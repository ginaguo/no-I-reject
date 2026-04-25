//
//  Sync.swift
//  NoIReject
//
//  Supabase REST + Auth client, AuthService, and MomentStore.
//  Uses URLSession only — no external dependencies needed.
//

import Foundation
import Combine

// MARK: - Config

enum SupabaseConfig {
    // Same project as the web app (see docs/app.js)
    static let url = URL(string: "https://xrvokelhhoxrqgdpgula.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhydm9rZWxoaG94cnFnZHBndWxhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUzMjgyMjIsImV4cCI6MjA5MDkwNDIyMn0.XhT2hzXoOmq5dcawG39wCpiyojkvX3TR6A-206e-mQ4"
}

// MARK: - Errors

struct SupabaseError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// MARK: - Session model

struct StoredSession: Codable {
    var accessToken: String
    var refreshToken: String
    var userId: String
    var email: String?
    var expiresAt: Date
}

// MARK: - REST client

final class SupabaseClient {
    static let shared = SupabaseClient()

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        return URLSession(configuration: cfg)
    }()

    // MARK: Auth

    struct AuthResponse: Decodable {
        let access_token: String?
        let refresh_token: String?
        let expires_in: Int?
        let user: AuthUser?
        // sign-up may return only user (no session) when email confirmation is required
        let id: String?           // not normally present at top level
        let msg: String?
        let error_description: String?
        let error: String?
    }
    struct AuthUser: Decodable { let id: String; let email: String? }

    func signIn(email: String, password: String) async throws -> StoredSession {
        let url = SupabaseConfig.url.appendingPathComponent("auth/v1/token")
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "grant_type", value: "password")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": email, "password": password
        ])
        return try await performAuth(req)
    }

    func signUp(email: String, password: String) async throws -> StoredSession {
        let url = SupabaseConfig.url.appendingPathComponent("auth/v1/signup")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": email, "password": password
        ])
        return try await performAuth(req)
    }

    func refresh(refreshToken: String) async throws -> StoredSession {
        let url = SupabaseConfig.url.appendingPathComponent("auth/v1/token")
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "refresh_token": refreshToken
        ])
        return try await performAuth(req)
    }

    func signOut(accessToken: String) async {
        let url = SupabaseConfig.url.appendingPathComponent("auth/v1/logout")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        _ = try? await session.data(for: req)
    }

    /// Exchange an Apple identity token for a Supabase session.
    /// `rawNonce` must be the unhashed nonce string used when requesting the Apple credential
    /// (Supabase verifies it against the hashed nonce embedded in the id_token).
    func signInWithApple(idToken: String, rawNonce: String) async throws -> StoredSession {
        let url = SupabaseConfig.url.appendingPathComponent("auth/v1/token")
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "grant_type", value: "id_token")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "provider": "apple",
            "id_token": idToken,
            "nonce": rawNonce
        ])
        return try await performAuth(req)
    }

    private func performAuth(_ req: URLRequest) async throws -> StoredSession {
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw SupabaseError(message: "No response") }
        if !(200...299).contains(http.statusCode) {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0["msg"] as? String ?? $0["error_description"] as? String ?? $0["error"] as? String }
                ?? String(data: data, encoding: .utf8) ?? "Auth failed (\(http.statusCode))"
            throw SupabaseError(message: msg)
        }
        let decoded = try JSONDecoder().decode(AuthResponse.self, from: data)
        guard let access = decoded.access_token,
              let refresh = decoded.refresh_token,
              let user = decoded.user else {
            throw SupabaseError(message: "Account created — check your email to confirm, then sign in.")
        }
        let expiresIn = TimeInterval(decoded.expires_in ?? 3600)
        return StoredSession(
            accessToken: access,
            refreshToken: refresh,
            userId: user.id,
            email: user.email,
            expiresAt: Date().addingTimeInterval(expiresIn - 60)
        )
    }

    // MARK: REST — moments

    private func restRequest(_ method: String, path: String, query: [URLQueryItem] = [],
                             body: Data? = nil, prefer: String? = nil,
                             accessToken: String) -> URLRequest {
        var comps = URLComponents(url: SupabaseConfig.url.appendingPathComponent("rest/v1/\(path)"),
                                  resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let prefer { req.setValue(prefer, forHTTPHeaderField: "Prefer") }
        req.httpBody = body
        return req
    }

    func fetchMoments(userId: String, accessToken: String) async throws -> [Moment] {
        let req = restRequest("GET", path: "moments",
                              query: [
                                URLQueryItem(name: "user_id", value: "eq.\(userId)"),
                                URLQueryItem(name: "order", value: "created_at.desc"),
                                URLQueryItem(name: "select", value: "*")
                              ],
                              accessToken: accessToken)
        let (data, resp) = try await session.data(for: req)
        try validate(resp, data: data)
        return try Moment.decodeArray(data)
    }

    func insertMoment(_ moment: Moment, userId: String, accessToken: String) async throws {
        let body = try moment.encodeForInsert(userId: userId)
        let req = restRequest("POST", path: "moments",
                              body: body,
                              prefer: "return=minimal",
                              accessToken: accessToken)
        let (data, resp) = try await session.data(for: req)
        try validate(resp, data: data)
    }

    func deleteMoment(id: UUID, userId: String, accessToken: String) async throws {
        let req = restRequest("DELETE", path: "moments",
                              query: [
                                URLQueryItem(name: "id", value: "eq.\(id.uuidString.lowercased())"),
                                URLQueryItem(name: "user_id", value: "eq.\(userId)")
                              ],
                              accessToken: accessToken)
        let (data, resp) = try await session.data(for: req)
        try validate(resp, data: data)
    }

    // MARK: REST — user_focus

    private struct FocusRow: Codable {
        let user_id: String?
        let goals: String?
        let helpers: String?
        let updated_at: String?
    }

    /// Returns (goals, helpers, updatedAt) or nil if no row exists yet.
    func fetchFocus(userId: String, accessToken: String) async throws -> (goals: String, helpers: String, updatedAt: Date?)? {
        let req = restRequest("GET", path: "user_focus",
                              query: [
                                URLQueryItem(name: "user_id", value: "eq.\(userId)"),
                                URLQueryItem(name: "select", value: "goals,helpers,updated_at"),
                                URLQueryItem(name: "limit", value: "1")
                              ],
                              accessToken: accessToken)
        let (data, resp) = try await session.data(for: req)
        try validate(resp, data: data)
        let rows = try JSONDecoder().decode([FocusRow].self, from: data)
        guard let row = rows.first else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let updated = row.updated_at.flatMap { s in
            formatter.date(from: s) ?? ISO8601DateFormatter().date(from: s)
        }
        return (row.goals ?? "", row.helpers ?? "", updated)
    }

    func upsertFocus(userId: String, goals: String, helpers: String, accessToken: String) async throws -> Date {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let body = try JSONSerialization.data(withJSONObject: [
            "user_id": userId,
            "goals": goals,
            "helpers": helpers,
            "updated_at": formatter.string(from: now)
        ])
        var comps = URLComponents(url: SupabaseConfig.url.appendingPathComponent("rest/v1/user_focus"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "on_conflict", value: "user_id")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = body
        let (data, resp) = try await session.data(for: req)
        try validate(resp, data: data)
        return now
    }

    // MARK: REST — user_custom_tags

    private struct CustomTagsRow: Codable {
        let user_id: String?
        let tags: [String]?
        let updated_at: String?
    }

    func fetchCustomTags(userId: String, accessToken: String) async throws -> (tags: [String], updatedAt: Date?)? {
        let req = restRequest("GET", path: "user_custom_tags",
                              query: [
                                URLQueryItem(name: "user_id", value: "eq.\(userId)"),
                                URLQueryItem(name: "select", value: "tags,updated_at"),
                                URLQueryItem(name: "limit", value: "1")
                              ],
                              accessToken: accessToken)
        let (data, resp) = try await session.data(for: req)
        try validate(resp, data: data)
        let rows = try JSONDecoder().decode([CustomTagsRow].self, from: data)
        guard let row = rows.first else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let updated = row.updated_at.flatMap { s in
            formatter.date(from: s) ?? ISO8601DateFormatter().date(from: s)
        }
        return (row.tags ?? [], updated)
    }

    func upsertCustomTags(userId: String, tags: [String], accessToken: String) async throws -> Date {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let body = try JSONSerialization.data(withJSONObject: [
            "user_id": userId,
            "tags": tags,
            "updated_at": formatter.string(from: now)
        ])
        var comps = URLComponents(url: SupabaseConfig.url.appendingPathComponent("rest/v1/user_custom_tags"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "on_conflict", value: "user_id")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = body
        let (data, resp) = try await session.data(for: req)
        try validate(resp, data: data)
        return now
    }

    private func validate(_ resp: URLResponse, data: Data) throws {
        guard let http = resp as? HTTPURLResponse else {
            throw SupabaseError(message: "No response")
        }
        if !(200...299).contains(http.statusCode) {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw SupabaseError(message: "Request failed (\(http.statusCode)): \(msg)")
        }
    }
}

// MARK: - AuthService

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var session: StoredSession?
    @Published var isAuthenticating = false
    @Published var errorMessage: String?

    private let storageKey = "noireject.session.v1"

    init() {
        loadSession()
    }

    var isLoggedIn: Bool { session != nil }
    var userId: String? { session?.userId }
    var email: String? { session?.email }

    func signIn(email: String, password: String) async {
        await runAuth { try await SupabaseClient.shared.signIn(email: email, password: password) }
    }

    func signUp(email: String, password: String) async {
        await runAuth { try await SupabaseClient.shared.signUp(email: email, password: password) }
    }

    func signInWithApple(idToken: String, rawNonce: String) async {
        await runAuth {
            try await SupabaseClient.shared.signInWithApple(idToken: idToken, rawNonce: rawNonce)
        }
    }

    func reportAuthError(_ message: String) {
        errorMessage = message
    }

    func signOut() async {
        if let token = session?.accessToken {
            await SupabaseClient.shared.signOut(accessToken: token)
        }
        session = nil
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    /// Returns a valid access token, refreshing if expired.
    func validAccessToken() async throws -> (token: String, userId: String) {
        guard var s = session else { throw SupabaseError(message: "Not logged in") }
        if s.expiresAt <= Date() {
            s = try await SupabaseClient.shared.refresh(refreshToken: s.refreshToken)
            persist(s)
        }
        return (s.accessToken, s.userId)
    }

    private func runAuth(_ op: () async throws -> StoredSession) async {
        isAuthenticating = true
        errorMessage = nil
        defer { isAuthenticating = false }
        do {
            let s = try await op()
            persist(s)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persist(_ s: StoredSession) {
        session = s
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadSession() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let s = try? JSONDecoder().decode(StoredSession.self, from: data) else { return }
        session = s
        // Refresh in background if needed
        if s.expiresAt <= Date() {
            Task { _ = try? await validAccessToken() }
        }
    }
}

// MARK: - MomentStore

@MainActor
final class MomentStore: ObservableObject {
    @Published private(set) var moments: [Moment] = []
    @Published var isLoading = false
    @Published var lastError: String?

    private let auth: AuthService
    private let cacheKey = "noireject.moments.cache.v1"

    init(auth: AuthService) {
        self.auth = auth
        loadCache()
    }

    func reload() async {
        guard auth.isLoggedIn else { moments = []; return }
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            let (token, uid) = try await auth.validAccessToken()
            let fetched = try await SupabaseClient.shared.fetchMoments(userId: uid, accessToken: token)
            moments = fetched
            saveCache()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func add(_ moment: Moment) async {
        // Optimistic insert
        moments.insert(moment, at: 0)
        saveCache()
        do {
            let (token, uid) = try await auth.validAccessToken()
            try await SupabaseClient.shared.insertMoment(moment, userId: uid, accessToken: token)
        } catch {
            lastError = error.localizedDescription
            moments.removeAll { $0.id == moment.id }
            saveCache()
        }
    }

    func delete(_ moment: Moment) async {
        let backup = moments
        moments.removeAll { $0.id == moment.id }
        saveCache()
        do {
            let (token, uid) = try await auth.validAccessToken()
            try await SupabaseClient.shared.deleteMoment(id: moment.id, userId: uid, accessToken: token)
        } catch {
            lastError = error.localizedDescription
            moments = backup
            saveCache()
        }
    }

    func clear() {
        moments = []
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }

    private func saveCache() {
        if let data = try? JSONEncoder().encode(moments) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode([Moment].self, from: data) else { return }
        moments = cached
    }
}
