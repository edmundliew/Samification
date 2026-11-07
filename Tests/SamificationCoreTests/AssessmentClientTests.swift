import XCTest
@testable import SamificationCore

private actor AssessmentTransport: StaffHTTPTransport {
    var requests: [URLRequest] = []
    let response: String
    init(response: String) { self.response = response }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        return (Data(response.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
    func captured() -> [URLRequest] { requests }
}
final class AssessmentClientTests: XCTestCase {
    func testSubmissionRetriesPreserveRequestAndNeverSendClientScore() async throws {
        let response = """
        {"sequence":2,"kind":"submit","priorExposure":false,"submissions":1,"hints":0,"references":0,"scoringVersion":"TRAY-0.1-PROPOSED","attempt":1}
        """
        let transport = AssessmentTransport(response: response)
        let client = try StaffAccessClient(url: "https://vqexfcvzoryocjnzjozv.supabase.co", publishableKey: "sb_publishable_test_only", transport: transport)
        let meds = DemoData.medications
        var tray = Tray(); tray.add(meds[0].id, at: .morning)
        let pending = PendingAssessmentAction(kind: "submit", tray: tray, medications: meds)
        let assignment = UUID()
        for _ in 0..<2 { _ = try await client.assessmentAction(assignment: assignment, pending: pending, token: "patient-token") }
        let requests = await transport.captured()
        XCTAssertEqual(requests[0].httpBody, requests[1].httpBody)
        let body = try JSONSerialization.jsonObject(with: requests[0].httpBody!) as! [String: Any]
        XCTAssertEqual(Set(body.keys), ["wanted_assignment", "request_id", "action_kind", "action_payload", "expected_previous"])
        XCTAssertEqual(body["request_id"] as? String, pending.id.uuidString)
        XCTAssertEqual(requests[0].value(forHTTPHeaderField: "Authorization"), "Bearer patient-token")
        XCTAssertEqual(try Tray.fromWire(pending.payload).count(meds[0].id, at: .morning), 1)
    }
    func testServerHistoryDecodesWithoutClientOnlyRequestFields() throws {
        let json = """
        [{"id":"00000000-0000-4000-8000-000000000001","recorded_at":"2026-11-07T13:00:00Z","kind":"start","payload":{},"result":{"sequence":1,"kind":"start","priorExposure":false,"submissions":0,"hints":0,"references":0,"scoringVersion":"TRAY-0.1-PROPOSED"}}]
        """
        let history = try JSONDecoder().decode([AssessmentAction].self, from: Data(json.utf8))
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history[0].result.sequence, 1)
        XCTAssertTrue(history[0].payload.isEmpty)
    }
    func testWireTrayRejectsMalformedHistory() throws {
        XCTAssertThrowsError(try Tray.fromWire(["night": [:]]))
        XCTAssertThrowsError(try Tray.fromWire(["morning": [UUID().uuidString: 13]]))
        XCTAssertThrowsError(try Tray.fromWire(["morning": ["unknown": 1]]))
    }
    func testSwiftAndPostgresUseSameIndependentScoringFixtures() throws {
        struct Fixture: Decodable {
            let medications: [FixtureMedication]
            let tray: [String: [String: Int]]
            let expected: [String: Int]
        }
        struct FixtureMedication: Decodable {
            let id: UUID; let code: String; let name: String; let doseMG: Double; let strengthMG: Double; let periods: Set<DayPeriod>
        }
        let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/scoring-parity.json")
        let fixtures = try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: path))
        for f in fixtures {
            let meds = f.medications.map { Medication(id: $0.id, code: $0.code, name: $0.name, doseMG: $0.doseMG, strengthMG: $0.strengthMG, periods: $0.periods, confirmed: true) }
            let score = Score.evaluate(medications: meds, tray: try Tray.fromWire(f.tray))
            let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(score)) as! [String: Any]
            for (key, expected) in f.expected { XCTAssertEqual(json[key] as? Int, expected, key) }
        }
    }
}
