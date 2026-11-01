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

struct ReviewRecord: Identifiable {
    let id = UUID()
    let sessionID: UUID
    let disposition: String
    let rationale: String
    let at = Date()
}

@MainActor @Observable final class DemoStore {
    var role: DemoRole = .clinician
    var medications = DemoData.medications
    var confirmedMedications = DemoData.medications
    var version = 1
    var challenges: [Challenge] = []
    var activeID: UUID?
    var reviews: [ReviewRecord] = []
    var message: String?
    var accessRequests = ["Demo nurse · Ward A"]
    var approvedStaff: [String] = []
    var selectedTab = "assign"
    var validation: [String] {
        let included = medications.filter(\.included)
        var errors = medications.flatMap(\.issues)
        if included.isEmpty { errors.append("Include at least one supported medicine.") }
        let names = included.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        if Set(names).count != names.count { errors.append("Resolve duplicate included medication names.") }
        return errors
    }
    func confirm() {
        guard validation.isEmpty else { return }
        version += 1; confirmedMedications = medications.filter(\.included)
        for index in challenges.indices where !challenges[index].shared { challenges[index].supersede() }
        selectedTab = "assign"; message = "Regimen v\(version) confirmed."
    }
    func assign(practice: Bool) {
        let prior = challenges.contains { $0.regimenVersion == version && !$0.attempts.isEmpty }
        let c = Challenge(medications: confirmedMedications, regimenVersion: version, practice: practice, priorExposure: prior)
        challenges.append(c); activeID = c.id; message = "Challenge assigned to demo patient P-001."
    }
    func update(_ id: UUID, _ mutation: (inout Challenge) -> Void) {
        guard let index = challenges.firstIndex(where: { $0.id == id }) else { return }
        mutation(&challenges[index])
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
                Text("OFFLINE DEMO · Fictional patient P-001 · Role previews are simulated · Closing the app clears session data")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding().background(.bar)
            TabView(selection: $store.selectedTab) {
                if store.role == .clinician {
                    NavigationStack { MedicationReviewView() }.tabItem { Label("Medications", systemImage: "list.clipboard") }.tag("meds")
                    NavigationStack { AssignmentView() }.tabItem { Label("Assign", systemImage: "paperplane") }.tag("assign")
                    NavigationStack { ResultsView() }.tabItem { Label("Results", systemImage: "chart.bar") }.tag("results")
                } else if store.role == .patient {
                    NavigationStack { PatientInboxView() }.tabItem { Label("Challenges", systemImage: "tray") }.tag("patient")
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
                Text("Four demo products and their supplied package photos are bundled with this release. Verification and catalogue administration are planned for the connected pilot.")
            }
        }.navigationTitle("Administration")
    }
}
