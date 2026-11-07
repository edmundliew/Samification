import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct StaffSession: Decodable, Sendable {
    public struct User: Decodable, Sendable { public let id: UUID; public let email: String? }
    public let access_token: String
    public let user: User
}
public struct CareScope: Decodable, Identifiable, Sendable { public let id: UUID; public let name: String; public let active: Bool }
public struct StaffMembership: Decodable, Identifiable, Sendable {
    public let id: UUID; public let user_id: UUID; public let role: String; public let scope_id: UUID?; public let active: Bool
}
public struct StaffAccessRequest: Decodable, Identifiable, Sendable {
    public let id: UUID; public let user_id: UUID; public let scope_id: UUID
    public let display_name: String; public let status: String
}
public enum StaffAPIError: Error, LocalizedError {
    case configuration, authentication, forbidden, rejected, unavailable
    public var errorDescription: String? {
        switch self {
        case .configuration: return "Supabase configuration is missing or invalid."
        case .authentication: return "Sign in again. Your code or session may have expired."
        case .forbidden: return "This account does not have permission for that action."
        case .rejected: return "The request was not accepted. Refresh the list and check your details."
        case .unavailable: return "Unable to reach the service. Try again later."
        }
    }
}
public protocol StaffHTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}
extension URLSession: StaffHTTPTransport {}

// Session tokens live in memory only in this development milestone. No token logging or UserDefaults storage.
public struct StaffAccessClient: Sendable {
    private let baseURL: URL
    private let publishableKey: String
    private let transport: any StaffHTTPTransport
    public init(url: String, publishableKey: String, transport: any StaffHTTPTransport = URLSession(configuration: .ephemeral)) throws {
        guard let parsed = URL(string: url), parsed.scheme == "https", parsed.host == "vqexfcvzoryocjnzjozv.supabase.co",
              parsed.user == nil, parsed.password == nil, parsed.query == nil, parsed.fragment == nil,
              parsed.port == nil, parsed.path.isEmpty || parsed.path == "/",
              publishableKey.hasPrefix("sb_publishable_"), !publishableKey.contains("REPLACE") else { throw StaffAPIError.configuration }
        self.baseURL = parsed; self.publishableKey = publishableKey; self.transport = transport
    }
    func request(_ path: String, method: String = "GET", body: [String: Any]? = nil, token: String? = nil) async throws -> Data {
        guard let url = URL(string: path, relativeTo: baseURL) else { throw StaffAPIError.configuration }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.httpMethod = method
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let result: (Data, URLResponse)
        do { result = try await transport.data(for: request) } catch { throw StaffAPIError.unavailable }
        guard let response = result.1 as? HTTPURLResponse else { throw StaffAPIError.unavailable }
        switch response.statusCode {
        case 200..<300: return result.0
        case 401: throw StaffAPIError.authentication
        case 403: throw StaffAPIError.forbidden
        case 400..<500: throw StaffAPIError.rejected
        default: throw StaffAPIError.unavailable
        }
    }
    public func sendCode(email: String) async throws {
        _ = try await request("/auth/v1/otp", method: "POST", body: ["email": email, "create_user": true])
    }
    public func verifyCode(email: String, code: String) async throws -> StaffSession {
        guard Self.validEmailCode(code) else { throw StaffAPIError.rejected }
        let data = try await request("/auth/v1/verify", method: "POST", body: ["email": email, "token": code, "type": "email"])
        return try JSONDecoder().decode(StaffSession.self, from: data)
    }
    // Consume the original email verification link through the JSON endpoint.
    // Never visit the link or its redirect destination, and never persist its token.
    public static func validEmailLink(_ text: String) -> Bool { (try? emailLinkParameters(text)) != nil }
    public static func validEmailCode(_ text: String) -> Bool {
        let code = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return (6...10).contains(code.count) && code.allSatisfy { $0.isASCII && $0.isNumber }
    }
    private static func emailLinkParameters(_ text: String) throws -> (String, String) {
        guard text.utf8.count <= 4096,
              let url = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https", url.host == "vqexfcvzoryocjnzjozv.supabase.co", url.port == nil,
              url.user == nil, url.password == nil, url.path == "/auth/v1/verify", url.fragment == nil else { throw StaffAPIError.rejected }
        let items = url.queryItems ?? []
        let tokens = items.filter { $0.name == "token" || $0.name == "token_hash" }
        let types = items.filter { $0.name == "type" }
        guard tokens.count == 1, types.count == 1, let hash = tokens[0].value,
              (20...256).contains(hash.count), hash.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }),
              let type = types[0].value, ["email", "signup", "magiclink"].contains(type) else { throw StaffAPIError.rejected }
        return (hash, type)
    }
    public func verifyEmailLink(_ text: String, expectedEmail: String) async throws -> StaffSession {
        let (hash, type) = try Self.emailLinkParameters(text)
        let data = try await request("/auth/v1/verify", method: "POST", body: ["token_hash": hash, "type": type])
        let session = try JSONDecoder().decode(StaffSession.self, from: data)
        guard session.user.email?.caseInsensitiveCompare(expectedEmail.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame else {
            try? await signOut(token: session.access_token)
            throw StaffAPIError.authentication
        }
        return session
    }
    public func signOut(token: String) async throws { _ = try await request("/auth/v1/logout?scope=local", method: "POST", token: token) }
    public func scopes(token: String) async throws -> [CareScope] {
        try await decode([CareScope].self, path: "/rest/v1/care_scopes?select=id,name,active&order=name", token: token)
    }
    public func memberships(token: String) async throws -> [StaffMembership] {
        try await decode([StaffMembership].self, path: "/rest/v1/staff_memberships?select=id,user_id,role,scope_id,active", token: token)
    }
    public func requests(token: String) async throws -> [StaffAccessRequest] {
        try await decode([StaffAccessRequest].self, path: "/rest/v1/staff_access_requests?select=id,user_id,scope_id,display_name,status&order=requested_at.desc", token: token)
    }
    func decode<T: Decodable>(_ type: T.Type, path: String, token: String) async throws -> T {
        try await JSONDecoder().decode(type, from: request(path, token: token))
    }
    public func requestAccess(scope: UUID, name: String, token: String) async throws {
        _ = try await request("/rest/v1/rpc/request_clinician_access", method: "POST", body: ["wanted_scope": scope.uuidString, "requested_name": name], token: token)
    }
    public func decide(requestID: UUID, approve: Bool, reason: String, token: String) async throws {
        _ = try await request("/rest/v1/rpc/decide_clinician_access", method: "POST", body: ["request_id": requestID.uuidString, "approve": approve, "decision_reason": reason], token: token)
    }
    public func setAccess(membershipID: UUID, enabled: Bool, reason: String, token: String) async throws {
        _ = try await request("/rest/v1/rpc/set_clinician_access", method: "POST", body: ["membership_id": membershipID.uuidString, "enabled": enabled, "change_reason": reason], token: token)
    }
}
