import Foundation

public struct ReviewRecord: Identifiable, Codable, Sendable {
    public let id: UUID
    public let sessionID: UUID
    public let disposition: String
    public let rationale: String
    public let at: Date
    public init(sessionID: UUID, disposition: String, rationale: String) {
        id = UUID(); self.sessionID = sessionID; self.disposition = disposition; self.rationale = rationale; at = Date()
    }
}

public struct RegimenVersion: Identifiable, Codable, Sendable {
    public let id: UUID
    public let number: Int
    public let confirmedAt: Date
    public let medications: [Medication]
    public let sourceCSV: String?
    public init(number: Int, medications: [Medication], sourceCSV: String? = nil) {
        id = UUID(); self.number = number; self.medications = medications; self.sourceCSV = sourceCSV; confirmedAt = Date()
    }
}

public enum WorkflowError: Error, LocalizedError {
    case invalid(String), newerFormat
    public var errorDescription: String? {
        switch self {
        case .invalid(let reason): return reason
        case .newerFormat: return "This saved workspace requires a newer app. The existing file has been preserved."
        }
    }
}

public struct PatientCase: Identifiable, Codable, Sendable {
    public let id: UUID
    public let label: String
    public let ward: String
    public let createdAt: Date
    public var draft: [Medication]
    public var draftSourceCSV: String?
    public private(set) var regimens: [RegimenVersion]
    public var challenges: [Challenge] = []
    public var reviews: [ReviewRecord] = []
    public var latestRegimen: RegimenVersion { regimens[regimens.count - 1] }
    public init(label: String, ward: String) {
        id = UUID(); self.label = label; self.ward = ward; createdAt = Date()
        let medications = DemoData.medications
        draft = medications; regimens = [RegimenVersion(number: 1, medications: medications)]
    }
    public var validation: [String] {
        let included = draft.filter(\.included)
        var errors = draft.flatMap(\.issues)
        if included.isEmpty { errors.append("Include at least one supported medicine.") }
        if draft.count > 20 { errors.append("A regimen supports at most 20 medicine rows.") }
        let names = included.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        if Set(names).count != names.count { errors.append("Resolve duplicate included medication names.") }
        if Set(included.map(\.id)).count != included.count || Set(included.map(\.code)).count != included.count { errors.append("Medication identifiers must be unique.") }
        return errors
    }
    public mutating func importCSV(_ text: String) throws {
        let imported = try CSVImporter.medications(from: text)
        draft = imported; draftSourceCSV = text
    }
    public mutating func confirm() throws {
        guard validation.isEmpty else { throw WorkflowError.invalid(validation.joined(separator: " ")) }
        let next = RegimenVersion(number: latestRegimen.number + 1, medications: draft.filter(\.included), sourceCSV: draftSourceCSV)
        regimens.append(next)
        for index in challenges.indices where !challenges[index].shared { challenges[index].supersede() }
    }
    @discardableResult public mutating func assign(practice: Bool) -> UUID {
        let regimen = latestRegimen
        let prior = challenges.contains { $0.regimenVersion == regimen.number && !$0.attempts.isEmpty }
        let challenge = Challenge(medications: regimen.medications, regimenVersion: regimen.number, practice: practice, priorExposure: prior)
        challenges.append(challenge); return challenge.id
    }
    public mutating func start(_ challengeID: UUID) {
        guard let index = challenges.firstIndex(where: { $0.id == challengeID }) else { return }
        let version = challenges[index].regimenVersion
        let prior = challenges.contains { $0.id != challengeID && $0.regimenVersion == version && !$0.attempts.isEmpty }
        challenges[index].start(priorExposure: prior)
    }
    public mutating func recordReview(challengeID: UUID, disposition: String, rationale: String) throws {
        let trimmed = rationale.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 4_000, challenges.contains(where: { $0.id == challengeID && $0.shared }) else {
            throw WorkflowError.invalid("A shared challenge and a review rationale of 1–4,000 characters are required.")
        }
        reviews.append(ReviewRecord(sessionID: challengeID, disposition: disposition, rationale: trimmed))
    }
}

