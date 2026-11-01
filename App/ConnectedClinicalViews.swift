import SwiftUI
import Observation
import UniformTypeIdentifiers

@MainActor @Observable final class ConnectedClinicalStore {
    var admissions: [ClinicalAdmission] = []
    var regimens: [ClinicalRegimen] = []
    var assignments: [ClinicalAssignment] = []
    var pendingAdmission: PendingAdmissionSave?
    var pendingConfirmation: PendingRegimenSave?
    var alias = ""
    var selectedScope: UUID?
    var draft: [Medication] = []
    var sourceCSV: String?
    var pendingAssignmentID = UUID()
    var pendingRegimenID: UUID?
    var practice = false
    var loadedAdmissionID: UUID?
    var draftIssues: [String] { RegimenValidation.issues(for: draft) }
    private func definiteRejection(_ error: Error) -> Bool {
        guard let api = error as? StaffAPIError else { return false }
        switch api { case .configuration, .authentication, .forbidden, .rejected: return true; case .unavailable: return false }
    }
    func refresh(_ account: StaffAccountStore) async {
        admissions = []
        await account.perform { client in
            guard let token = account.session?.access_token else { throw StaffAPIError.authentication }
            self.admissions = try await client.admissions(token: token)
        }
    }
    func create(_ account: StaffAccountStore) async {
        guard let scope = selectedScope else { return }
        if pendingAdmission == nil { pendingAdmission = PendingAdmissionSave(scope: scope, alias: alias) }
        guard let pending = pendingAdmission else { return }
        await account.perform { client in
            guard let token = account.session?.access_token else { throw StaffAPIError.authentication }
            do {
                _ = try await client.createAdmission(scope: pending.scope, alias: pending.alias, requestID: pending.id, token: token)
                self.admissions = try await client.admissions(token: token)
                self.pendingAdmission = nil; self.alias = ""
            } catch {
                if self.definiteRejection(error) { self.pendingAdmission = nil }
                throw error
            }
        }
    }
    func load(_ admissionID: UUID, account: StaffAccountStore) async {
        regimens = []; assignments = []
        if loadedAdmissionID != admissionID { draft = []; sourceCSV = nil; pendingRegimenID = nil; loadedAdmissionID = admissionID }
        await account.perform { client in
            guard let token = account.session?.access_token else { throw StaffAPIError.authentication }
            let versions = try await client.regimens(admissionID: admissionID, token: token)
            let assigned = try await client.assignments(admissionID: admissionID, token: token)
            self.regimens = versions; self.assignments = assigned
        }
    }
    func confirm(_ admissionID: UUID, account: StaffAccountStore) async {
        guard draftIssues.isEmpty else { return }
        if pendingConfirmation == nil {
            pendingConfirmation = PendingRegimenSave(admissionID: admissionID, medications: draft.filter(\.included), sourceCSV: sourceCSV)
        }
        guard let pending = pendingConfirmation, pending.admissionID == admissionID else { return }
        await account.perform { client in
            guard let token = account.session?.access_token else { throw StaffAPIError.authentication }
            do {
                _ = try await client.confirmRegimen(admissionID: pending.admissionID, medications: pending.medications, sourceCSV: pending.sourceCSV, requestID: pending.id, token: token)
                self.regimens = try await client.regimens(admissionID: admissionID, token: token)
                self.assignments = try await client.assignments(admissionID: admissionID, token: token)
                self.draft = []; self.sourceCSV = nil; self.pendingRegimenID = nil; self.pendingConfirmation = nil
                account.notice = "Regimen confirmed. Previous pending assignments were superseded."
            } catch {
                if self.definiteRejection(error) { self.pendingConfirmation = nil }
                throw error
            }
        }
    }
    func assign(_ admissionID: UUID, account: StaffAccountStore) async {
        guard let regimen = regimens.first else { return }
        if pendingRegimenID != regimen.id { pendingRegimenID = regimen.id; pendingAssignmentID = UUID() }
        await account.perform { client in
            guard let token = account.session?.access_token else { throw StaffAPIError.authentication }
            _ = try await client.assignChallenge(admissionID: admissionID, regimenID: regimen.id, practice: self.practice, assignmentID: self.pendingAssignmentID, token: token)
            self.assignments = try await client.assignments(admissionID: admissionID, token: token)
            self.pendingRegimenID = nil
            account.notice = "Challenge assignment saved. Patient pairing is the next connection step."
        }
    }
}

