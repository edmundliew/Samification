import XCTest
@testable import SamificationCore

private actor RenewalTransport: StaffHTTPTransport {
    private var requests: [URLRequest] = []
    private var waiters: [CheckedContinuation<Void, Never>] = []
    let refreshedUser: UUID
    let invalid: Bool
    init(user: UUID, invalid: Bool = false) { refreshedUser = user; self.invalid = invalid }
    func waitForCall() async {
        if !requests.isEmpty { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request); waiters.forEach { $0.resume() }; waiters = []
        try await Task.sleep(for: .milliseconds(30))
        let refresh = request.url!.path == "/auth/v1/token"
        let response = invalid && refresh ? "{\"code\":\"refresh_token_not_found\"}" : "{\"access_token\":\"new-access\",\"refresh_token\":\"rotated-refresh\",\"expires_at\":9000,\"user\":{\"id\":\"\(refreshedUser)\"}}"
        return (Data(response.utf8), HTTPURLResponse(url: request.url!, statusCode: invalid && refresh ? 400 : 200, httpVersion: nil, headerFields: nil)!)
    }
    func captured() -> [URLRequest] { requests }
}
final class PatientSessionProviderTests: XCTestCase {
    private let user = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
    private func makeSession(expiry: Int) throws -> StaffSession {
        try JSONDecoder().decode(StaffSession.self, from: Data("{\"access_token\":\"old-access\",\"refresh_token\":\"old-refresh\",\"expires_at\":\(expiry),\"user\":{\"id\":\"\(user)\"}}".utf8))
    }
    private func client(_ transport: RenewalTransport) throws -> StaffAccessClient {
        try StaffAccessClient(url: "https://vqexfcvzoryocjnzjozv.supabase.co", publishableKey: "sb_publishable_test_only", transport: transport)
    }
    func testExpiryPolicyTreatsUnknownAndBoundaryAsNeedingRenewal() throws {
        let now = Date(timeIntervalSince1970: 1000)
        XCTAssertTrue(try makeSession(expiry: 1060).needsRenewal(at: now))
        XCTAssertFalse(try makeSession(expiry: 1061).needsRenewal(at: now))
        let legacy = try JSONDecoder().decode(StaffSession.self, from: Data("{\"access_token\":\"old\",\"user\":{\"id\":\"\(user)\"}}".utf8))
        XCTAssertTrue(legacy.needsRenewal(at: now))
    }
    func testFreshSessionDoesNotRequestOrExtendPairing() async throws {
        let transport = RenewalTransport(user: user)
        let provider = try PatientSessionProvider(session: makeSession(expiry: 5000), client: client(transport))
        let value = try await provider.current(now: Date(timeIntervalSince1970: 1000))
        XCTAssertEqual(value.access_token, "old-access")
        let calls = await transport.captured(); XCTAssertTrue(calls.isEmpty)
    }
    func testConcurrentExpiryRenewsOnceAndRetainsSamePatientIdentity() async throws {
        let transport = RenewalTransport(user: user)
        let provider = try PatientSessionProvider(session: makeSession(expiry: 1020), client: client(transport))
        async let first = provider.current(now: Date(timeIntervalSince1970: 1000))
        async let second = provider.current(now: Date(timeIntervalSince1970: 1000))
        let values = try await [first, second]
        XCTAssertTrue(values.allSatisfy { $0.user.id == user && $0.refresh_token == "rotated-refresh" })
        _ = try await provider.current(now: Date(timeIntervalSince1970: 1000))
        let calls = await transport.captured(); XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].url!.path, "/auth/v1/token")
        let body = try JSONSerialization.jsonObject(with: calls[0].httpBody!) as! [String: String]
        XCTAssertEqual(body, ["refresh_token": "old-refresh"])
    }
    func testRenewalCannotSwitchPatientIdentity() async throws {
        let transport = RenewalTransport(user: UUID())
        let provider = try PatientSessionProvider(session: makeSession(expiry: 1020), client: client(transport))
        do { _ = try await provider.current(now: Date(timeIntervalSince1970: 1000)); XCTFail("Changed identity accepted") } catch StaffAPIError.authentication {} catch { XCTFail("Wrong error") }
        do { _ = try await provider.current(); XCTFail("Invalid identity retained") } catch StaffAPIError.authentication {} catch { XCTFail("Wrong error") }
        let calls = await transport.captured(); XCTAssertEqual(calls.count, 2)
        XCTAssertEqual(calls.last!.url!.path, "/auth/v1/logout")
    }
    func testInvalidRefreshRequiresPairingAgain() async throws {
        let transport = RenewalTransport(user: user, invalid: true)
        let provider = try PatientSessionProvider(session: makeSession(expiry: 1020), client: client(transport))
        do { _ = try await provider.current(now: Date(timeIntervalSince1970: 1000)); XCTFail("Invalid refresh accepted") } catch StaffAuthError.invalidRefresh {} catch { XCTFail("Wrong error") }
        do { _ = try await provider.current(); XCTFail("Expired session retained") } catch StaffAPIError.authentication {} catch { XCTFail("Wrong error") }
        let calls = await transport.captured(); XCTAssertEqual(calls.count, 1)
    }
    func testEndingSessionDuringRenewalCannotRestoreIt() async throws {
        let transport = RenewalTransport(user: user)
        let provider = try PatientSessionProvider(session: makeSession(expiry: 1020), client: client(transport))
        let task = Task { try await provider.current(now: Date(timeIntervalSince1970: 1000)) }
        await transport.waitForCall(); await provider.invalidate()
        do { _ = try await task.value; XCTFail("Ended session restored") } catch {}
        do { _ = try await provider.current(); XCTFail("Ended session retained") } catch StaffAPIError.authentication {} catch { XCTFail("Wrong error") }
    }
}
