import Foundation

public enum DayPeriod: String, CaseIterable, Codable, Identifiable, Sendable {
    case morning, afternoon, evening, bedtime
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var symbol: String { switch self { case .morning: "sunrise"; case .afternoon: "sun.max"; case .evening: "sunset"; case .bedtime: "moon.stars" } }
}

public struct Medication: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var code: String
    public var name: String
    public let originalName: String
    public var doseMG: Double
    public var strengthMG: Double
    public var periods: Set<DayPeriod>
    public var directions: String
    public let sourceDetails: String
    public let sourceRow: Int
    public var imageName: String?
    public let imageStrengthMG: Double?
    public var included: Bool
    public let exclusionReason: String?
    public var confirmed: Bool
    public var quantity: Int? {
        guard doseMG.isFinite, strengthMG.isFinite, doseMG > 0, strengthMG > 0 else { return nil }
        let q = doseMG / strengthMG
        guard q >= 1, q <= 12, abs(q - q.rounded()) < 0.00000001 else { return nil }
        return Int(q.rounded())
    }
    public var visibleImage: String? { strengthMG == imageStrengthMG ? imageName : nil }
    public var issues: [String] {
        guard included else { return [] }
        var errors: [String] = []
        if exclusionReason != nil { errors.append("This order is outside the tray game's scope.") }
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append("Enter a medication name.") }
        if quantity == nil { errors.append("Confirm dose and strength: 1–12 whole tablets per administration are supported.") }
        if periods.isEmpty { errors.append("Select the confirmed day period(s).") }
        if !confirmed { errors.append("Clinician confirmation required.") }
        return errors
    }
    private enum CodingKeys: String, CodingKey {
        case id, code, name, originalName, doseMG, strengthMG, periods, directions
        case sourceDetails, sourceRow, imageName, imageStrengthMG, included, exclusionReason, confirmed
    }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        // The backend requires these fields in every confirmed answer key.
        id = try values.decode(UUID.self, forKey: .id)
        code = try values.decode(String.self, forKey: .code)
        name = try values.decode(String.self, forKey: .name)
        originalName = try values.decode(String.self, forKey: .originalName)
        doseMG = try values.decode(Double.self, forKey: .doseMG)
        strengthMG = try values.decode(Double.self, forKey: .strengthMG)
        periods = try values.decode(Set<DayPeriod>.self, forKey: .periods)
        included = try values.decode(Bool.self, forKey: .included)
        confirmed = try values.decode(Bool.self, forKey: .confirmed)
        // Display/provenance fields are optional in the server snapshot schema.
        directions = try values.decodeIfPresent(String.self, forKey: .directions) ?? ""
        sourceDetails = try values.decodeIfPresent(String.self, forKey: .sourceDetails) ?? ""
        sourceRow = try values.decodeIfPresent(Int.self, forKey: .sourceRow) ?? 0
        imageName = try values.decodeIfPresent(String.self, forKey: .imageName)
        imageStrengthMG = try values.decodeIfPresent(Double.self, forKey: .imageStrengthMG)
        exclusionReason = try values.decodeIfPresent(String.self, forKey: .exclusionReason)
    }
    public init(id: UUID = UUID(), code: String, name: String, doseMG: Double, strengthMG: Double, periods: Set<DayPeriod>, directions: String = "", sourceDetails: String = "", sourceRow: Int = 0, imageName: String? = nil, imageStrengthMG: Double? = nil, included: Bool = true, exclusionReason: String? = nil, confirmed: Bool = false) {
        self.id = id; self.code = code; self.name = name; self.originalName = name; self.doseMG = doseMG; self.strengthMG = strengthMG; self.periods = periods; self.directions = directions; self.sourceDetails = sourceDetails; self.sourceRow = sourceRow; self.imageName = imageName; self.imageStrengthMG = imageStrengthMG; self.included = included; self.exclusionReason = exclusionReason; self.confirmed = confirmed
    }
}

