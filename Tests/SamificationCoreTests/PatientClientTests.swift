import XCTest
@testable import SamificationCore

private actor PatientTransport: StaffHTTPTransport {
    var requests: [URLRequest] = []
    let response: String
    init(response: String) { self.response = response }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        return (Data(response.utf8),HTTPURLResponse(url: request.url!,statusCode:200,httpVersion:nil,headerFields:nil)!)
    }
    func captured() -> [URLRequest] { requests }
}
final class PatientClientTests: XCTestCase {
    private func client(_ transport: PatientTransport) throws -> StaffAccessClient {
        try StaffAccessClient(url:"https://vqexfcvzoryocjnzjozv.supabase.co",publishableKey:"sb_publishable_test_only",transport:transport)
    }
    func testTemporaryPatientSignInUsesNoEmailOrStaffToken() async throws {
        let transport = PatientTransport(response:"{\"access_token\":\"fictional-token\",\"user\":{\"id\":\"00000000-0000-4000-8000-000000000050\"}}")
        let session = try await client(transport).beginPatientSession()
        XCTAssertNil(session.user.email)
        let request = await transport.captured()[0]
        XCTAssertEqual(request.url?.path,"/auth/v1/signup")
        XCTAssertNil(request.value(forHTTPHeaderField:"Authorization"))
        let body = try JSONSerialization.jsonObject(with:request.httpBody!) as! [String:Any]
        XCTAssertTrue(body.isEmpty)
    }
    func testPairingValidatesFormatAndNormalizesCodeForBackendHash() async throws {
        let transport = PatientTransport(response:"\"00000000-0000-4000-8000-000000000060\"")
        let api = try client(transport)
        do { _ = try await api.claimPairing(code:"bad code",token:"test"); XCTFail("Invalid code must not be sent") } catch {}
        var requests = await transport.captured(); XCTAssertTrue(requests.isEmpty)
        _ = try await api.claimPairing(code:" ABCDEFAB-0000-4000-8000-000000000050 ",token:"patient-token")
        requests = await transport.captured()
        let body = try JSONSerialization.jsonObject(with:requests[0].httpBody!) as! [String:Any]
        XCTAssertEqual(body["pairing_token"] as? String,"abcdefab-0000-4000-8000-000000000050")
        XCTAssertEqual(requests[0].value(forHTTPHeaderField:"Authorization"),"Bearer patient-token")
    }
    func testPatientInboxDecodesAssignedReferenceOnly() async throws {
        let json = """
        [{"id":"00000000-0000-4000-8000-000000000060","admission_id":"00000000-0000-4000-8000-000000000070","patient_alias":"Fictional patient","regimen_version":1,"practice":false,"status":"assigned","medications":[{"id":"00000000-0000-4000-8000-000000000080","code":"A","name":"Fictional Tablet","doseMG":10,"strengthMG":10,"periods":["bedtime"],"directions":"Fictional instruction"}]}]
        """
        let transport = PatientTransport(response:json)
        let inbox = try await client(transport).patientInbox(token:"test")
        XCTAssertEqual(inbox.count,1); XCTAssertEqual(inbox[0].regimen_version,1)
        XCTAssertEqual(inbox[0].medications[0].periods,[.bedtime])
        let request = await transport.captured()[0]
        XCTAssertEqual(request.url?.path,"/rest/v1/rpc/patient_challenge_inbox")
        XCTAssertEqual(request.httpMethod,"POST")
    }
}
