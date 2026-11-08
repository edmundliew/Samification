import SwiftUI

struct GameView: View {
    @Environment(DemoStore.self) private var store
    let challengeID: UUID
    @State private var activePeriod: DayPeriod = .morning
    @State private var showingFeedback = false
    @State private var showingHint = false
    private var challenge: Challenge? { store.challenges.first { $0.id == challengeID } }
    var body: some View {
        ScrollView {
            if let c = challenge {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Choose a time. Tap or drag a medication image into the tray. Tap a tray tablet to remove it.").font(.subheadline)
                    if c.priorExposure { Label("Earlier regimen exposure recorded", systemImage: "info.circle").font(.caption).foregroundStyle(.orange) }
                    if c.superseded { Notice(text: "This regimen has been replaced. Open the latest challenge.", color: .red) }
                    DisclosureGroup("Your medication reference card") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(c.medications) { m in
                                VStack(alignment: .leading) {
                                    Text("\(m.code) · \(m.name)").font(.headline)
                                    Text("\(m.doseMG.formatted()) mg · \(m.quantity ?? 0) tablet(s) · \(DayPeriod.allCases.filter { m.periods.contains($0) }.map(\.title).joined(separator: ", "))")
                                    if !m.directions.isEmpty { Text(m.directions).foregroundStyle(.secondary) }
                                }
                            }
                        }.padding(.top)
                    }.padding(10).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    MedicationShelf(medications: c.medications, disabled: c.locked) { m in
                        store.update(c.id) { $0.add(m.id, at: activePeriod) }; edited()
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Text("Your daily tray").font(.headline); Spacer(); Text("Taps add to \(activePeriod.title)").font(.caption) }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), alignment: .top), count: 4), alignment: .leading, spacing: 6) {
                            ForEach(DayPeriod.allCases) { period in
                                compartment(c, period)
                            }
                        }
                    }.padding(8).background(Color.brown.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
                    TrayActionRow(clearDisabled: c.locked || c.tray.isEmpty, checkDisabled: c.locked) {
                        store.update(c.id) { $0.clear() }; edited()
                    } check: {
                        store.update(c.id) { $0.submit() }; showingFeedback = true; showingHint = false
                    }
                    if showingFeedback, let attempt = c.attempts.last {
                        Notice(text: attempt.score.correct ? "Correct! Your daily tray matches." : "Let’s review your tray. Check the quantities and day periods below.", color: attempt.score.correct ? .green : .red)
                        if !attempt.score.correct {
                            ForEach(attempt.score.findings) { f in
                                Text("\(name(f.medicationID, in: c)) · \(f.period.title): expected \(f.expected), submitted \(f.actual)").font(.subheadline).foregroundStyle(.red)
                            }
                        }
                    }
                    if let last = c.attempts.last, !last.score.correct, !c.locked {
                        Button("Ask for a hint") { store.update(c.id) { _ = $0.showHint() }; showingHint = true }
                            .foregroundStyle(.red).padding(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(.red, lineWidth: 1))
                    }
                    if showingHint {
                        Notice(text: c.medications.map { m in "\(m.code): \(m.quantity ?? 0) tablet(s) in \(DayPeriod.allCases.filter { m.periods.contains($0) }.map(\.title).joined(separator: ", "))." }.joined(separator: " "))
                    }
                    if !c.attempts.isEmpty, !c.locked {
                        Button(c.attempts.last?.score.correct == true ? "Finish & share results" : "End challenge & share results") {
                            store.update(c.id) { _ = $0.share() }; store.message = "Results are now visible in the clinician preview on this device."
                        }.buttonStyle(.borderedProminent).disabled(!c.canShare)
                        if !c.canShare { Text("Check the updated tray before sharing.").font(.caption).foregroundStyle(.secondary) }
                    }
                    if c.shared { Notice(text: "Results shared in this demo. This challenge is now read-only.") }
                    Text("Submissions: \(c.attempts.count) · Hints: \(c.hintCount)").font(.subheadline).foregroundStyle(.secondary)
                    Text("Package photos are supplied demo references. Pill icons are illustrative. This challenge scores quantities and day periods; food instructions are displayed but not scored.").font(.caption).foregroundStyle(.secondary)
                }.padding().frame(maxWidth: 950).frame(maxWidth: .infinity)
            }
        }.navigationTitle("Plan your medication day").navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .onAppear { store.gamePresented = true; store.start(challengeID) }
            .onDisappear { store.gamePresented = false }
    }
    private func edited() { showingFeedback = false; showingHint = false }
    private func name(_ id: UUID, in c: Challenge) -> String { c.medications.first { $0.id == id }?.code ?? "Unknown medication" }
    private func compartment(_ c: Challenge, _ period: DayPeriod) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { activePeriod = period } label: {
                TrayPeriodLabel(period: period)
            }.buttonStyle(.plain).padding(.vertical, 4).frame(maxWidth: .infinity).background(activePeriod == period ? Color.teal.opacity(0.15) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10)).foregroundStyle(activePeriod == period ? .teal : .secondary).disabled(c.locked)
            FlowPills(challenge: c, period: period, assessed: showingFeedback) { id in
                store.update(c.id) { $0.remove(id, at: period) }; edited()
            }
            Spacer(minLength: 0)
        }.padding(4).frame(maxWidth: .infinity, minHeight: 140).background(.background, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(activePeriod == period ? Color.teal : Color.secondary.opacity(0.3), lineWidth: activePeriod == period ? 3 : 1))
            .dropDestination(for: String.self) { items, _ in
                guard !c.locked, items.count == 1, let id = UUID(uuidString: items[0]), c.medications.contains(where: { $0.id == id }) else { return false }
                activePeriod = period; store.update(c.id) { $0.add(id, at: period) }; edited(); return true
            }
    }
}

