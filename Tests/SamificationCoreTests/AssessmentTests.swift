import XCTest
@testable import SamificationCore

final class AssessmentTests: XCTestCase {
    func correctTray(_ meds: [Medication]) -> Tray {
        var tray = Tray()
        for m in meds { for period in m.periods { for _ in 0..<(m.quantity ?? 0) { tray.add(m.id, at: period) } } }
        return tray
    }
    func testExtraPlacementCannotPassEvenWithFullBars() {
        let meds = DemoData.medications; var tray = correctTray(meds)
        tray.add(meds[0].id, at: .morning)
        let score = Score.evaluate(medications: meds, tray: tray)
        XCTAssertEqual(score.dosePercent, 100); XCTAssertEqual(score.schedulePercent, 100)
        XCTAssertFalse(score.correct); XCTAssertEqual(score.unexpectedPlacements, 1)
    }
    func testUnderdoseAndWrongTimeAreSeparateEvidence() {
        var meds = DemoData.medications; meds[0].doseMG = 20
        var tray = correctTray(meds); tray.remove(meds[0].id, at: .bedtime)
        tray.remove(meds[1].id, at: .morning); tray.add(meds[1].id, at: .evening)
        let score = Score.evaluate(medications: meds, tray: tray)
        XCTAssertEqual(score.exactQuantities, 2); XCTAssertEqual(score.presentAdministrations, 3)
        XCTAssertEqual(score.omissions, 1); XCTAssertEqual(score.unexpectedPlacements, 1)
        XCTAssertEqual(score.missingTablets, 2)
    }
    func testFirstAttemptClearHintsShareAndLock() {
        let meds = DemoData.medications; var c = Challenge(medications: meds, regimenVersion: 1)
        XCTAssertFalse(c.showHint()); XCTAssertFalse(c.share())
        c.submit(); let first = c.attempts[0]; XCTAssertTrue(c.showHint())
        for m in meds { for p in m.periods { c.add(m.id, at: p) } }
        XCTAssertFalse(c.share()); c.submit()
        XCTAssertEqual(c.firstCorrectAttempt, 2); XCTAssertEqual(c.attempts[1].hintsBefore, 1)
        XCTAssertEqual(c.attempts[1].feedbackBefore, 1)
        c.clear(); XCTAssertEqual(c.attempts[0].tray, first.tray); XCTAssertEqual(c.attempts.count, 2)
        XCTAssertEqual(c.hintCount, 1); XCTAssertFalse(c.share())
        c.submit(); XCTAssertTrue(c.share()); let count = c.events.count
        c.clear(); c.submit(); c.add(meds[0].id, at: .bedtime)
        XCTAssertEqual(c.events.count, count)
    }
    func testUnknownMedicationAndEmptyRegimenCannotPass() {
        var tray = correctTray(DemoData.medications); tray.add(UUID(), at: .morning)
        XCTAssertFalse(Score.evaluate(medications: DemoData.medications, tray: tray).correct)
        XCTAssertFalse(Score.evaluate(medications: [], tray: Tray()).correct)
    }
    func testHistoryNotTruncatedAndSupersedingLocks() {
        var c = Challenge(medications: DemoData.medications, regimenVersion: 1)
        for _ in 0..<40 { c.submit() }
        XCTAssertEqual(c.attempts.count, 40); XCTAssertEqual(c.attempts.first?.number, 1)
        c.supersede(); c.submit(); XCTAssertEqual(c.attempts.count, 40)
    }
    func testCSVQuotedFieldsMultilineCRLFAndBOM() throws {
        let rows = try CSVImporter.parse("\u{FEFF}Medication Name,Details\r\n\"Tablet, example\",\"PO, 10 MG\nEvery morning\"\r\n")
        XCTAssertEqual(rows.count, 2); XCTAssertEqual(rows[1][0], "Tablet, example")
        XCTAssertTrue(rows[1][1].contains("\n"))
        XCTAssertThrowsError(try CSVImporter.parse("a,b\n\"unclosed"))
        XCTAssertThrowsError(try CSVImporter.medications(from: "Medication Name,Details\na,b,c"))
        XCTAssertThrowsError(try CSVImporter.medications(from: "Medication Name,Medication Name,Details\na,b,c"))
    }
    func testCSVRequiresReviewAndExcludesUnsupportedAndCancelled() throws {
        let csv = "Medication Name,Details,Task Status,Strength\nExample Tablet,\"PO, 1 MG Every morning\",Pending,500 mcg\nOther Tablet,\"PO, 10 MG Every night\",Pending,10 mg\nCancelled Tablet,\"PO, 10 MG Every morning\",Cancelled,10 mg\nInjection,\"IV, 10 MG Every 8 hours\",Pending,10 mg"
        let meds = try CSVImporter.medications(from: csv)
        XCTAssertEqual(meds[0].quantity, 2); XCTAssertFalse(meds[0].confirmed)
        XCTAssertTrue(meds[1].periods.isEmpty); XCTAssertFalse(meds[2].included); XCTAssertFalse(meds[3].included)
    }
    func testChangedStrengthHidesPhotoAndNameKeepsSource() {
        var m = DemoData.medications[0]; XCTAssertNotNil(m.visibleImage)
        m.strengthMG = 5; XCTAssertNil(m.visibleImage)
        m.name = "Reviewed name"; XCTAssertEqual(m.originalName, "Rosuvastatin Tablet")
    }
}
