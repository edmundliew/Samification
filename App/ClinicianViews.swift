import SwiftUI
import UniformTypeIdentifiers

struct MedicationReviewView: View {
    @Environment(DemoStore.self) private var store
    @State private var importing = false
    var body: some View {
        @Bindable var store = store
        List {
            Section {
                Text("Four demo medicines are preconfirmed on launch. Review any edits before assigning a new regimen version.")
                Button("Import fictional CSV", systemImage: "square.and.arrow.down") { importing = true }
                Button("Reload four demo medicines") { store.medications = DemoData.medications.map { var m = $0; m.confirmed = false; return m } }
            }
            ForEach(store.medications.indices, id: \.self) { index in
                Section {
                    MedicationEditor(medication: $store.medications[index])
                } header: { Text(store.medications[index].code + " · " + store.medications[index].name) }
            }
            Section {
                ForEach(Array(store.validation.enumerated()), id: \.offset) { _, error in Text(error).foregroundStyle(.red) }
                Button("Confirm regimen & continue") { store.confirm() }.disabled(!store.validation.isEmpty)
                Text("Current assignment regimen: v\(store.version). Existing results retain their original regimen.").font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("Medication review")
            .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText], allowsMultipleSelection: false) { result in
                do {
                    guard let url = try result.get().first else { return }
                    let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let values = try url.resourceValues(forKeys: [.fileSizeKey])
                    guard (values.fileSize ?? 0) <= 200_000 else { throw CSVError.invalid("Use a CSV smaller than 200 KB.") }
                    let text = try String(contentsOf: url, encoding: .utf8)
                    store.medications = try CSVImporter.medications(from: text)
                    store.message = "CSV imported. Review and confirm every included row."
                } catch { store.message = error.localizedDescription }
            }
    }
}

struct MedicationEditor: View {
    @Binding var medication: Medication
    private func edit<T>(_ path: WritableKeyPath<Medication, T>) -> Binding<T> {
        Binding(get: { medication[keyPath: path] }, set: { medication[keyPath: path] = $0; medication.confirmed = false })
    }
    var body: some View {
        DisclosureGroup {
            LabeledContent("Original CSV name", value: medication.originalName)
            Text(medication.sourceDetails).font(.caption).foregroundStyle(.secondary)
            if let reason = medication.exclusionReason { Text(reason).foregroundStyle(.orange) }
            else {
                Toggle("Include in challenge", isOn: edit(\.included))
                TextField("Name shown to patient", text: edit(\.name))
                LabeledContent("Prescribed dose (mg)") { TextField("Dose", value: edit(\.doseMG), format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                LabeledContent("Product strength (mg/tablet)") { TextField("Strength", value: edit(\.strengthMG), format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                Text("Calculated quantity: \(medication.quantity.map(String.init) ?? "—") tablets per administration")
                ForEach(DayPeriod.allCases) { period in
                    Toggle(isOn: Binding(get: { medication.periods.contains(period) }, set: { included in
                        if included { medication.periods.insert(period) } else { medication.periods.remove(period) }; medication.confirmed = false
                    })) { Label(period.title, systemImage: period.symbol) }
                }
                TextField("Directions", text: edit(\.directions))
                Toggle("I confirm the name, current order, strength, quantity and schedule", isOn: $medication.confirmed).disabled(!medication.included)
                if medication.included { ForEach(medication.issues, id: \.self) { Text($0).font(.caption).foregroundStyle(.red) } }
            }
        } label: { Label(medication.name, systemImage: medication.confirmed ? "checkmark.circle" : "pills") }
    }
}

struct AssignmentView: View {
    @Environment(DemoStore.self) private var store
    @State private var practice = false
    var body: some View {
        List {
            Section("P-001 · Fictional demo admission") {
                Text("Confirmed regimen v\(store.version) · \(store.confirmedMedications.count) medicines")
                Toggle("Practice mode", isOn: $practice)
                Text(practice ? "Practice is labelled separately in results." : "Assessment retains the first answer before feedback, then permits guided retries.").font(.subheadline).foregroundStyle(.secondary)
                Button("Assign to P-001", systemImage: "paperplane.fill") { store.assign(practice: practice) }.buttonStyle(.borderedProminent)
                Button("Open patient preview") { store.patientPreview() }
            }
            Section("Assignments") {
                if store.challenges.isEmpty { Text("No challenges assigned yet").foregroundStyle(.secondary) }
                ForEach(store.challenges.reversed()) { c in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Regimen v\(c.regimenVersion) · \(c.practice ? "Practice" : "Assessment")").font(.headline)
                        Text(c.shared ? "Results received" : c.superseded ? "Superseded" : "Available to patient").foregroundStyle(c.superseded ? .orange : .secondary)
                        Text(c.id.uuidString).font(.caption2).textSelection(.enabled)
                        Button("Open patient view") { store.activeID = c.id; store.patientPreview() }
                    }.padding(.vertical, 4)
                }
            }
            Section { Text("Delivery and notifications are simulated in this release. Sessions stay on this device.").font(.caption) }
        }.navigationTitle("Patient assignment")
    }
}

struct PatientInboxView: View {
    @Environment(DemoStore.self) private var store
    var body: some View {
        List {
            Section { Text("P-001 · Your medication challenges") }
            if store.challenges.isEmpty {
                Text("No challenge assigned yet.")
                Button("Open clinician assignments") { store.role = .clinician; store.selectedTab = "assign" }
            }
            ForEach(store.challenges.reversed()) { challenge in
                NavigationLink { GameView(challengeID: challenge.id) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Plan your medication day").font(.headline)
                        Text("\(challenge.medications.count) medicines · regimen v\(challenge.regimenVersion)")
                        Text(challenge.superseded ? "Superseded — use the latest challenge" : challenge.shared ? "View completed challenge" : challenge.attempts.isEmpty ? "Start challenge" : "Continue challenge").foregroundStyle(.secondary)
                    }
                }.disabled(challenge.superseded)
            }
        }.navigationTitle("My challenges")
    }
}
