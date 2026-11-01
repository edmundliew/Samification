import SwiftUI

struct PatientSelector: View {
    @Environment(DemoStore.self) private var store
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Fictional patient", selection: Binding(get: { store.patient.id }, set: { store.selectPatient($0) })) {
                ForEach(store.workspace.patients) { p in Text("\(p.label) · \(p.ward)").tag(p.id) }
            }
            HStack {
                Label("Saved on this device", systemImage: "internaldrive").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Add fictional patient", systemImage: "person.badge.plus") { store.addPatient() }.font(.caption)
            }
        }
    }
}

struct RegimenHistoryView: View {
    @Environment(DemoStore.self) private var store
    var body: some View {
        List {
            Section { Text("\(store.patient.label) · \(store.patient.ward)"); Text("Confirmed versions are retained. Each assignment keeps the exact medication instructions used when it was created.").font(.caption) }
            ForEach(store.patient.regimens.reversed()) { regimen in
                NavigationLink {
                    List {
                        Section {
                            Text("Confirmed \(regimen.confirmedAt.formatted(date: .abbreviated, time: .shortened))")
                            Text("Version \(regimen.number) · \(regimen.medications.count) medicines")
                        }
                        ForEach(regimen.medications) { m in
                            Section("\(m.code) · \(m.name)") {
                                LabeledContent("Original name", value: m.originalName)
                                LabeledContent("Prescribed dose", value: "\(m.doseMG.formatted()) mg")
                                LabeledContent("Product strength", value: "\(m.strengthMG.formatted()) mg/tablet")
                                LabeledContent("Tablets each time", value: String(m.quantity ?? 0))
                                Text(DayPeriod.allCases.filter { m.periods.contains($0) }.map(\.title).joined(separator: ", "))
                                if !m.directions.isEmpty { Text(m.directions) }
                                Text(m.sourceDetails).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        if let source = regimen.sourceCSV {
                            Section("Original imported CSV · fictional") {
                                DisclosureGroup("Show original CSV") { Text(source).font(.caption.monospaced()).textSelection(.enabled) }
                            }
                        }
                    }.navigationTitle("Regimen v\(regimen.number)")
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Version \(regimen.number)\(regimen.number == store.version ? " · current" : "")").font(.headline)
                        Text("\(regimen.medications.count) medicines · \(regimen.confirmedAt.formatted(date: .abbreviated, time: .shortened))")
                        Text(regimen.sourceCSV == nil ? "Bundled fictional medicines" : "Imported CSV retained").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }.navigationTitle("Regimen history")
    }
}

struct CatalogueView: View {
    // Demo product references only. Patient dose/frequency lives in the confirmed regimen.
    private let products = DemoData.medications
    var body: some View {
        List {
            Section {
                Text("Medication product references").font(.headline)
                Text("These four supplied package photos are unverified demo references. Product strength and packaging are separate from the patient’s prescribed dose, frequency and directions. Editing a strength hides a mismatched photo.")
            }
            ForEach(products, id: \.code) { m in
                Section(m.name) {
                    if let image = m.visibleImage {
                        Image(image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 150).accessibilityLabel("Demo package for \(m.name)")
                    }
                    LabeledContent("Form", value: "Tablet")
                    LabeledContent("Product strength", value: "\(m.strengthMG.formatted()) mg/tablet")
                    Label("Photo verification pending", systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.orange)
                }
            }
        }.navigationTitle("Medication catalogue")
    }
}
