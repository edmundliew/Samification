import Foundation

@main struct VerifyCore {
    static func main() throws {
        let meds = DemoData.medications
        var challenge = Challenge(medications: meds, regimenVersion: 1)
        precondition(!challenge.showHint() && !challenge.canShare)
        challenge.submit(); let first = challenge.attempts[0]
        precondition(!first.score.correct && first.score.omissions == 4)
        precondition(challenge.showHint())
        for m in meds { for period in m.periods { challenge.add(m.id, at: period) } }
        challenge.add(meds[0].id, at: .morning); challenge.submit()
        precondition(challenge.attempts[1].score.dosePercent == 100)
        precondition(challenge.attempts[1].score.schedulePercent == 100)
        precondition(!challenge.attempts[1].score.correct)
        precondition(challenge.attempts[1].score.unexpectedPlacements == 1)
        challenge.remove(meds[0].id, at: .morning)
        precondition(!challenge.canShare)
        challenge.submit(); precondition(challenge.firstCorrectAttempt == 3)
        precondition(challenge.attempts[2].hintsBefore == 1 && challenge.attempts[2].feedbackBefore == 2)
        challenge.clear(); precondition(challenge.attempts[0].tray == first.tray && challenge.attempts.count == 3)
        challenge.submit(); precondition(challenge.share()); let events = challenge.events.count
        challenge.clear(); challenge.submit(); precondition(challenge.events.count == events)
        var many = Challenge(medications: meds, regimenVersion: 1)
        for _ in 0..<40 { many.submit() }; precondition(many.attempts.count == 40)
        many.supersede(); many.submit(); precondition(many.attempts.count == 40)
        var unknown = Tray(); unknown.add(UUID(), at: .morning)
        precondition(!Score.evaluate(medications: meds, tray: unknown).correct)
        precondition(!Score.evaluate(medications: [], tray: Tray()).correct)
        var invalid = meds; invalid[0].strengthMG = 0
        precondition(!Score.evaluate(medications: invalid, tray: Tray()).correct)
        var delayed = Challenge(medications: meds, regimenVersion: 1)
        delayed.start(priorExposure: true); delayed.start(priorExposure: false)
        precondition(delayed.priorExposure && delayed.events.count == 1)
        var under = DemoData.medications; under[0].doseMG = 20
        var tray = Tray()
        for m in under { for period in m.periods { tray.add(m.id, at: period) } }
        let score = Score.evaluate(medications: under, tray: tray)
        precondition(score.exactQuantities == 3 && score.presentAdministrations == 4 && score.missingTablets == 1)
        let csv = "\u{FEFF}Medication Name,Details,Task Status,Strength\r\n\"Example, Tablet\",\"PO, 1 MG Every morning\",Pending,500 mcg\r\nOther Tablet,\"PO, 10 MG Every night\",Pending,10 mg\r\nCancelled Tablet,\"PO, 10 MG Every morning\",Cancelled,10 mg\r\nInjection,\"IV, 10 MG Every 8 hours\",Pending,10 mg"
        let imported = try CSVImporter.medications(from: csv)
        precondition(imported.count == 4 && imported[0].name == "Example, Tablet" && imported[0].quantity == 2)
        precondition(!imported[0].confirmed && imported[1].periods.isEmpty && !imported[2].included && !imported[3].included)
        for bad in ["Medication Name,Details\na,b,c", "Medication Name,Medication Name,Details\na,b,c", "Medication Name,Details\n\"unclosed"] {
            do { _ = try CSVImporter.medications(from: bad); fatalError("Malformed CSV accepted") } catch is CSVError { }
        }
        let multiline = try CSVImporter.parse("Name,Details\n\"a\"\"b\",\"line1\nline2\"")
        precondition(multiline[1][0] == "a\"b" && multiline[1][1].contains("\n"))
        var photo = meds[0]; photo.strengthMG = 5; precondition(photo.visibleImage == nil)
        photo.name = "Reviewed name"; precondition(photo.originalName == "Rosuvastatin Tablet")
        let encoded = try JSONEncoder().encode(challenge)
        let decoded = try JSONDecoder().decode(Challenge.self, from: encoded)
        precondition(decoded.attempts.count == challenge.attempts.count && decoded.attempts[0].tray == first.tray)
        print("PASS: quantities, periods, extras, omissions, immutable first attempt, hint exposure, 40 retries, share guards, locks, CSV validation, image strength matching and evidence round-trip.")
    }
}
