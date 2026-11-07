import SwiftUI

struct ConnectedResultsView: View {
    let admission: ClinicalAdmission
    let account: StaffAccountStore
    @State private var runs: [ClinicalRun] = []
    var body: some View {
        List {
            Section { Text("Medication preparation evidence supports clinical review. The app does not automatically qualify patients for self-administration.") }
            ForEach(runs) { run in
                NavigationLink { ConnectedRunView(run: run, account: account) } label: {
                    VStack(alignment: .leading) {
                        Text(run.finished_at == nil ? "In progress" : "Completed challenge").font(.headline)
                        Text(run.started_at).font(.caption)
                        if run.prior_exposure { Text("Earlier regimen exposure recorded").font(.caption).foregroundStyle(.orange) }
                    }
                }
            }
            if runs.isEmpty { Text("No patient challenges started yet.") }
            Button("Refresh results") { Task { await load() } }
            if let notice = account.notice { Notice(text: notice, color: account.failed ? .red : .teal) }
        }.navigationTitle(admission.patient_alias).task { await load() }.disabled(account.busy)
    }
    private func load() async {
        runs = []
        await account.perform { client in
            guard let token = account.session?.access_token else { throw StaffAPIError.authentication }
            runs = try await client.clinicalRuns(admission: admission.id, token: token)
        }
    }
}

struct ConnectedRunView: View {
    let run: ClinicalRun
    let account: StaffAccountStore
    @State private var actions: [AssessmentAction] = []
    @State private var reviews: [ClinicalReview] = []
    @State private var decision = "education_required"
    @State private var note = ""
    @State private var pendingReview: UUID?
    @State private var medications: [Medication] = []
    @State private var practice = false
    private var submissions: [AssessmentAction] { actions.filter { $0.kind == "submit" } }
    private var firstCorrect: Int? { submissions.firstIndex { $0.result.score?.correct == true }.map { $0 + 1 } }
    var body: some View {
        List {
            Section("Evidence summary") {
                Text(practice ? "Practice challenge" : "Assessment challenge").font(.headline)
                Text("First attempt: \(submissions.first.map { $0.result.score?.correct == true ? "correct" : "incorrect" } ?? "not submitted")")
                Text("Submissions: \(submissions.count) · retries: \(max(0, submissions.count - 1))")
                Text("First correct attempt: \(firstCorrect.map(String.init) ?? "none")")
                Text("Hint requests: \(actions.filter { $0.kind == "hint" }.count) · reference requests: \(actions.filter { $0.kind == "reference" }.count)")
                Text("Earlier challenge for this regimen: \(run.prior_exposure ? "yes" : "no")")
                Text("Counts measure recorded server actions. A response does not prove that feedback was read. The game does not measure actual medication taking.").font(.caption)
            }
            ForEach(submissions) { action in
                Section("Attempt \(action.result.attempt ?? 0)") {
                    if let score = action.result.score {
                        EvidenceScoreView(score: score)
                        Text("Prior submissions: \(action.result.feedbackBefore ?? 0) · prior hint requests: \(action.result.hintsBefore ?? 0) · prior reference requests: \(action.result.referencesBefore ?? 0)").font(.caption)
                        ForEach(score.findings) { f in
                            Text("\(medications.first { $0.id == f.medicationID }?.name ?? f.medicationID.uuidString) · \(f.period.title): expected \(f.expected), submitted \(f.actual)").font(.caption).foregroundStyle(.red)
                        }
                    }
                    Text("Server time: \(action.recorded_at)").font(.caption)
                    Text("Rules: \(action.result.scoringVersion) · request \(action.id.uuidString)").font(.caption2).textSelection(.enabled)
                    DisclosureGroup("Submitted tray") {
                        ForEach(DayPeriod.allCases) { p in
                            Text("\(p.title): \((action.payload[p.rawValue] ?? [:]).sorted { $0.key < $1.key }.map { item in "\(medications.first { $0.id.uuidString.lowercased() == item.key }?.name ?? item.key): \(item.value)" }.joined(separator: ", "))").font(.caption)
                        }
                    }
                }
            }
            Section("Audit timeline") {
                ForEach(actions) { a in Text("\(a.result.sequence) · \(a.kind) · \(a.recorded_at)").font(.caption) }
            }
            if run.finished_at != nil {
                Section("Record clinical review") {
                    Picker("Review outcome", selection: $decision) {
                        Text("Further education required").tag("education_required")
                        Text("Proceed to supervised assessment").tag("supervised_assessment")
                        Text("Evidence reviewed").tag("reviewed")
                    }.disabled(pendingReview != nil)
                    TextField("Clinical review note", text: $note, axis: .vertical).disabled(pendingReview != nil)
                    Text("This records your review; it does not grant self-administration permission.").font(.caption)
                    Button(pendingReview == nil ? "Save review" : "Retry saving review") { Task { await save() } }.disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || note.count > 4000)
                }
            }
            Section("Saved clinical reviews") {
                ForEach(reviews) { r in
                    VStack(alignment: .leading) { Text(r.decision.replacingOccurrences(of: "_", with: " ").capitalized).font(.headline); Text(r.note); Text("\(r.recorded_at) · \(r.clinician_id)").font(.caption) }
                }
            }
            Button("Refresh evidence") { Task { await load() } }
            if let notice = account.notice { Notice(text: notice, color: account.failed ? .red : .teal) }
        }.navigationTitle("Challenge evidence").task { await load() }.disabled(account.busy)
    }
    private func load() async {
        actions = []; reviews = []
        await account.perform { client in
            guard let token = account.session?.access_token else { throw StaffAPIError.authentication }
            let assignments = try await client.assignments(admissionID: run.admission_id, token: token)
            let regimens = try await client.regimens(admissionID: run.admission_id, token: token)
            if let assignment = assignments.first(where: { $0.id == run.id }) {
                practice = assignment.practice
                medications = regimens.first { $0.id == assignment.regimen_id }?.medications ?? []
            }
            actions = try await client.clinicalActions(run: run.id, token: token)
            reviews = try await client.clinicalReviews(run: run.id, token: token)
        }
    }
    private func save() async {
        if pendingReview == nil { pendingReview = UUID() }
        guard let id = pendingReview else { return }
        await account.perform { client in
            guard let token = account.session?.access_token else { throw StaffAPIError.authentication }
            do { try await client.reviewChallenge(run: run.id, requestID: id, decision: decision, note: note, token: token) }
            catch {
                if let api = error as? StaffAPIError {
                    switch api { case .authentication, .forbidden, .rejected, .configuration: pendingReview = nil; case .unavailable: break }
                }
                throw error
            }
            pendingReview = nil; note = ""
            reviews = try await client.clinicalReviews(run: run.id, token: token)
        }
    }
}
struct EvidenceScoreView: View {
    let score: Score
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dose accuracy: \(score.exactQuantities)/\(score.expectedAdministrations) · \(score.dosePercent.formatted(.number.precision(.fractionLength(1))))%")
            ProgressView(value: score.dosePercent, total: 100).tint(.teal)
            Text("Schedule accuracy: \(score.presentAdministrations)/\(score.expectedAdministrations) · \(score.schedulePercent.formatted(.number.precision(.fractionLength(1))))%")
            ProgressView(value: score.schedulePercent, total: 100).tint(.blue)
            Text("\(score.correct ? "Exact tray match" : "Tray contains errors") · unexpected placements: \(score.unexpectedPlacements) · omissions: \(score.omissions)").foregroundStyle(score.correct ? .green : .red)
            Text("Extra tablets: \(score.extraTablets) · missing tablets: \(score.missingTablets)")
        }
    }
}