struct TrayActionRow: View {
    let clearDisabled: Bool
    let checkDisabled: Bool
    let clear: () -> Void
    let check: () -> Void
    var body: some View {
        HStack(spacing: 6) {
            Button(action: clear) {
                Label("Clear all", systemImage: "arrow.counterclockwise")
                    .font(.caption).fixedSize(horizontal: true, vertical: false).frame(minHeight: 32)
            }.buttonStyle(.bordered).controlSize(.small).disabled(clearDisabled).frame(width: 76)
            Spacer(minLength: 0)
            Button(action: check) {
                Text("Check my daily tray").font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 32)
            }.buttonStyle(.borderedProminent).disabled(checkDisabled)
            Spacer(minLength: 0)
            Color.clear.frame(width: 76, height: 1).accessibilityHidden(true)
        }
    }
}

struct TrayPeriodLabel: View {
    let period: DayPeriod
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: period.symbol).font(.system(size: 18))
            Text(period.title).font(.caption2).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, minHeight: 48)
        .accessibilityElement(children: .ignore).accessibilityLabel(period.title)
    }
}

struct MedicationShelf: View {
    let medications: [Medication]
    let disabled: Bool
    let add: (Medication) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Swipe sideways to see all medicines", systemImage: "arrow.left.arrow.right")
                .font(.caption).foregroundStyle(.secondary)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(medications) { medication in
                        MedicationBag(medication: medication, disabled: disabled) { add(medication) }
                            .frame(width: 148)
                    }
                }.padding(.bottom, 8)
            }
            .scrollIndicators(.visible)
            .scrollIndicatorsFlash(onAppear: true)
        }
    }
}

struct MedicationBag: View {
    let medication: Medication
    let disabled: Bool
    let add: () -> Void
    var body: some View {
        VStack(spacing: 8) {
            VStack(spacing: 4) {
                Capsule().fill(.teal.opacity(0.6)).frame(height: 3)
                Capsule().fill(.teal.opacity(0.3)).frame(height: 2)
            }
            VStack(spacing: 4) {
                Text("MEDICATION \(medication.code)").font(.caption).foregroundStyle(.secondary)
                Text(medication.name).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                Text("\(medication.strengthMG.formatted()) mg / tablet").font(.caption)
            }.frame(maxWidth: .infinity).padding(8).background(.background, in: RoundedRectangle(cornerRadius: 8))
            Button(action: add) {
                VStack(spacing: 4) {
                    if let image = medication.visibleImage {
                        Image(image).resizable().scaledToFit().frame(height: 64)
                    } else {
                        Image(systemName: "pills").font(.system(size: 28)).frame(height: 64)
                    }
                    Text("Tap / drag").font(.caption2).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).contentShape(Rectangle())
            }
            .buttonStyle(.plain).disabled(disabled).draggable(medication.id.uuidString)
            .accessibilityLabel("Add one \(medication.name) tablet to selected compartment")
            .accessibilityHint("Tap to add one tablet, or drag this medication image into a time compartment.")
        }.padding(8).frame(maxWidth: .infinity).background(.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(.teal.opacity(0.4), lineWidth: 1))
    }
}

struct PillIcon: View {
    let code: String
    var error = false
    var compact = false
    var body: some View {
        Text(error && !compact ? "\(code) ×" : code)
            .font(compact ? .caption.weight(.semibold) : .headline)
            .foregroundStyle(error ? Color.red : Color.primary)
            .frame(minWidth: compact ? 18 : 44, minHeight: compact ? 26 : 34)
            .padding(.horizontal, compact ? 3 : 4)
            .background(error ? Color.red.opacity(0.15) : Color.teal.opacity(0.15), in: Capsule())
            .overlay(Capsule().stroke(error ? Color.red : Color.teal.opacity(0.35)))
    }
}

struct TrayTablet: Identifiable {
    let medication: Medication
    let index: Int
    var id: String { "\(medication.id.uuidString)-\(index)" }
    static func items(_ medications: [Medication], tray: Tray, period: DayPeriod) -> [TrayTablet] {
        medications.flatMap { medication in
            (0..<tray.count(medication.id, at: period)).map { TrayTablet(medication: medication, index: $0) }
        }
    }
}

struct FlowPills: View {
    let challenge: Challenge
    let period: DayPeriod
    let assessed: Bool
    let remove: (UUID) -> Void
    var body: some View {
        let total = challenge.medications.reduce(0) { $0 + challenge.tray.count($1.id, at: period) }
        if total == 0 { Text("Drop here").font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 70) }
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0)), count: 2), spacing: 4) {
            ForEach(TrayTablet.items(challenge.medications, tray: challenge.tray, period: period)) { tablet in
                let m = tablet.medication
                let index = tablet.index
                let expected = m.periods.contains(period) ? (m.quantity ?? 0) : 0
                Button { remove(m.id) } label: { PillIcon(code: m.code, error: assessed && index >= expected, compact: true).frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle()) }
                    .buttonStyle(.plain).disabled(challenge.locked)
                    .accessibilityLabel("Remove one \(m.name) tablet from \(period.title)")
            }
        }
    }
}
