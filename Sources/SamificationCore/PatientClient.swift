import Foundation

public struct PatientPairingCode: Decodable, Sendable {
    public let token: String
    public let expires_at: String
}
public struct PatientSessionRecord: Decodable, Identifiable, Sendable {
    public let id: UUID
    public let admission_id: UUID
    public let expires_at: String
    public let revoked_at: String?
}
public struct PatientReferenceMedication: Decodable, Identifiable, Sendable {
    public let id: UUID
    public let code: String
    public let name: String
    public let doseMG: Double
    public let strengthMG: Double
    public let periods: Set<DayPeriod>
    public let directions: String
}
public struct PatientInboxEntry: Decodable, Identifiable, Sendable {
    public let id: UUID
    public let admission_id: UUID
    public let patient_alias: String
    public let regimen_version: Int
    public let practice: Bool
    public let status: String
    public let medications: [PatientReferenceMedication]
}

extension StaffAccessClient {
    public func beginPatientSession() async throws -> StaffSession {
        let data = try await request("/auth/v1/signup", method: "POST", body: [:])
        return try JSONDecoder().decode(StaffSession.self, from: data)
    }
    public func issuePairing(admissionID: UUID, token: String) async throws -> PatientPairingCode {
        let data = try await request("/rest/v1/rpc/issue_patient_pairing", method: "POST", body: ["wanted_admission": admissionID.uuidString], token: token)
        return try JSONDecoder().decode(PatientPairingCode.self, from: data)
    }
    public func claimPairing(code: String, token: String) async throws -> UUID {
        guard let id = UUID(uuidString: code.trimmingCharacters(in: .whitespacesAndNewlines)) else { throw StaffAPIError.rejected }
        let data = try await request("/rest/v1/rpc/claim_patient_pairing", method: "POST", body: ["pairing_token": id.uuidString.lowercased()], token: token)
        return try JSONDecoder().decode(UUID.self, from: data)
    }
    public func patientInbox(token: String) async throws -> [PatientInboxEntry] {
        let data = try await request("/rest/v1/rpc/patient_challenge_inbox", method: "POST", body: [:], token: token)
        return try JSONDecoder().decode([PatientInboxEntry].self, from: data)
    }
    public func patientSessions(admissionID: UUID, token: String) async throws -> [PatientSessionRecord] {
        try await decode([PatientSessionRecord].self, path: "/rest/v1/patient_sessions?select=id,admission_id,expires_at,revoked_at&admission_id=eq.\(admissionID.uuidString)", token: token)
    }
    public func currentPatientSessions(userID: UUID, token: String) async throws -> [PatientSessionRecord] {
        try await decode([PatientSessionRecord].self, path: "/rest/v1/patient_sessions?select=id,admission_id,expires_at,revoked_at&user_id=eq.\(userID.uuidString)", token: token)
    }
    public func revokePatientSession(_ sessionID: UUID, token: String) async throws {
        _ = try await request("/rest/v1/rpc/revoke_patient_session", method: "POST", body: ["wanted_session": sessionID.uuidString], token: token)
    }
    public func endPatientSession(token: String) async throws {
        _ = try await request("/rest/v1/rpc/end_patient_session", method: "POST", body: [:], token: token)
    }
}