public enum DemoData {
    public static var medications: [Medication] {
        [Medication(code: "A", name: "Rosuvastatin Tablet", doseMG: 10, strengthMG: 10, periods: [.bedtime], sourceDetails: "PO, 10 MG At bedtime x 84 Days", imageName: "rosuvastatin", imageStrengthMG: 10, confirmed: true),
         Medication(code: "B", name: "Empagliflozin Tablet", doseMG: 25, strengthMG: 25, periods: [.morning], sourceDetails: "PO, 25 MG Every morning x 84 Days", imageName: "empagliflozin", imageStrengthMG: 25, confirmed: true),
         Medication(code: "C", name: "Vericiguat Tablet", doseMG: 5, strengthMG: 5, periods: [.morning], directions: "With a meal", sourceDetails: "PO, 5 MG Every morning (with meal) x 28 Days", imageName: "vericiguat", imageStrengthMG: 5, confirmed: true),
         Medication(code: "D", name: "Allopurinol Tablet", doseMG: 100, strengthMG: 100, periods: [.morning], sourceDetails: "PO, 100 MG Every morning x 14 Days", imageName: "allopurinol", imageStrengthMG: 100, confirmed: true)]
    }
}

public struct Tray: Codable, Equatable, Sendable {
    private var counts: [DayPeriod: [UUID: Int]] = [:]
    public init() {}
    public func count(_ medication: UUID, at period: DayPeriod) -> Int { counts[period]?[medication] ?? 0 }
    public mutating func add(_ medication: UUID, at period: DayPeriod) {
        counts[period, default: [:]][medication] = min(12, count(medication, at: period) + 1)
    }
    public mutating func remove(_ medication: UUID, at period: DayPeriod) {
        counts[period, default: [:]][medication] = max(0, count(medication, at: period) - 1)
    }
    public var medicationIDs: Set<UUID> { Set(counts.values.flatMap { $0.filter { $0.value > 0 }.keys }) }
    public var isEmpty: Bool { counts.values.allSatisfy { $0.values.allSatisfy { $0 == 0 } } }
}

public struct Finding: Identifiable, Codable, Equatable, Sendable {
    public var id: String { medicationID.uuidString + period.rawValue }
    public let medicationID: UUID
    public let period: DayPeriod
    public let expected: Int
    public let actual: Int
}

public struct Score: Codable, Equatable, Sendable {
    public static let rulesVersion = "TRAY-0.1-PROPOSED"
    public let validRegimen: Bool
    public let expectedAdministrations: Int
    public let exactQuantities: Int
    public let presentAdministrations: Int
    public let unexpectedPlacements: Int
    public let omissions: Int
    public let extraTablets: Int
    public let missingTablets: Int
    public let findings: [Finding]
    public var correct: Bool { validRegimen && expectedAdministrations > 0 && findings.isEmpty }
    public var dosePercent: Double { expectedAdministrations == 0 ? 0 : Double(exactQuantities) / Double(expectedAdministrations) * 100 }
    public var schedulePercent: Double { expectedAdministrations == 0 ? 0 : Double(presentAdministrations) / Double(expectedAdministrations) * 100 }
    public static func evaluate(medications: [Medication], tray: Tray) -> Score {
        let meds = medications.filter(\.included)
        var total = 0, exact = 0, present = 0, unexpected = 0, omissions = 0, extra = 0, missing = 0
        var findings: [Finding] = []
        for m in meds {
            for period in DayPeriod.allCases {
                let needed = m.periods.contains(period) ? (m.quantity ?? 0) : 0
                let actual = tray.count(m.id, at: period)
                if needed > 0 {
                    total += 1
                    if actual == needed { exact += 1 }
                    if actual > 0 { present += 1 } else { omissions += 1 }
                } else if actual > 0 { unexpected += 1 }
                extra += max(0, actual - needed); missing += max(0, needed - actual)
                if actual != needed { findings.append(Finding(medicationID: m.id, period: period, expected: needed, actual: actual)) }
            }
        }
        // Unknown IDs must never disappear from evidence or yield a correct tray.
        for id in tray.medicationIDs.subtracting(Set(meds.map(\.id))) {
            for period in DayPeriod.allCases where tray.count(id, at: period) > 0 {
                let actual = tray.count(id, at: period); unexpected += 1; extra += actual
                findings.append(Finding(medicationID: id, period: period, expected: 0, actual: actual))
            }
        }
        let valid = !meds.isEmpty && meds.allSatisfy { $0.quantity != nil && !$0.periods.isEmpty && $0.exclusionReason == nil }
        return Score(validRegimen: valid, expectedAdministrations: total, exactQuantities: exact, presentAdministrations: present, unexpectedPlacements: unexpected, omissions: omissions, extraTablets: extra, missingTablets: missing, findings: findings)
    }
}

