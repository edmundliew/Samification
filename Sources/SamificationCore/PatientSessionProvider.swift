import Foundation

// Memory-only renewal of an existing patient identity. This never issues or extends
// an admission pairing grant; the server still authorizes every clinical request.
public actor PatientSessionProvider {
    private var session: StaffSession?
    private let client: StaffAccessClient
    private var renewal: Task<StaffSession, Error>?
    private var generation = 0
    public init(session: StaffSession, client: StaffAccessClient) {
        self.session = session; self.client = client
    }
    public func current(forceRefresh: Bool = false, now: Date = Date()) async throws -> StaffSession {
        guard let saved = session else { throw StaffAPIError.authentication }
        if renewal == nil, !forceRefresh, !saved.needsRenewal(at: now) {
            return saved
        }
        let task: Task<StaffSession, Error>
        if let active = renewal { task = active }
        else {
            guard let refresh = saved.refresh_token, !refresh.isEmpty else { throw StaffAuthError.invalidRefresh }
            let client = client
            task = Task {
                let refreshed = try await client.refreshSession(refreshToken: refresh)
                guard refreshed.user.id == saved.user.id else {
                    try? await client.signOut(token: refreshed.access_token)
                    throw StaffAPIError.authentication
                }
                return refreshed
            }
            renewal = task
        }
        let expectedGeneration = generation
        do {
            let refreshed = try await task.value
            guard generation == expectedGeneration else { throw StaffAPIError.authentication }
            session = refreshed; renewal = nil
            return refreshed
        } catch {
            if generation == expectedGeneration {
                renewal = nil
                if case StaffAuthError.invalidRefresh = error { session = nil }
                if case StaffAPIError.authentication = error { session = nil }
            }
            throw error
        }
    }
    public func invalidate() {
        generation += 1; session = nil; renewal?.cancel(); renewal = nil
    }
}
