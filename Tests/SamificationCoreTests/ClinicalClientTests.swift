import XCTest
@testable import SamificationCore

private actor ClinicalTransport: StaffHTTPTransport {
    let responseID = UUID()
    var requests: [URLRequest] = []
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        return (try JSONEncoder().encode(responseID), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
    func captured() -> [URLRequest] { requests }
}
final class ClinicalClientTests: XCTestCase {
    private func client(_ transport: ClinicalTransport) throws -> StaffAccessClient {
        try StaffAccessClient(url: "https://vqexfcvzoryocjnzjozv.supabase.co", publishableKey: "sb_publishable_test_only", transport: transport)
    }
    func testRegimenUploadPreservesOriginalNameAndCSV() async throws {
        let transport = ClinicalTransport(); let client = try client(transport)
        var medications = DemoData.medications; medications[0].name = "Reviewed display name"
        _ = try await client.confirmRegimen(admissionID: UUID(), medications: medications, sourceCSV: "Fictional original CSV", token: "test")
        let request = await transport.captured()[0]
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let snapshot = body["medication_snapshot"] as! [[String: Any]]
        XCTAssertEqual(snapshot[0]["originalName"] as? String, "Rosuvastatin Tablet")
        XCTAssertEqual(snapshot[0]["name"] as? String, "Reviewed display name")
        XCTAssertEqual(body["source_csv"] as? String, "Fictional original CSV")
        XCTAssertEqual(request.url?.path, "/rest/v1/rpc/confirm_patient_regimen")
    }
    func testUnconfirmedRegimenDoesNotReachNetwork() async throws {
        let transport = ClinicalTransport(); let client = try client(transport)
        var medications = DemoData.medications; medications[0].confirmed = false
        do { _ = try await client.confirmRegimen(admissionID: UUID(), medications: medications, sourceCSV: nil, token: "test"); XCTFail("Must reject") } catch {}
        let requests = await transport.captured(); XCTAssertTrue(requests.isEmpty)
    }
    func testAdmissionAndRegimenRetriesPreserveRequestIDs() async throws {
        let transport = ClinicalTransport(); let client = try client(transport)
        let admissionRequest = PendingAdmissionSave(scope: UUID(), alias: "Fictional alias")
        let confirmation = PendingRegimenSave(admissionID: UUID(), medications: DemoData.medications, sourceCSV: "Fictional CSV")
        for _ in 0..<2 {
            _ = try await client.createAdmission(scope: admissionRequest.scope, alias: admissionRequest.alias, requestID: admissionRequest.id, token: "test")
            _ = try await client.confirmRegimen(admissionID: confirmation.admissionID, medications: confirmation.medications, sourceCSV: confirmation.sourceCSV, requestID: confirmation.id, token: "test")
        }
        let requests = await transport.captured()
        let bodies = try requests.map { try JSONSerialization.jsonObject(with: $0.httpBody!) as! [String: Any] }
        XCTAssertEqual(bodies[0]["request_id"] as? String, bodies[2]["request_id"] as? String)
        XCTAssertEqual(bodies[1]["request_id"] as? String, bodies[3]["request_id"] as? String)
        XCTAssertEqual(bodies[0]["request_id"] as? String, admissionRequest.id.uuidString)
        XCTAssertEqual(bodies[1]["request_id"] as? String, confirmation.id.uuidString)
    }
    func testAllExcludedAndDuplicateNamesAreRejectedBeforeUpload() async throws {
        let transport = ClinicalTransport(); let client = try client(transport)
        var excluded = DemoData.medications; excluded = excluded.map { var m = $0; m.included = false; return m }
        XCTAssertFalse(RegimenValidation.issues(for: excluded).isEmpty)
        var duplicate = DemoData.medications; duplicate[1].name = duplicate[0].name
        do { _ = try await client.confirmRegimen(admissionID: UUID(), medications: duplicate, sourceCSV: nil, token: "test"); XCTFail("Must reject duplicate names") } catch {}
        let requests = await transport.captured(); XCTAssertTrue(requests.isEmpty)
    }
    func testAssignmentRetryKeepsSameRequestIdentity() async throws {
        let transport = ClinicalTransport(); let client = try client(transport)
        let admission = UUID(), regimen = UUID(), assignment = UUID()
        for _ in 0..<2 { _ = try await client.assignChallenge(admissionID: admission, regimenID: regimen, practice: false, assignmentID: assignment, token: "test") }
        let requests = await transport.captured()
        let bodies = try requests.map { try JSONSerialization.jsonObject(with: $0.httpBody!) as! [String: Any] }
        XCTAssertEqual(bodies[0]["assignment_id"] as? String, assignment.uuidString)
        XCTAssertEqual(bodies[0]["assignment_id"] as? String, bodies[1]["assignment_id"] as? String)
        XCTAssertEqual(bodies[0]["wanted_admission"] as? String, admission.uuidString)
        XCTAssertEqual(requests[0].value(forHTTPHeaderField: "Authorization"), "Bearer test")
    }
}