public struct DemoWorkspace: Codable, Sendable {
    public let schemaVersion: Int
    public var selectedPatientID: UUID
    public var patients: [PatientCase]
    public init() {
        schemaVersion = 1
        let first = PatientCase(label: "P-001", ward: "Fictional Ward A")
        patients = [first, PatientCase(label: "P-002", ward: "Fictional Ward B")]; selectedPatientID = first.id
    }
    public var selectedIndex: Int { patients.firstIndex { $0.id == selectedPatientID } ?? 0 }
    @discardableResult public mutating func addPatient() -> UUID {
        let patient = PatientCase(label: String(format: "P-%03d", patients.count + 1), ward: "Fictional Ward A")
        patients.append(patient); selectedPatientID = patient.id; return patient.id
    }
    // Validate reference integrity and saved scoring evidence before restoring the local demo.
    // This detects malformed files; it is not a replacement for an authenticated server audit store.
    public func validate() throws {
        guard schemaVersion == 1 else { throw WorkflowError.newerFormat }
        guard !patients.isEmpty, patients.contains(where: { $0.id == selectedPatientID }), Set(patients.map(\.id)).count == patients.count else {
            throw WorkflowError.invalid("The saved patient workspace is invalid. The file has been preserved.")
        }
        var sessionIDs = Set<UUID>()
        for patient in patients {
            guard !patient.regimens.isEmpty, patient.regimens.enumerated().allSatisfy({ $0.element.number == $0.offset + 1 }) else { throw WorkflowError.invalid("Invalid saved regimen history.") }
            for regimen in patient.regimens {
                guard !regimen.medications.isEmpty, regimen.medications.allSatisfy({ $0.included && $0.issues.isEmpty }), Set(regimen.medications.map(\.id)).count == regimen.medications.count else { throw WorkflowError.invalid("Invalid saved confirmed regimen.") }
            }
            for challenge in patient.challenges {
                guard sessionIDs.insert(challenge.id).inserted,
                      let regimen = patient.regimens.first(where: { $0.number == challenge.regimenVersion }), regimen.medications == challenge.medications else {
                    throw WorkflowError.invalid("A saved challenge has no matching patient regimen.")
                }
                for (index, attempt) in challenge.attempts.enumerated() {
                    guard attempt.number == index + 1, attempt.scoringVersion == Score.rulesVersion,
                          attempt.hintsBefore >= 0, attempt.feedbackBefore == index,
                          attempt.score == Score.evaluate(medications: regimen.medications, tray: attempt.tray) else {
                        throw WorkflowError.invalid("Saved assessment evidence failed validation.")
                    }
                }
                if challenge.shared && challenge.attempts.isEmpty { throw WorkflowError.invalid("A completed challenge has no submission.") }
            }
            guard patient.reviews.allSatisfy({ r in patient.challenges.contains { $0.id == r.sessionID && $0.shared } }) else { throw WorkflowError.invalid("A saved review has no shared challenge.") }
        }
    }
}

public struct WorkspaceRepository {
    public let url: URL
    public init(url: URL) { self.url = url }
    public static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Samification", isDirectory: true).appendingPathComponent("fictional-demo-v1.json")
    }
    public func load() throws -> DemoWorkspace? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let workspace = try JSONDecoder().decode(DemoWorkspace.self, from: Data(contentsOf: url))
        try workspace.validate(); return workspace
    }
    public func save(_ workspace: DemoWorkspace) throws {
        try workspace.validate()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(workspace)
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: .atomic)
        #endif
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    // Preserve the old file as a backup before starting a new fictional demo.
    public func archive() throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let backup = url.deletingLastPathComponent().appendingPathComponent("fictional-demo-backup-\(UUID().uuidString).json")
        try FileManager.default.copyItem(at: url, to: backup)
    }
}