struct ConnectedClinicalView: View {
    let account: StaffAccountStore
    @State private var records = ConnectedClinicalStore()
    private var scopes: [CareScope] {
        account.scopes.filter { scope in scope.active && account.memberships.contains { $0.user_id == account.session?.user.id && $0.role == "clinician" && $0.active && $0.scope_id == scope.id } }
    }
    var body: some View {
        @Bindable var records = records
        List {
            Section { Notice(text: "Connected development workflow. Use fictional admission aliases and medication data only. Patient pairing and centrally scored results are still being built.", color: .orange) }
            Section("Create admission") {
                Picker("Ward", selection: $records.selectedScope) {
                    Text("Select a ward").tag(Optional<UUID>.none)
                    ForEach(scopes) { Text($0.name).tag(Optional($0.id)) }
                }
                .disabled(records.pendingAdmission != nil)
                TextField("Fictional patient alias", text: $records.alias).disabled(records.pendingAdmission != nil)
                Button(records.pendingAdmission == nil ? "Create admission" : "Retry saving admission") { Task { await records.create(account) } }
                    .disabled(records.selectedScope == nil || records.alias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || records.alias.count > 100)
            }
            Section("Admissions in your approved wards") {
                if records.admissions.isEmpty { Text("No admissions loaded. Refresh to check your access.").foregroundStyle(.secondary) }
                ForEach(records.admissions) { admission in
                    NavigationLink {
                        ConnectedAdmissionView(admission: admission, account: account)
                    } label: {
                        VStack(alignment: .leading) { Text(admission.patient_alias).font(.headline); Text(admission.status.capitalized).font(.caption) }
                    }
                }
                Button("Refresh admissions") { Task { await records.refresh(account) } }
            }
            if let notice = account.notice { Section { Notice(text: notice, color: account.failed ? .red : .teal) } }
        }.navigationTitle("Connected admissions").disabled(account.busy)
            .task { if records.selectedScope == nil { records.selectedScope = scopes.first?.id }; await records.refresh(account) }
    }
}

struct ConnectedAdmissionView: View {
    let admission: ClinicalAdmission
    let account: StaffAccountStore
    @State private var records = ConnectedClinicalStore()
    @State private var importing = false
    @State private var importError: String?
    var body: some View {
        @Bindable var records = records
        List {
            Section { Text(admission.patient_alias).font(.headline); Text(admission.status.capitalized); Button("Refresh admission") { Task { await records.load(admission.id, account: account) } } }
            if admission.status == "active" {
                Section("Prepare next regimen") {
                    Button("Import fictional medication CSV") { importing = true }.disabled(records.pendingConfirmation != nil)
                    Text("Review every included medicine. Confirming saves an immutable version and supersedes this admission’s pending older assignments.").font(.caption)
                }
                ForEach(records.draft.indices, id: \.self) { index in
                    Section(records.draft[index].code) { MedicationEditor(medication: $records.draft[index]).disabled(records.pendingConfirmation != nil) }
                }
                if !records.draft.isEmpty {
                    Section {
                        ForEach(Array(records.draftIssues.enumerated()), id: \.offset) { _, issue in Text(issue).foregroundStyle(.red) }
                        Button(records.pendingConfirmation == nil ? "Confirm regimen" : "Retry saving this regimen") { Task { await records.confirm(admission.id, account: account) } }.disabled(!records.draftIssues.isEmpty)
                    }
                }
                if let regimen = records.regimens.first {
                    Section("Assign current regimen v\(regimen.version)") {
                        Toggle("Practice mode", isOn: $records.practice).disabled(records.pendingRegimenID != nil)
                        Button("Save challenge assignment") { Task { await records.assign(admission.id, account: account) } }
                    }
                }
            }
            if admission.status == "active" {
                Section("Patient access") {
                    NavigationLink("Pair a patient device") { ClinicianPairingView(admission: admission, account: account) }
                }
            }
            Section("Confirmed regimen history") {
                ForEach(records.regimens) { regimen in
                    DisclosureGroup("Version \(regimen.version) · \(regimen.medications.count) medicines") {
                        ForEach(regimen.medications) { m in
                            VStack(alignment: .leading) { Text(m.name).font(.headline); Text("\(m.doseMG.formatted()) mg · \(m.quantity ?? 0) tablet(s)"); Text(DayPeriod.allCases.filter { m.periods.contains($0) }.map(\.title).joined(separator: ", ")); Text("Original: \(m.originalName)").font(.caption) }
                        }
                    }
                }
            }
            Section("Assignments") {
                ForEach(records.assignments) { assignment in
                    VStack(alignment: .leading) { Text(assignment.practice ? "Practice" : "Assessment").font(.headline); Text(assignment.status.capitalized); Text(assignment.id.uuidString).font(.caption2).textSelection(.enabled) }
                }
            }
            if let error = importError { Section { Notice(text: error, color: .red) } }
            if let notice = account.notice { Section { Notice(text: notice, color: account.failed ? .red : .teal) } }
        }.navigationTitle("Admission regimen").disabled(account.busy)
            .task(id: admission.id) { await records.load(admission.id, account: account) }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText], allowsMultipleSelection: false) { result in
                do {
                    guard let url = try result.get().first else { return }
                    let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                    guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 200_000 else { throw CSVError.invalid("Use a CSV smaller than 200 KB.") }
                    let text = try String(contentsOf: url, encoding: .utf8)
                    records.draft = try CSVImporter.medications(from: text); records.sourceCSV = text; importError = nil
                } catch { importError = error.localizedDescription }
            }
    }
}
