import SwiftUI
import Observation

@main
@MainActor
struct SamificationApp: App {
    @State private var store = DemoStore()
    var body: some Scene { WindowGroup { RootView().environment(store).tint(.teal) } }
}

enum DemoRole: String, CaseIterable, Identifiable {
    case administrator = "Administrator", clinician = "Clinician", patient = "Patient"
    var id: String { rawValue }
}

@MainActor @Observable final class DemoStore {
    @ObservationIgnored private let repository: WorkspaceRepository
    @ObservationIgnored private var persistenceEnabled = true
    var workspace: DemoWorkspace { didSet { persist() } }
    var persistenceError: String?
    var role: DemoRole = .clinician
    var activeID: UUID?
    var message: String?
    var accessRequests = ["Demo nurse · Ward A"]
    var approvedStaff: [String] = []
    var selectedTab = "assign"
    var patient: PatientCase { workspace.patients[workspace.selectedIndex] }
    var medications: [Medication] {
        get { patient.draft }
        set { modify { $0.draft = newValue } }
    }
    var confirmedMedications: [Medication] { patient.latestRegimen.medications }
    var version: Int { patient.latestRegimen.number }
    var challenges: [Challenge] { patient.challenges }
    var reviews: [ReviewRecord] { patient.reviews }
    var validation: [String] { patient.validation }
    init(repository: WorkspaceRepository = WorkspaceRepository(url: WorkspaceRepository.defaultURL)) {
        self.repository = repository
        do { workspace = try repository.load() ?? DemoWorkspace() }
        catch {
            workspace = DemoWorkspace(); persistenceEnabled = false
            persistenceError = "Saved demo could not be loaded. Its file is preserved; this temporary workspace will not overwrite it."
        }
    }
    private func modify(_ mutation: (inout PatientCase) throws -> Void) rethrows {
        let index = workspace.selectedIndex
        var value = workspace.patients[index]
        try mutation(&value); workspace.patients[index] = value
    }
    func persist() {
        guard persistenceEnabled else { return }
        do { try repository.save(workspace); persistenceError = nil }
        catch { persistenceError = "Changes could not be saved on this device. Keep the app open and try Save again." }
    }
    func selectPatient(_ id: UUID) {
        guard workspace.patients.contains(where: { $0.id == id }) else { return }
        workspace.selectedPatientID = id; activeID = nil
    }
    func addPatient() { workspace.addPatient(); activeID = nil }
    func importCSV(_ text: String) throws { try modify { try $0.importCSV(text) } }
    func reloadDemoMedicines() {
        modify { $0.draft = DemoData.medications.map { var m = $0; m.confirmed = false; return m }; $0.draftSourceCSV = nil }
    }
    func confirm() {
        do {
            try modify { try $0.confirm() }
            selectedTab = "assign"; message = "\(patient.label) regimen v\(version) confirmed."
        } catch { message = error.localizedDescription }
    }
    func assign(practice: Bool) {
        modify { activeID = $0.assign(practice: practice) }
        message = "Challenge assigned to fictional patient \(patient.label)."
    }
    func update(_ id: UUID, _ mutation: (inout Challenge) -> Void) {
        modify { patient in
            guard let index = patient.challenges.firstIndex(where: { $0.id == id }) else { return }
            mutation(&patient.challenges[index])
        }
    }
    func start(_ id: UUID) { modify { $0.start(id) } }
    func recordReview(_ id: UUID, disposition: String, rationale: String) {
        do {
            try modify { try $0.recordReview(challengeID: id, disposition: disposition, rationale: rationale) }
            message = "Demo review saved separately from assessment evidence."
        } catch { message = error.localizedDescription }
    }
    func archiveAndRestart() {
        do {
            try repository.archive()
            let fresh = DemoWorkspace(); try repository.save(fresh)
            persistenceEnabled = true; workspace = fresh; activeID = nil
            message = "Previous demo archived on this device. A fresh fictional workspace is ready."
        } catch { message = "Could not archive the old workspace. Existing records have been preserved." }
    }
    func patientPreview() { role = .patient; selectedTab = "patient" }
}

struct RootView: View {
    @Environment(DemoStore.self) private var store
    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack { Label("Samification", systemImage: "pills.fill").font(.headline); Spacer(); Text("v0.2 · Development").font(.caption).foregroundStyle(.secondary) }
                Picker("Demo role preview", selection: $store.role) { ForEach(DemoRole.allCases) { Text($0.rawValue).tag($0) } }
                    .pickerStyle(.segmented).onChange(of: store.role) { _, role in store.selectedTab = role == .clinician ? "assign" : role == .patient ? "patient" : "admin" }
                Text("LOCAL DEMO · Fictional records · Role previews are simulated · Work is saved on this device")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding().background(.bar)
            if let error = store.persistenceError {
                VStack { Notice(text: error, color: .red); Button("Save again") { store.persist() } }.padding(.horizontal)
            }
            TabView(selection: $store.selectedTab) {
                if store.role == .clinician {
                    NavigationStack { MedicationReviewView() }.tabItem { Label("Medications", systemImage: "list.clipboard") }.tag("meds")
                    NavigationStack { AssignmentView() }.tabItem { Label("Assign", systemImage: "paperplane") }.tag("assign")
                    NavigationStack { ResultsView() }.tabItem { Label("Results", systemImage: "chart.bar") }.tag("results")
                } else if store.role == .patient {
                    NavigationStack { PatientInboxView() }.tabItem { Label("Demo", systemImage: "tray") }.tag("patient")
                    NavigationStack { PatientConnectionView() }.tabItem { Label("Join", systemImage: "qrcode") }.tag("join")
                } else {
                    NavigationStack { AdministratorView() }.tabItem { Label("Users", systemImage: "person.badge.key") }.tag("admin")
                }
                NavigationStack { StaffAccountView() }.tabItem { Label("Account", systemImage: "person.crop.circle") }.tag("account")
                NavigationStack { HelpView() }.tabItem { Label("Help", systemImage: "questionmark.circle") }.tag("help")
            }
        }.alert("Samification", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) { Button("OK") { store.message = nil } } message: { Text(store.message ?? "") }
    }
}

struct Notice: View {
    let text: String
    var color: Color = .teal
    var body: some View {
        Label(text, systemImage: color == .red ? "exclamationmark.circle.fill" : "info.circle.fill")
            .font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).padding()
            .foregroundStyle(color).background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct AdministratorView: View {
    @Environment(DemoStore.self) private var store
    var body: some View {
        List {
            Section { Text("Administrator preview only. These controls change fictional local records; Supabase approval and access enforcement arrive in v0.2.") }
            Section("Access requests") {
                if store.accessRequests.isEmpty { Text("No pending demo requests").foregroundStyle(.secondary) }
                ForEach(store.accessRequests, id: \.self) { name in
                    VStack(alignment: .leading) { Text(name); Button("Approve demo clinician") { store.approvedStaff.append(name); store.accessRequests.removeAll { $0 == name } } }
                }
            }
            Section("Approved demo staff") {
                ForEach(store.approvedStaff, id: \.self) { name in
                    VStack(alignment: .leading) { Text(name); Button("Suspend demo access", role: .destructive) { store.approvedStaff.removeAll { $0 == name }; store.accessRequests.append(name) } }
                }
            }
            Section("Medication catalogue") {
                NavigationLink("Browse demo products & package photos") { CatalogueView() }
                Text("Product strengths and photos are separate from each patient’s prescribed dose and schedule.")
            }
        }.navigationTitle("Administration")
    }
}
