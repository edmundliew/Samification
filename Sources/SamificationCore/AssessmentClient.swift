import Foundation

public struct AssessmentResult: Codable, Sendable {
    public let sequence: Int
    public let kind: String
    public let priorExposure: Bool
    public let submissions: Int
    public let hints: Int
    public let references: Int
    public let scoringVersion: String
    public let score: Score?
    public let attempt: Int?
    public let hintsBefore: Int?
    public let feedbackBefore: Int?
    public let referencesBefore: Int?
    public let firstAttemptCorrect: Bool?
    public let firstCorrectAttempt: Int?
    public let retries: Int?
    public let completed: Bool?
}
public struct AssessmentAction: Decodable, Identifiable, Sendable {
    public let id: UUID
    public let recorded_at: String
    public let kind: String
    public let payload: [String: [String: Int]]
    public let result: AssessmentResult
}
public struct ClinicalRun: Decodable, Identifiable, Sendable {
    public let id: UUID
    public let admission_id: UUID
    public let started_at: String
    public let prior_exposure: Bool
    public let finished_at: String?
}
public struct ClinicalReview: Decodable, Identifiable, Sendable {
    public let id: UUID
    public let clinician_id: UUID
    public let recorded_at: String
    public let decision: String
    public let note: String
}
public struct PendingAssessmentAction: Sendable {
    public let id: UUID
    public let kind: String
    public let expectedPrevious: Int
    public let payload: [String: [String: Int]]
    public init(kind: String, tray: Tray? = nil, medications: [Medication] = [], expectedPrevious: Int = 0) {
        id = UUID(); self.kind = kind; self.expectedPrevious = expectedPrevious
        payload = tray.map { $0.wireCounts(medications: medications) } ?? [:]
    }
}
extension Tray {
    public func wireCounts(medications: [Medication]) -> [String: [String: Int]] {
        Dictionary(uniqueKeysWithValues: DayPeriod.allCases.map { period in
            (period.rawValue, Dictionary(uniqueKeysWithValues: medications.filter { count($0.id, at: period) > 0 }.map { ($0.id.uuidString.lowercased(), count($0.id, at: period)) }))
        })
    }
    public static func fromWire(_ payload: [String: [String: Int]]) throws -> Tray {
        var tray = Tray()
        for (period, values) in payload {
            guard let day = DayPeriod(rawValue: period) else { throw StaffAPIError.rejected }
            for (id, count) in values {
                guard let uuid = UUID(uuidString: id), (0...12).contains(count) else { throw StaffAPIError.rejected }
                for _ in 0..<count { tray.add(uuid, at: day) }
            }
        }
        return tray
    }
}
extension PatientInboxEntry {
    public var gameMedications: [Medication] {
        medications.map { m in Medication(id: m.id, code: m.code, name: m.name, doseMG: m.doseMG, strengthMG: m.strengthMG, periods: m.periods, directions: m.directions, confirmed: true) }
    }
}
extension StaffAccessClient {
    public func assessmentAction(assignment: UUID, pending: PendingAssessmentAction, token: String) async throws -> AssessmentResult {
        let data = try await request("/rest/v1/rpc/patient_challenge_action", method: "POST", body: ["wanted_assignment": assignment.uuidString, "request_id": pending.id.uuidString, "action_kind": pending.kind, "action_payload": pending.payload, "expected_previous": pending.expectedPrevious], token: token)
        return try JSONDecoder().decode(AssessmentResult.self, from: data)
    }
    public func assessmentHistory(assignment: UUID, token: String) async throws -> [AssessmentAction] {
        let data = try await request("/rest/v1/rpc/patient_challenge_history", method: "POST", body: ["wanted_assignment": assignment.uuidString], token: token)
        return try JSONDecoder().decode([AssessmentAction].self, from: data)
    }
    public func clinicalRuns(admission: UUID, token: String) async throws -> [ClinicalRun] {
        try await decode([ClinicalRun].self, path: "/rest/v1/challenge_runs?select=id,admission_id,started_at,prior_exposure,finished_at&admission_id=eq.\(admission.uuidString)&order=started_at.desc", token: token)
    }
    public func clinicalActions(run: UUID, token: String) async throws -> [AssessmentAction] {
        try await decode([AssessmentAction].self, path: "/rest/v1/challenge_actions?select=id,recorded_at,kind,payload,result&run_id=eq.\(run.uuidString)&order=sequence.asc", token: token)
    }
    public func clinicalReviews(run: UUID, token: String) async throws -> [ClinicalReview] {
        try await decode([ClinicalReview].self, path: "/rest/v1/challenge_reviews?select=id,clinician_id,recorded_at,decision,note&run_id=eq.\(run.uuidString)&order=recorded_at.desc", token: token)
    }
    public func reviewChallenge(run: UUID, requestID: UUID, decision: String, note: String, token: String) async throws {
        _ = try await request("/rest/v1/rpc/review_challenge", method: "POST", body: ["wanted_run": run.uuidString, "request_id": requestID.uuidString, "review_decision": decision, "review_note": note], token: token)
    }
}
