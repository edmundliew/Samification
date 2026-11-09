import SwiftUI
import Observation

@MainActor @Observable final class ConnectedGameStore {
    let entry: PatientInboxEntry
    var tray = Tray()
    var history: [AssessmentAction] = []
    var result: AssessmentResult?
    var pending: PendingAssessmentAction?
    var busy = false
    var loaded = false
    var notice: String?
    var showingFeedback = false
    var showingHint = false
    var showingReference = false
    var accessValid = false
    var finished: Bool { result?.completed == true }
    var editable: Bool { loaded && accessValid && !busy && pending == nil && !finished }
    init(entry: PatientInboxEntry) { self.entry = entry }
    func invalidate() { accessValid = false; showingHint = false; showingReference = false; showingFeedback = false }
    func load(connection: PatientConnectionStore) async {
        guard !busy else { return }
        busy = true; accessValid = false; notice = nil
        do {
            history = try await connection.withSession { client, token in
                let inbox = try await client.patientInbox(token: token)
                guard inbox.contains(where: { $0.id == self.entry.id }) else { throw WorkflowError.invalid("This challenge is unavailable. Refresh your patient connection.") }
                return try await client.assessmentHistory(assignment: self.entry.id, token: token)
            }
            result = history.last?.result
            if !loaded, let last = history.last(where: { $0.kind == "submit" }) { tray = try Tray.fromWire(last.payload) }
            loaded = true; accessValid = true
        } catch { notice = error.localizedDescription }
        busy = false
        if loaded && accessValid && history.isEmpty && pending == nil { await send("start", connection: connection) }
    }
    func send(_ kind: String, connection: PatientConnectionStore) async {
        guard !busy, accessValid else { return }
        if pending == nil { pending = PendingAssessmentAction(kind: kind, tray: ["submit", "finish"].contains(kind) ? tray : nil, medications: entry.gameMedications, expectedPrevious: result?.sequence ?? 0) }
        guard let action = pending else { return }
        busy = true; notice = nil; defer { busy = false }
        do {
            result = try await connection.withSession { client, token in try await client.assessmentAction(assignment: self.entry.id, pending: action, token: token) }
            pending = nil
            if action.kind == "submit" { showingFeedback = true; showingHint = false }
            if action.kind == "hint" { showingHint = true }
            if action.kind == "reference" { showingReference = true }
            // A successful action is authoritative even if refreshing history fails.
            do { history = try await connection.withSession { client, token in try await client.assessmentHistory(assignment: self.entry.id, token: token) } }
            catch { accessValid = false; notice = "Action saved. Refresh to reload its audit history." }
        } catch {
            notice = "Action not confirmed. Retry this same action before continuing. \(error.localizedDescription)"
            if let api = error as? StaffAPIError {
                switch api {
                case .authentication, .forbidden, .rejected:
                    pending = nil; accessValid = false
                    notice = "The server rejected this action. Refresh to check your access and challenge status."
                case .configuration, .unavailable: break
                }
            }
        }
    }
    func edited() { showingFeedback = false; showingHint = false }
}