public struct Attempt: Identifiable, Codable, Sendable {
    public let id: UUID
    public let number: Int
    public let submittedAt: Date
    public let tray: Tray
    public let score: Score
    public let hintsBefore: Int
    public let feedbackBefore: Int
    public let scoringVersion: String
}
public struct EvidenceEvent: Identifiable, Codable, Sendable {
    public let id: UUID
    public let at: Date
    public let action: String
    public let detail: String
}
public struct Challenge: Identifiable, Codable, Sendable {
    public let id: UUID
    public let regimenVersion: Int
    public let medications: [Medication]
    public let practice: Bool
    public private(set) var priorExposure: Bool
    public private(set) var started = false
    public private(set) var tray = Tray()
    public private(set) var attempts: [Attempt] = []
    public private(set) var hintCount = 0
    public private(set) var events: [EvidenceEvent] = []
    public private(set) var shared = false
    public private(set) var superseded = false
    public var locked: Bool { shared || superseded }
    public var canShare: Bool { !locked && attempts.last.map { $0.tray == tray } == true }
    public var firstCorrectAttempt: Int? { attempts.firstIndex { $0.score.correct }.map { $0 + 1 } }
    public init(medications: [Medication], regimenVersion: Int, practice: Bool = false, priorExposure: Bool = false) {
        self.id = UUID(); self.medications = medications; self.regimenVersion = regimenVersion; self.practice = practice; self.priorExposure = priorExposure
    }
    public mutating func record(_ action: String, _ detail: String = "") { events.append(EvidenceEvent(id: UUID(), at: Date(), action: action, detail: detail)) }
    public mutating func start(priorExposure: Bool) {
        guard !started, !locked else { return }
        started = true; self.priorExposure = priorExposure; record("challenge_started", "Prior regimen exposure: \(priorExposure)")
    }
    public mutating func add(_ id: UUID, at period: DayPeriod) {
        guard !locked, medications.contains(where: { $0.id == id }) else { return }
        tray.add(id, at: period); record("tablet_added", "\(id) · \(period.rawValue)")
    }
    public mutating func remove(_ id: UUID, at period: DayPeriod) {
        guard !locked, tray.count(id, at: period) > 0 else { return }
        tray.remove(id, at: period); record("tablet_removed", "\(id) · \(period.rawValue)")
    }
    public mutating func clear() { guard !locked else { return }; tray = Tray(); record("tray_cleared") }
    public mutating func submit() {
        guard !locked else { return }
        let result = Score.evaluate(medications: medications, tray: tray)
        let attempt = Attempt(id: UUID(), number: attempts.count + 1, submittedAt: Date(), tray: tray, score: result, hintsBefore: hintCount, feedbackBefore: attempts.count, scoringVersion: Score.rulesVersion)
        attempts.append(attempt); record("tray_submitted", "Attempt \(attempt.number) · \(attempt.id)")
        record("feedback_displayed", result.correct ? "Exact match" : "Errors present")
    }
    @discardableResult public mutating func showHint() -> Bool {
        guard !locked, let last = attempts.last, !last.score.correct else { return false }
        hintCount += 1; record("hint_displayed", "HINT-0.1 · after attempt \(last.number)"); return true
    }
    @discardableResult public mutating func share() -> Bool {
        guard canShare else { return false }; shared = true; record("results_shared_demo"); return true
    }
    public mutating func supersede() { guard !shared else { return }; superseded = true; record("regimen_superseded") }
}
