import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct StaffSession: Codable, Sendable {
    public struct User: Codable, Sendable { public let id: UUID; public let email: String? }
    public let access_token: String
    public let refresh_token: String?
    public let expires_at: TimeInterval?
    public let user: User
    public func needsRenewal(at now: Date = Date()) -> Bool {
        guard let expires_at else { return true }
        return expires_at <= now.timeIntervalSince1970 + 60
    }
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
        case .authentication: return "Your sign-in has expired. Please sign in again."
        case .forbidden: return "This account does not have permission for that action."
        case .rejected: return "The request was not accepted. Refresh the list and check your details."
        case .unavailable: return "Unable to reach the service. Try again later."
        }
    }
}
public enum StaffAuthError: Error, LocalizedError {
    case expiredLink, emailRateLimited, emailDeliveryRestricted, verificationFailed, invalidCredentials, emailUnconfirmed, invalidRefresh, weakPassword
    public var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Email or password is incorrect. If you previously used an email link, set up a password first."
        case .emailUnconfirmed: return "Confirm your email before signing in."
        case .invalidRefresh: return "Your saved sign-in has expired. Sign in again."
        case .weakPassword: return "Choose a stronger password with at least 12 characters."
        case .expiredLink: return "This sign-in link is invalid, expired or already used (otp_expired). Use a fresh unopened email link. This is not a staff-permission decision."
        case .emailRateLimited: return "Supabase has reached its email-sending limit (over_email_send_rate_limit). No new email was sent. Wait for the limit to reset or configure the sender service."
        case .emailDeliveryRestricted: return "The current email service cannot send to this address (email_address_not_authorized). Sender configuration is required."
        case .verificationFailed: return "Supabase could not verify this sign-in link or code. Use the newest unopened link and check that the email address matches."
        }
    }
}
public protocol StaffHTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}
extension URLSession: StaffHTTPTransport {}

// Callers may persist session tokens in the platform Keychain. Never log them or store passwords.
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
        // Auth uses HTTP 403 for expired OTPs too. Interpret its machine code,
        // without reflecting server messages or credentials into logs/UI.
        if path.hasPrefix("/auth/v1/"), (400..<500).contains(response.statusCode) {
            let detail = (try? JSONSerialization.jsonObject(with: result.0)) as? [String: Any]
            let code = detail?["error_code"] as? String ?? detail?["code"] as? String
            switch code {
            case "invalid_credentials": throw StaffAuthError.invalidCredentials
            case "email_not_confirmed": throw StaffAuthError.emailUnconfirmed
            case "refresh_token_not_found", "refresh_token_already_used", "session_not_found", "session_expired": throw StaffAuthError.invalidRefresh
            case "invalid_grant":
                if path.contains("grant_type=refresh_token") { throw StaffAuthError.invalidRefresh }
                throw StaffAuthError.invalidCredentials
            case "weak_password": throw StaffAuthError.weakPassword
            case "otp_expired": throw StaffAuthError.expiredLink
            case "over_email_send_rate_limit": throw StaffAuthError.emailRateLimited
            case "email_address_not_authorized": throw StaffAuthError.emailDeliveryRestricted
            default:
                if path == "/auth/v1/verify" { throw StaffAuthError.verificationFailed }
            }
        }
        switch response.statusCode {
        case 200..<300: return result.0
        case 401: throw StaffAPIError.authentication
        case 403: throw StaffAPIError.forbidden
        case 400..<500: throw StaffAPIError.rejected
        default: throw StaffAPIError.unavailable
        }
    }
    public func signInWithPassword(email: String, password: String) async throws -> StaffSession {
        guard !password.isEmpty, password.utf8.count <= 4096 else { throw StaffAuthError.invalidCredentials }
        return try await JSONDecoder().decode(StaffSession.self, from: request("/auth/v1/token?grant_type=password", method: "POST", body: ["email": email.trimmingCharacters(in: .whitespacesAndNewlines), "password": password]))
    }
    public func refreshSession(refreshToken: String) async throws -> StaffSession {
        guard !refreshToken.isEmpty else { throw StaffAuthError.invalidRefresh }
        return try await JSONDecoder().decode(StaffSession.self, from: request("/auth/v1/token?grant_type=refresh_token", method: "POST", body: ["refresh_token": refreshToken]))
    }
    public func setPassword(_ password: String, token: String) async throws {
        guard password.count >= 12, password.utf8.count <= 4096 else { throw StaffAuthError.weakPassword }
        _ = try await request("/auth/v1/user", method: "PUT", body: ["password": password], token: token)
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
    // Parse copied email/Markdown and bounded Safe Links wrappers locally. Never follow URLs.
    private static func emailLinkParameters(_ text: String) throws -> (String, String) {
        guard text.utf8.count <= 16384 else { throw StaffAPIError.rejected }
        let normalized = text.replacingOccurrences(of: "\\&", with: "&").replacingOccurrences(of: "&amp;", with: "&")
        let regex = try NSRegularExpression(pattern: #"https://[^\s<>"()]+"#)
        let matches = regex.matches(in: normalized, range: NSRange(normalized.startIndex..., in: normalized))
        guard !matches.isEmpty, matches.count <= 32 else { throw StaffAPIError.rejected }
        var credentials: [String: (String, String)] = [:]
        for match in matches {
            guard let range = Range(match.range, in: normalized) else { continue }
            var candidate = String(normalized[range])
            for _ in 0..<3 {
                guard let wrapper = URLComponents(string: candidate), let host = wrapper.host?.lowercased(),
                      host == "safelinks.protection.outlook.com" || host.hasSuffix(".safelinks.protection.outlook.com") else { break }
                guard wrapper.scheme == "https", wrapper.user == nil, wrapper.password == nil, wrapper.port == nil,
                      let items = wrapper.queryItems, items.filter({ $0.name == "url" }).count == 1,
                      let inner = items.first(where: { $0.name == "url" })?.value else { throw StaffAPIError.rejected }
                candidate = inner
            }
            if let pair = try? directEmailLinkParameters(candidate) { credentials[pair.0 + ":" + pair.1] = pair }
        }
        guard credentials.count == 1, let pair = credentials.values.first else { throw StaffAPIError.rejected }
        return pair
    }
    private static func directEmailLinkParameters(_ text: String) throws -> (String, String) {
        guard text.utf8.count <= 16384,
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
