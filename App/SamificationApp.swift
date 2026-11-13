import SwiftUI
import Observation

@main
@MainActor
struct SamificationApp: App {
    @State private var store = DemoStore()
    var body: some Scene { WindowGroup { RootView().environment(store).tint(.teal) } }
}

enum DemoRole: String, CaseIterable, Identifiable {
    case clinician = "Clinician", patient = "Patient"
    var id: String { rawValue }
}

@MainActor @Observable final class DemoStore {
    @ObservationIgnored private let repository: WorkspaceRepository
    @ObservationIgnored private var persistenceEnabled = true
    var workspace: DemoWorkspace { didSet { persist() } }
    var persistenceError: String?
    var role: DemoRole = .clinician
    var activeID: UUID?
    var gamePresented = false
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

// Entry preference selects a workspace; it never grants a server role.
private enum AppEntry: String { case welcome, patient, staff, demo }

struct RootView: View {
    @AppStorage("samification.entry.v1") private var entryValue = AppEntry.welcome.rawValue
    @State private var account = StaffAccountStore()
    @State private var connection = PatientConnectionStore()
    @State private var restoring = true
    @Environment(\.scenePhase) private var scenePhase
    private var entry: AppEntry { AppEntry(rawValue: entryValue) ?? .welcome }
    var body: some View {
        Group {
            if restoring {
                ProgressView("Opening Samification…")
            } else {
                switch entry {
                case .welcome:
                    WelcomeView(onPatient: { entryValue = AppEntry.patient.rawValue },
                                onStaff: { entryValue = AppEntry.staff.rawValue },
                                onDemo: { entryValue = AppEntry.demo.rawValue })
                case .patient:
                    TabView {
                        NavigationStack {
                            PatientConnectionView(connection: connection)
                                .toolbar { if !connection.paired { ToolbarItem(placement: .topBarLeading) { Button("Back") { entryValue = AppEntry.welcome.rawValue } } } }
                        }.tabItem { Label("Play", systemImage: "pills") }
                        NavigationStack { TesterHelpView() }
                            .tabItem { Label("Help", systemImage: "questionmark.circle") }
                    }
                case .staff:
                    if account.clinician {
                        ClinicianWorkspaceView(account: account)
                    } else {
                        NavigationStack {
                            StaffAccountView(account: account)
                                .toolbar { if account.session == nil { ToolbarItem(placement: .topBarLeading) { Button("Back") { entryValue = AppEntry.welcome.rawValue } } } }
                        }
                    }
                case .demo:
                    DemoWorkspaceView { entryValue = AppEntry.welcome.rawValue }
                }
            }
        }
        .task {
            if entry == .staff { await account.restore() }
            restoring = false
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(300)) } catch { break }
                if scenePhase == .active && entry == .staff { await account.renew() }
            }
        }
        .onChange(of: entryValue) { _, _ in
            if entry == .staff { Task { await account.restore() } }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && entry == .staff { Task { await account.renew() } }
            else if phase != .active { account.password = ""; account.newPassword = ""; account.confirmPassword = "" }
        }
    }
}

private struct WelcomeView: View {
    let onPatient: () -> Void
    let onStaff: () -> Void
    let onDemo: () -> Void
    @State private var showingHelp = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "pills.fill").font(.system(size: 36)).foregroundStyle(.teal).accessibilityHidden(true)
                    Text("Samification").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                    Text("Build confidence with your medicines.").font(.title3).foregroundStyle(.secondary)
                }
                demoCard
                entryButton("Play Samification", detail: "For patients · Enter the game code from your care team", symbol: "qrcode", action: onPatient)
                entryButton("Staff sign-in", detail: "For clinicians · Access your ward and patients", symbol: "person.crop.rectangle", action: onStaff)
                Button("Help · Start here", systemImage: "questionmark.circle") { showingHelp = true }
                Text("Development build · Use fictional data only").font(.caption).foregroundStyle(.secondary)
            }.padding(28).frame(maxWidth: 540, alignment: .leading).frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showingHelp) {
            NavigationStack {
                TesterHelpView()
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingHelp = false } } }
            }
        }
    }
    private var demoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Build a practice tray")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text("Fictional records. No sign-in or game code needed.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 5) {
                ForEach(DayPeriod.allCases) { period in
                    HStack(spacing: 5) {
                        Image(systemName: period.symbol)
                        switch period {
                        case .morning: Text("A").fontWeight(.semibold)
                        case .bedtime: Text("B").fontWeight(.semibold)
                        default: EmptyView()
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, minHeight: 30)
                    .background(.background, in: RoundedRectangle(cornerRadius: 7))
                }
            }
            .accessibilityHidden(true)
            Button(action: onDemo) {
                HStack(spacing: 10) {
                    Label("Try demo", systemImage: "play.circle.fill")
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.right").accessibilityHidden(true)
                }
                .font(.title3.bold())
                .frame(minHeight: 44)
                .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .tint(Color(red: 0, green: 0.45, blue: 0.49))
            .accessibilityHint("Opens the fictional demo")
        }
        .padding(14)
        .background(.teal.opacity(0.09), in: RoundedRectangle(cornerRadius: 20))
    }

    private func entryButton(_ title: String, detail: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: symbol).font(.title2.bold())
                Text(detail).font(.body)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
        }.buttonStyle(.plain).background(.teal.opacity(0.09), in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct ClinicianWorkspaceView: View {
    let account: StaffAccountStore
    @State private var selectedTab = "patients"
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { ConnectedClinicalView(account: account) }.tabItem { Label("Patients", systemImage: "person.2") }.tag("patients")
            NavigationStack { StaffAccountView(account: account) }.tabItem { Label("Account", systemImage: "person.crop.circle") }.tag("account")
            NavigationStack { TesterHelpView() }.tabItem { Label("Help", systemImage: "questionmark.circle") }.tag("help")
        }
    }
}

private struct DemoWorkspaceView: View {
    @Environment(DemoStore.self) private var store
    let onExit: () -> Void
    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            if !store.gamePresented {
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Label("Fictional demo", systemImage: "play.circle").font(.headline); Spacer(); Button("Exit demo", action: onExit) }
                    Picker("Demo preview", selection: $store.role) { ForEach(DemoRole.allCases) { Text($0.rawValue).tag($0) } }
                        .pickerStyle(.segmented).onChange(of: store.role) { _, role in store.selectedTab = role == .clinician ? "assign" : "patient" }
                    Text("Fictional records · Saved on this device · No connected accounts")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding().background(.bar)
            }
            if let error = store.persistenceError {
                VStack { Notice(text: error, color: .red); Button("Save again") { store.persist() } }.padding(.horizontal)
            }
            TabView(selection: $store.selectedTab) {
                if store.role == .clinician {
                    NavigationStack { MedicationReviewView() }.tabItem { Label("Medications", systemImage: "list.clipboard") }.tag("meds")
                    NavigationStack { AssignmentView() }.tabItem { Label("Assign", systemImage: "paperplane") }.tag("assign")
                    NavigationStack { ResultsView() }.tabItem { Label("Results", systemImage: "chart.bar") }.tag("results")
                } else {
                    NavigationStack { PatientInboxView() }.tabItem { Label("Challenges", systemImage: "tray") }.tag("patient")
                }
                NavigationStack { HelpView() }.tabItem { Label("Help", systemImage: "questionmark.circle") }.tag("help")
            }
        }.onAppear { store.selectedTab = store.role == .clinician ? "assign" : "patient" }
        .alert("Samification", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) { Button("OK") { store.message = nil } } message: { Text(store.message ?? "") }
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
