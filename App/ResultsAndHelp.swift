import SwiftUI

struct ResultsView: View {
    @Environment(DemoStore.self) private var store
    var body: some View {
        List {
            Section { Text("Three directly measurable results. First attempts and guided retries remain separate; no combined qualification score is calculated.") }
            let shared = store.challenges.filter(\.shared)
            if shared.isEmpty { Text("No results shared yet. Assign and complete a challenge in the patient preview.").foregroundStyle(.secondary) }
            ForEach(shared.reversed()) { c in
                NavigationLink { ResultDetailView(challenge: c) } label: {
                    VStack(alignment: .leading) {
                        Text("P-001 · Regimen v\(c.regimenVersion)").font(.headline)
                        Text("\(c.practice ? "Practice" : "Assessment") · \(c.attempts.count) submissions · \(c.hintCount) hints")
                        Text(c.attempts.first?.score.correct == true ? "First attempt correct" : "First attempt had errors").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }.navigationTitle("Clinician results")
    }
}

struct ResultDetailView: View {
    @Environment(DemoStore.self) private var store
    let challenge: Challenge
    @State private var selectedAttempt = 0
    @State private var disposition = "Further review required"
    @State private var rationale = ""
    private let dispositions = ["Further review required", "Teaching and reassessment", "Supervised self-administration", "Approved scope under local policy"]
    var body: some View {
        List {
            if challenge.regimenVersion != store.version { Section { Text("Historical regimen v\(challenge.regimenVersion). Current regimen is v\(store.version).").foregroundStyle(.orange) } }
            Section {
                Text("P-001 · \(challenge.practice ? "Practice" : "Assessment") · \(Score.rulesVersion)")
                Text(challenge.priorExposure ? "Prior exposure to this regimen recorded" : "No earlier exposure recorded in this demo").font(.caption)
                Picker("Submission to inspect", selection: $selectedAttempt) {
                    ForEach(challenge.attempts.indices, id: \.self) { Text("Attempt \($0 + 1)\($0 == 0 ? " · first" : "")").tag($0) }
                }
            }
            if challenge.attempts.indices.contains(selectedAttempt) {
                let attempt = challenge.attempts[selectedAttempt]
                let score = attempt.score
                Section("Dose preparation") {
                    Text("\(score.exactQuantities) / \(score.expectedAdministrations) · \(score.dosePercent.formatted(.number.precision(.fractionLength(1))))%").font(.title2.monospacedDigit())
                    ProgressView(value: score.dosePercent, total: 100).accessibilityLabel("Exact quantities")
                    Text("\(score.extraTablets) extra tablets · \(score.missingTablets) missing tablets")
                }
                Section("Schedule placement") {
                    Text("\(score.presentAdministrations) / \(score.expectedAdministrations) · \(score.schedulePercent.formatted(.number.precision(.fractionLength(1))))%").font(.title2.monospacedDigit())
                    ProgressView(value: score.schedulePercent, total: 100)
                    Text("\(score.unexpectedPlacements) unexpected placements · \(score.omissions) omitted administrations").foregroundStyle(score.unexpectedPlacements > 0 || score.omissions > 0 ? .red : .primary)
                }
                Section("Assistance & retries · session totals") {
                    LabeledContent("First submission", value: challenge.attempts.first?.score.correct == true ? "Correct" : "Incorrect")
                    LabeledContent("Total submissions", value: String(challenge.attempts.count))
                    LabeledContent("Total retries", value: String(max(0, challenge.attempts.count - 1)))
                    LabeledContent("First correct", value: challenge.firstCorrectAttempt.map { "Attempt \($0)" } ?? "Not achieved")
                    LabeledContent("Retries to first correct", value: challenge.firstCorrectAttempt.map { String($0 - 1) } ?? "Not achieved")
                    LabeledContent("Hints viewed", value: String(challenge.hintCount))
                }
                Section("Selected submission evidence") {
                    Label(score.correct ? "Exact tray match" : "Errors present", systemImage: score.correct ? "checkmark.circle.fill" : "xmark.circle.fill").foregroundStyle(score.correct ? .green : .red)
                    Text("Submitted \(attempt.submittedAt.formatted(date: .abbreviated, time: .standard))")
                    Text("Before this submission: \(attempt.hintsBefore) hints · \(attempt.feedbackBefore) automatic feedback displays")
                    ForEach(DayPeriod.allCases) { period in
                        VStack(alignment: .leading) {
                            Label(period.title, systemImage: period.symbol).font(.headline)
                            ForEach(challenge.medications) { m in Text("\(m.code) · \(m.name): \(attempt.tray.count(m.id, at: period))") }
                        }.padding(.vertical, 4)
                    }
                    ForEach(score.findings) { f in
                        Text("\(challenge.medications.first { $0.id == f.medicationID }?.name ?? "Unknown") · \(f.period.title): expected \(f.expected), submitted \(f.actual)").foregroundStyle(.red)
                    }
                }
            }
            Section("Attempt history") {
                ForEach(Array(challenge.attempts.enumerated()), id: \.element.id) { index, a in
                    Button { selectedAttempt = index } label: {
                        VStack(alignment: .leading) {
                            Text("Attempt \(a.number) · \(a.score.correct ? "Correct" : "Errors present")")
                            Text("\(a.hintsBefore) hints and \(a.feedbackBefore) feedback displays before submission").font(.caption)
                        }
                    }
                }
            }
            Section("Scoring definitions · proposed") {
                Text("Dose preparation: expected medicine/time administrations with exactly correct quantity ÷ all expected administrations.")
                Text("Schedule placement: expected medicine/time administrations containing at least one tablet ÷ all expected administrations. Unexpected placements are counted separately.")
                Text("The measures overlap and are never averaged. Exact tray correctness also requires no extras. Food compliance, exact clock times, real adherence and administration technique are outside this challenge.")
            }
            Section("Clinician review · simulated") {
                Text("Game results do not automatically qualify a patient for self-administration. Proposed rules require clinical validation.").font(.caption)
                Picker("Disposition", selection: $disposition) { ForEach(dispositions, id: \.self) { Text($0) } }
                TextField("Rationale, medicines and assistance scope", text: $rationale, axis: .vertical).lineLimit(3...6)
                Button("Record demo review") {
                    store.reviews.append(ReviewRecord(sessionID: challenge.id, disposition: disposition, rationale: rationale.trimmingCharacters(in: .whitespacesAndNewlines)))
                    store.message = "Demo review recorded separately from assessment evidence."
                }.disabled(rationale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                ForEach(store.reviews.filter { $0.sessionID == challenge.id }) { r in
                    VStack(alignment: .leading) { Text(r.disposition).font(.headline); Text(r.rationale); Text(r.at.formatted()).font(.caption) }
                }
            }
            Section { NavigationLink("Inspect audit trail") { AuditView(challenge: challenge) } }
        }.navigationTitle("Competency evidence")
    }
}

struct AuditView: View {
    let challenge: Challenge
    var body: some View {
        List {
            Section { Text("Local demo evidence, not a production audit store. Submissions use immutable value snapshots. The connected backend will independently verify and retain records.") }
            Section("Confirmed answer key · regimen v\(challenge.regimenVersion)") {
                ForEach(challenge.medications) { m in
                    VStack(alignment: .leading) {
                        Text("\(m.code) · \(m.name)").font(.headline)
                        Text("Original: \(m.originalName)").font(.caption)
                        Text("\(m.doseMG.formatted()) mg · \(m.strengthMG.formatted()) mg/tablet · \(m.quantity ?? 0) tablets")
                        Text(DayPeriod.allCases.filter { m.periods.contains($0) }.map(\.title).joined(separator: ", "))
                        Text(m.sourceDetails).font(.caption)
                    }
                }
            }
            Section("Events") {
                ForEach(challenge.events) { e in
                    VStack(alignment: .leading) {
                        Text(e.action.replacingOccurrences(of: "_", with: " ")).font(.headline)
                        Text(e.at.formatted(date: .abbreviated, time: .standard)).font(.caption)
                        if !e.detail.isEmpty { Text(e.detail).font(.caption).textSelection(.enabled) }
                    }
                }
            }
        }.navigationTitle("Audit trail")
    }
}

struct HelpView: View {
    var body: some View {
        List {
            Section("Clinician → Patient → Clinician") {
                HelpStep(number: 1, title: "Prepare", text: "Upload a CSV, review medication names, doses, strengths and day periods, then confirm the regimen. The four fictional demo medicines are preconfirmed on launch.", symbol: "list.clipboard")
                HelpStep(number: 2, title: "Assign", text: "In the clinician preview, open Assign. Choose assessment or practice and press Assign to P-001. Then open the patient preview.", symbol: "paperplane")
                HelpStep(number: 3, title: "Play and share", text: "Open Challenges and start a challenge. Fill the tray, check it, retry as needed and share results.", symbol: "pills")
                HelpStep(number: 4, title: "Review evidence", text: "In the clinician preview, open Results. Inspect the first attempt, later submissions, assistance used and audit trail. Record a separate clinical review.", symbol: "chart.bar")
            }
            Section("Patient controls") {
                Text("Select Morning (sunrise), Afternoon (sun), Evening (sunset), or Bedtime (moon). Tap a pill in its bag to add one tablet to that compartment, or drag it directly into any compartment.")
                Text("Tap a tablet in the tray to remove it. Clear all empties the working tray without deleting previous attempts or hints.")
                Text("Check my daily tray saves a submission. Incorrect answers show red feedback and highlight extra/wrong-time tablets. Missing doses are listed. Correct answers show green feedback.")
                Text("Ask for a hint appears only after an incorrect submission. Every hint display is counted. Use the reference card whenever needed.")
                Text("Check again after changing the tray before sharing. An unsuccessful challenge can also be ended and shared after checking. Sharing locks that challenge.")
            }
            Section("CSV and medication review") {
                Text("Use a UTF-8 CSV with unique Medication Name and Details headers. Optional Strength values can be 10 MG, 500 MCG, or 1 G. Maximum: 20 rows and 200 KB.")
                Text("Oral whole-tablet daily regimens are supported. Cancelled orders, PRN, exact-hour, weekly, injections and other formulations remain excluded.")
                Text("A name edit retains the original CSV name. Editing requires confirmation again. Every night and ambiguous frequencies require explicit clinician selection of day periods.")
                Text("Confirm regimen & continue creates a new version. Pending older challenges are superseded; shared results keep their original instructions.")
            }
            Section("Read the three results") {
                Text("Dose preparation counts exact quantities at expected administrations. Schedule placement counts expected administrations containing tablets. Inspect unexpected placements even when bars reach 100%.")
                Text("Assistance & retries records first-attempt correctness, total submissions, first correct attempt, retries to correct and hint views. Automatic feedback exposure is separately recorded.")
                Text("There is no overall qualification score. These rules need clinical validation, and clinicians make self-administration decisions under local policy.")
            }
            Section("Offline demo v0.1") {
                Text("Role switching, administrator approvals, patient identity and delivery are simulated on one device. No Supabase sign-in, push notifications or cross-device sharing are connected yet. Closing the app clears this session.")
                Text("The supplied package photos are demo references. Tablet icons are illustrative. Food compliance, technique and actual medication adherence are not measured.")
            }
        }.navigationTitle("Help & walkthrough")
    }
}

struct HelpStep: View {
    let number: Int
    let title: String
    let text: String
    let symbol: String
    var body: some View { VStack(alignment: .leading, spacing: 8) { Label("\(number) · \(title)", systemImage: symbol).font(.headline); Text(text) }.padding(.vertical, 6) }
}
