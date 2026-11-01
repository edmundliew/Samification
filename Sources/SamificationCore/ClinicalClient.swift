import Foundation

public struct ClinicalAdmission: Decodable, Identifiable, Sendable {
    public let id: UUID
    public let scope_id: UUID
    public let patient_alias: String
    public let status: String
}
public struct ClinicalRegimen: Decodable, Identifiable, Sendable {
    public let id: UUID
    public let admission_id: UUID
    public let version: Int
    public let medications: [Medication]
    public let original_csv: String?
}
public struct ClinicalAssignment: Decodable, Identifiable, Sendable {
    public let id: UUID
    public let admission_id: UUID
    public let regimen_id: UUID
    public let practice: Bool
    public let status: String
}

extension StaffAccessClient {
    public func admissions(token: String) async throws -> [ClinicalAdmission] {
        try await decode([ClinicalAdmission].self, path: "/rest/v1/patient_admissions?select=id,scope_id,patient_alias,status&order=created_at.desc", token: token)
    }
    public func regimens(admissionID: UUID, token: String) async throws -> [ClinicalRegimen] {
        try await decode([ClinicalRegimen].self, path: "/rest/v1/regimen_versions?select=id,admission_id,version,medications,original_csv&admission_id=eq.\(admissionID.uuidString)&order=version.desc", token: token)
    }
    public func assignments(admissionID: UUID, token: String) async throws -> [ClinicalAssignment] {
        try await decode([ClinicalAssignment].self, path: "/rest/v1/clinical_assignments?select=id,admission_id,regimen_id,practice,status&admission_id=eq.\(admissionID.uuidString)&order=assigned_at.desc", token: token)
    }
    public func createAdmission(scope: UUID, alias: String, token: String) async throws -> UUID {
        let value = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 100 else { throw StaffAPIError.rejected }
        let data = try await request("/rest/v1/rpc/create_patient_admission", method: "POST", body: ["wanted_scope": scope.uuidString, "patient_alias": value], token: token)
        return try JSONDecoder().decode(UUID.self, from: data)
    }
    public func confirmRegimen(admissionID: UUID, medications: [Medication], sourceCSV: String?, token: String) async throws -> UUID {
        guard !medications.isEmpty, medications.count <= 20, medications.allSatisfy({ $0.included && $0.issues.isEmpty }), (sourceCSV?.utf8.count ?? 0) <= 200_000 else { throw StaffAPIError.rejected }
        let snapshot = try JSONSerialization.jsonObject(with: JSONEncoder().encode(medications))
        let data = try await request("/rest/v1/rpc/confirm_patient_regimen", method: "POST", body: ["wanted_admission": admissionID.uuidString, "medication_snapshot": snapshot, "source_csv": sourceCSV.map { $0 as Any } ?? NSNull()], token: token)
        return try JSONDecoder().decode(UUID.self, from: data)
    }
    // Keep assignmentID unchanged on network retry. The server deduplicates identical requests.
    public func assignChallenge(admissionID: UUID, regimenID: UUID, practice: Bool, assignmentID: UUID, token: String) async throws -> UUID {
        let data = try await request("/rest/v1/rpc/assign_patient_challenge", method: "POST", body: ["wanted_admission": admissionID.uuidString, "wanted_regimen": regimenID.uuidString, "practice_mode": practice, "assignment_id": assignmentID.uuidString], token: token)
        return try JSONDecoder().decode(UUID.self, from: data)
    }
    public func dischargeAdmission(_ admissionID: UUID, token: String) async throws {
        _ = try await request("/rest/v1/rpc/discharge_patient_admission", method: "POST", body: ["wanted_admission": admissionID.uuidString], token: token)
    }
}
