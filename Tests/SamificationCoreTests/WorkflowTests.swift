import XCTest
@testable import SamificationCore

final class WorkflowTests: XCTestCase {
    func correct(_ challenge: inout Challenge) {
        for m in challenge.medications { for period in m.periods { for _ in 0..<(m.quantity ?? 0) { challenge.add(m.id, at: period) } } }
        challenge.submit()
    }
    func testPatientRegimensAndResultsStayIsolated() throws {
        var workspace = DemoWorkspace()
        let second = workspace.patients[1]
        workspace.patients[0].draft[0].name = "Reviewed name for patient one"
        try workspace.patients[0].confirm()
        workspace.patients[0].assign(practice: false)
        XCTAssertEqual(workspace.patients[1].latestRegimen.number, 1)
        XCTAssertEqual(workspace.patients[1].draft, second.draft)
        XCTAssertTrue(workspace.patients[1].challenges.isEmpty)
        XCTAssertEqual(workspace.patients[0].latestRegimen.medications[0].originalName, "Rosuvastatin Tablet")
        try workspace.validate()
    }
    func testNewVersionPreservesSharedHistoryAndSupersedesOnlyPending() throws {
        var patient = PatientCase(label: "Test", ward: "Fictional")
        patient.assign(practice: false)
        correct(&patient.challenges[0]); XCTAssertTrue(patient.challenges[0].share())
        patient.assign(practice: false)
        let original = patient.regimens[0].medications
        patient.draft[0].doseMG = 20; try patient.confirm()
        XCTAssertEqual(patient.regimens.count, 2)
        XCTAssertEqual(patient.regimens[0].medications, original)
        XCTAssertEqual(patient.challenges[0].medications, original)
        XCTAssertFalse(patient.challenges[0].superseded)
        XCTAssertTrue(patient.challenges[1].superseded)
        XCTAssertEqual(patient.latestRegimen.medications[0].doseMG, 20)
    }
    func testCSVSourceAndEditedNameAreRetainedInVersion() throws {
        let source = "Medication Name,Details,Strength\nExample Tablet,\"PO, 10 MG Every morning\",10 MG\n"
        var patient = PatientCase(label: "Test", ward: "Fictional")
        try patient.importCSV(source)
        XCTAssertThrowsError(try patient.confirm())
        patient.draft[0].name = "Reviewed example"; patient.draft[0].confirmed = true
        try patient.confirm()
        XCTAssertEqual(patient.latestRegimen.sourceCSV, source)
        XCTAssertEqual(patient.latestRegimen.medications[0].originalName, "Example Tablet")
        XCTAssertEqual(patient.latestRegimen.medications[0].name, "Reviewed example")
        XCTAssertEqual(patient.regimens[0].medications.count, 4)
    }
    func testPriorExposureIsPatientAndRegimenSpecificAtStart() throws {
        var patient = PatientCase(label: "Test", ward: "Fictional")
        let first = patient.assign(practice: false)
        let second = patient.assign(practice: false)
        patient.start(first); patient.challenges[0].submit(); patient.start(second)
        XCTAssertFalse(patient.challenges[0].priorExposure)
        XCTAssertTrue(patient.challenges[1].priorExposure)
        try patient.confirm(); let next = patient.assign(practice: false); patient.start(next)
        XCTAssertFalse(patient.challenges.last!.priorExposure)
    }
    func testSaveRestorePreservesAttemptsHintsWorkingTrayAndReviews() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = WorkspaceRepository(url: directory.appendingPathComponent("workspace.json"))
        XCTAssertNil(try repository.load())
        var workspace = DemoWorkspace()
        let id = workspace.patients[0].assign(practice: false)
        workspace.patients[0].start(id)
        workspace.patients[0].challenges[0].submit()
        XCTAssertTrue(workspace.patients[0].challenges[0].showHint())
        correct(&workspace.patients[0].challenges[0]); XCTAssertTrue(workspace.patients[0].challenges[0].share())
        try workspace.patients[0].recordReview(challengeID: id, disposition: "Teaching and reassessment", rationale: "Fictional test review")
        let secondID = workspace.patients[1].assign(practice: true)
        workspace.patients[1].start(secondID)
        let medicationID = workspace.patients[1].challenges[0].medications[0].id
        workspace.patients[1].challenges[0].add(medicationID, at: .evening)
        workspace.selectedPatientID = workspace.patients[1].id
        try repository.save(workspace)
        let restored = try XCTUnwrap(repository.load())
        XCTAssertEqual(restored.selectedPatientID, workspace.selectedPatientID)
        let challenge = restored.patients[0].challenges[0]
        XCTAssertEqual(challenge.id, id); XCTAssertEqual(challenge.attempts.count, 2)
        XCTAssertFalse(challenge.attempts[0].score.correct); XCTAssertTrue(challenge.attempts[1].score.correct)
        XCTAssertEqual(challenge.hintCount, 1); XCTAssertEqual(challenge.firstCorrectAttempt, 2)
        XCTAssertTrue(challenge.shared); XCTAssertEqual(restored.patients[0].reviews.count, 1)
        XCTAssertEqual(restored.patients[1].challenges[0].tray.count(medicationID, at: .evening), 1)
    }
    func testReviewsRequireSharedPatientChallengeAndRationale() throws {
        var patient = PatientCase(label: "Test", ward: "Fictional")
        let id = patient.assign(practice: false)
        XCTAssertThrowsError(try patient.recordReview(challengeID: id, disposition: "Review", rationale: "Draft"))
        patient.challenges[0].submit(); patient.challenges[0].share()
        XCTAssertThrowsError(try patient.recordReview(challengeID: UUID(), disposition: "Review", rationale: "Other patient"))
        XCTAssertThrowsError(try patient.recordReview(challengeID: id, disposition: "Review", rationale: "  "))
        try patient.recordReview(challengeID: id, disposition: "Review", rationale: " Reason ")
        XCTAssertEqual(patient.reviews[0].rationale, "Reason")
    }
    func testCorruptOrNewerFileIsNotOverwrittenAndArchivePreservesOldData() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let repository = WorkspaceRepository(url: directory.appendingPathComponent("workspace.json"))
        let corrupt = Data("broken".utf8); try corrupt.write(to: repository.url)
        XCTAssertThrowsError(try repository.load()); XCTAssertEqual(try Data(contentsOf: repository.url), corrupt)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(DemoWorkspace())) as! [String: Any]
        json["schemaVersion"] = 99
        let newer = try JSONSerialization.data(withJSONObject: json); try newer.write(to: repository.url)
        XCTAssertThrowsError(try repository.load()); XCTAssertEqual(try Data(contentsOf: repository.url), newer)
        try repository.archive(); try repository.save(DemoWorkspace())
        let backups = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.contains("backup") }
        XCTAssertEqual(backups.count, 1); XCTAssertEqual(try Data(contentsOf: backups[0]), newer)
        XCTAssertNotNil(try repository.load())
    }
    func testTamperedScoresAndCrossPatientSessionsFailRestoreValidation() throws {
        var workspace = DemoWorkspace(); workspace.patients[0].assign(practice: false); workspace.patients[0].challenges[0].submit()
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(workspace)) as! [String: Any]
        var patients = json["patients"] as! [[String: Any]]
        var challenges = patients[0]["challenges"] as! [[String: Any]]
        var attempts = challenges[0]["attempts"] as! [[String: Any]]
        var score = attempts[0]["score"] as! [String: Any]; score["exactQuantities"] = 4
        attempts[0]["score"] = score; challenges[0]["attempts"] = attempts
        patients[0]["challenges"] = challenges; json["patients"] = patients
        let tampered = try JSONDecoder().decode(DemoWorkspace.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertThrowsError(try tampered.validate())
        workspace.patients[1].challenges = workspace.patients[0].challenges
        XCTAssertThrowsError(try workspace.validate())
    }
}
