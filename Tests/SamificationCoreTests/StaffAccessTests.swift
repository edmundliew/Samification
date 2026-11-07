import XCTest
@testable import SamificationCore

private actor MockStaffTransport: StaffHTTPTransport {
    let status: Int
    let body: Data
    var captured: [URLRequest] = []
    init(status: Int = 200, body: String = "[]") { self.status = status; self.body = Data(body.utf8) }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        captured.append(request)
        return (body, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
    func last() -> URLRequest? { captured.last }
}
final class StaffAccessTests: XCTestCase {
    private let url = "https://vqexfcvzoryocjnzjozv.supabase.co"
    private let key = "sb_publishable_unit_test_only"
    func testConfigurationRejectsOtherDestinationsAndSecretKeys() {
        for bad in ["http://vqexfcvzoryocjnzjozv.supabase.co", "https://example.com", url + "/other", url + "?token=x"] {
            XCTAssertThrowsError(try StaffAccessClient(url: bad, publishableKey: key))
        }
        XCTAssertThrowsError(try StaffAccessClient(url: url, publishableKey: "sb_secret_not_allowed"))
    }
    func testOTPSendsOnlyEmailAndPublishableKeyWithoutSessionBearer() async throws {
        let transport = MockStaffTransport(body: "{}")
        let client = try StaffAccessClient(url: url, publishableKey: key, transport: transport)
        try await client.sendCode(email: "fictional@example.invalid")
        let request = await transport.last()!
        XCTAssertEqual(request.url?.path, "/auth/v1/otp")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), key)
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        XCTAssertEqual(body["email"] as? String, "fictional@example.invalid")
        XCTAssertEqual(body["create_user"] as? Bool, true)
    }
    func testApprovalUsesAuthenticatedRPCAndDoesNotWriteMembershipDirectly() async throws {
        let transport = MockStaffTransport(body: "null")
        let client = try StaffAccessClient(url: url, publishableKey: key, transport: transport)
        let id = UUID()
        try await client.decide(requestID: id, approve: true, reason: "Fictional test", token: "test-session")
        let request = await transport.last()!
        XCTAssertEqual(request.url?.path, "/rest/v1/rpc/decide_clinician_access")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-session")
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        XCTAssertEqual(body["request_id"] as? String, id.uuidString)
        XCTAssertEqual(body["approve"] as? Bool, true)
    }
    func testServerPermissionsAndExpiredSessionAreNotSuccessful() async throws {
        for status in [401, 403, 409, 500] {
            let client = try StaffAccessClient(url: url, publishableKey: key, transport: MockStaffTransport(status: status))
            do { _ = try await client.memberships(token: "expired"); XCTFail("HTTP \(status) must not succeed") }
            catch let error as StaffAPIError {
                switch (status, error) {
                case (401,.authentication), (403,.forbidden), (409,.rejected), (500,.unavailable): break
                default: XCTFail("Wrong error for \(status)")
                }
            }
        }
    }
}

extension StaffAccessTests {
    func testEmailLinkUsesOnlyPinnedVerificationEndpoint() async throws {
        let transport = MockStaffTransport(body: "{\"access_token\":\"test-token\",\"user\":{\"id\":\"00000000-0000-4000-8000-000000000001\",\"email\":\"Fictional@example.invalid\"}}")
        let client = try StaffAccessClient(url: url, publishableKey: key, transport: transport)
        let session = try await client.verifyEmailLink(url + "/auth/v1/verify?token=" + String(repeating: "a", count: 64) + "&type=signup&redirect_to=https%3A%2F%2Fexample.invalid", expectedEmail: "fictional@example.invalid")
        XCTAssertEqual(session.user.email, "Fictional@example.invalid")
        let request = await transport.last()!
        XCTAssertEqual(request.url?.absoluteString, url + "/auth/v1/verify")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: String]
        XCTAssertEqual(body, ["token_hash": String(repeating: "a", count: 64), "type": "signup"])
    }
    func testEmailLinkRejectsOtherOriginsDuplicateTokensAndRecovery() async throws {
        let transport = MockStaffTransport()
        let client = try StaffAccessClient(url: url, publishableKey: key, transport: transport)
        let hash = String(repeating: "a", count: 64)
        let links = ["https://example.invalid/auth/v1/verify?token=\(hash)&type=email", url + "/auth/v1/verify?token=\(hash)&type=recovery", url + "/auth/v1/verify?token=\(hash)&token=\(hash)&type=email", url + "/auth/v1/verify?token=\(hash)&type=email&type=signup", url + "/auth/v1/verify?token=\(hash)&type=email#access_token=secret", url + ":443/auth/v1/verify?token=\(hash)&type=email"]
        for link in links {
            do { _ = try await client.verifyEmailLink(link, expectedEmail: "fictional@example.invalid"); XCTFail("Invalid link sent") } catch {}
        }
        let request = await transport.last()
        XCTAssertNil(request)
    }
    func testEmailLinkCannotSilentlySwitchStaffIdentity() async throws {
        let transport = MockStaffTransport(body: "{\"access_token\":\"test-token\",\"user\":{\"id\":\"00000000-0000-4000-8000-000000000001\",\"email\":\"other@example.invalid\"}}")
        let client = try StaffAccessClient(url: url, publishableKey: key, transport: transport)
        do { _ = try await client.verifyEmailLink(url + "/auth/v1/verify?token=" + String(repeating: "a", count: 64) + "&type=magiclink", expectedEmail: "fictional@example.invalid"); XCTFail("Identity mismatch accepted") } catch {}
        let last = await transport.last()!
        XCTAssertEqual(last.url?.path, "/auth/v1/logout")
        XCTAssertEqual(last.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
    }
}