struct ConnectedGameView: View {
    let game: ConnectedGameStore
    let connection: PatientConnectionStore
    @Environment(DemoStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var active: DayPeriod = .morning
    private var meds: [Medication] { game.entry.gameMedications }
    var body: some View {
        ScrollView {
            if game.accessValid {
                VStack(alignment: .leading, spacing: 8) {
                    Text(game.entry.practice ? "Practice · regimen v\(game.entry.regimen_version)" : "Assessment · regimen v\(game.entry.regimen_version)").font(.headline)
                    Text("Choose a time. Tap or drag a medication image into the tray. Tap a tray tablet to remove it.").font(.subheadline)
                    if game.result?.priorExposure == true { Notice(text: "A previous challenge for this regimen was started. Earlier exposure is recorded.", color: .orange) }
                    Button("Open medication reference") { Task { await game.send("reference", connection: connection) } }.disabled(!game.editable)
                    if game.showingReference { reference }
                    MedicationShelf(medications: meds, disabled: !game.editable) { m in
                        game.tray.add(m.id, at: active); game.edited()
                    }
                    VStack(alignment: .leading) {
                        Text("Your daily tray · taps add to \(active.title)").font(.headline)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), alignment: .top), count: 4), spacing: 6) {
                            ForEach(DayPeriod.allCases) { period in compartment(period) }
                        }
                    }.padding(8).background(.brown.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
                    TrayActionRow(clearDisabled: !game.editable || game.tray.isEmpty, checkDisabled: !game.editable || game.result == nil) {
                        game.tray = Tray(); game.edited()
                    } check: {
                        Task { await game.send("submit", connection: connection) }
                    }
                    if game.showingFeedback, let score = game.result?.score {
                        Notice(text: score.correct ? "Correct! Your daily tray matches." : "Let’s review your tray.", color: score.correct ? .green : .red)
                        ForEach(score.findings) { f in Text("\(meds.first { $0.id == f.medicationID }?.name ?? "Medication") · \(f.period.title): expected \(f.expected), submitted \(f.actual)").foregroundStyle(.red) }
                    }
                    if let score = game.history.last(where: { $0.kind == "submit" })?.result.score, !score.correct, !game.finished {
                        Button("Ask for a hint") { Task { await game.send("hint", connection: connection) } }.foregroundStyle(.red).padding(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(.red)).disabled(!game.editable)
                    }
                    if game.showingHint { reference }
                    if (game.result?.submissions ?? 0) > 0, !game.finished {
                        Button("Finish & share results") { Task { await game.send("finish", connection: connection) } }.buttonStyle(.borderedProminent).disabled(!game.editable || !matchesLastSubmission)
                        if !matchesLastSubmission { Text("Check the current tray before finishing.").font(.caption) }
                    }
                    if game.finished { Notice(text: "Results saved for clinician review. This challenge is now read-only.") }
                    Text("Submissions: \(game.result?.submissions ?? 0) · Hints requested: \(game.result?.hints ?? 0)")
                    Text("Pill icons are illustrative. Quantities and day periods are scored; food instructions are displayed. These results support clinician review.").font(.caption).foregroundStyle(.secondary)
                }
            }
            if let notice = game.notice { Notice(text: notice, color: .red) }
            if game.pending != nil { Button("Retry pending action") { Task { await game.send("start", connection: connection) } }.disabled(game.busy || !game.accessValid) }
            Button("Refresh challenge") { Task { await game.load(connection: connection) } }.disabled(game.busy)
            if game.busy { ProgressView("Saving securely…") }
        }.padding().navigationTitle("Medication day")
            .toolbar(.hidden, for: .tabBar)
            .onAppear { store.gamePresented = true }
            .onDisappear { store.gamePresented = false }
            .task { await game.load(connection: connection) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await game.load(connection: connection) } } else { game.invalidate() }
            }
    }
    private var matchesLastSubmission: Bool {
        guard let last = game.history.last(where: { $0.kind == "submit" }), let saved = try? Tray.fromWire(last.payload) else { return false }
        // Compare canonical counts, since Tray can retain zero entries after removal.
        return saved.wireCounts(medications: meds) == game.tray.wireCounts(medications: meds)
    }
    private var reference: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(meds) { m in
                Text("\(m.code) · \(m.name): \(m.quantity ?? 0) tablet(s) in \(DayPeriod.allCases.filter { m.periods.contains($0) }.map(\.title).joined(separator: ", ")). \(m.directions)")
            }
        }.padding().background(.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
    private func compartment(_ period: DayPeriod) -> some View {
        VStack {
            Button { active = period } label: { TrayPeriodLabel(period: period) }.buttonStyle(.plain).padding(.vertical, 4).frame(maxWidth: .infinity).background(active == period ? Color.teal.opacity(0.15) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10)).tint(active == period ? .teal : .secondary).disabled(!game.editable)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0)), count: 2), spacing: 4) {
                ForEach(TrayTablet.items(meds, tray: game.tray, period: period)) { tablet in
                    let m = tablet.medication
                    let i = tablet.index
                    let expected = m.periods.contains(period) ? (m.quantity ?? 0) : 0
                    Button { game.tray.remove(m.id, at: period); game.edited() } label: { PillIcon(code: m.code, error: game.showingFeedback && i >= expected, compact: true).frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle()) }.disabled(!game.editable)
                        .accessibilityLabel("Remove one \(m.name) from \(period.title)")
                }
            }
            Spacer(minLength: 40)
        }.padding(4).frame(maxWidth: .infinity, minHeight: 140).background(.background, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(active == period ? Color.teal : Color.gray))
            .dropDestination(for: String.self) { items, _ in
                guard game.editable, items.count == 1, let id = UUID(uuidString: items[0]), meds.contains(where: { $0.id == id }) else { return false }
                game.tray.add(id, at: period); active = period; game.edited(); return true
            }
    }
}
