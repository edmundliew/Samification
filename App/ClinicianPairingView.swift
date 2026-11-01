import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

struct ClinicianPairingView: View {
    let admission: ClinicalAdmission
    let account: StaffAccountStore
    @State private var pairing: PatientPairingCode?
    @State private var sessions: [PatientSessionRecord] = []
    var body: some View {
        List {
            Section { Text(admission.patient_alias).font(.headline); Text("Check the patient and admission before issuing a pairing code. A new code replaces any unused code for this admission.") }
            Section("Pair a patient device") {
                Button("Generate pairing code") {
                    pairing = nil
                    Task { await account.perform { client in
                        guard let token = account.session?.access_token else { throw StaffAPIError.authentication }
                        pairing = try await client.issuePairing(admissionID: admission.id, token: token)
                    } }
                }
                if let pairing {
                    PairingQRCode(value: pairing.token).frame(maxWidth: .infinity)
                    Text(pairing.token).font(.caption.monospaced()).textSelection(.enabled)
                    Text("Code expires: \(pairing.expires_at)").font(.caption)
                    Button("Copy pairing code") { UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: pairing.token]], options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(900)]) }
                    Text("On the patient device, open Join and paste the code. This preview displays the QR for the scanning step to be connected later.").font(.caption)
                }
            }
            Section("Patient sessions") {
                Button("Refresh sessions") { Task { await refresh() } }
                ForEach(sessions) { session in
                    VStack(alignment: .leading) {
                        Text("Session \(session.id.uuidString.prefix(8))").font(.headline)
                        Text(session.revoked_at == nil ? "Expires: \(session.expires_at)" : "Revoked").font(.caption)
                        if session.revoked_at == nil {
                            Button("Revoke patient access", role: .destructive) {
                                Task { await account.perform { client in
                                    guard let token = account.session?.access_token else { throw StaffAPIError.authentication }
                                    try await client.revokePatientSession(session.id, token: token)
                                    sessions = try await client.patientSessions(admissionID: admission.id, token: token)
                                } }
                            }
                        }
                    }
                }
            }
            if let notice = account.notice { Section { Notice(text: notice, color: account.failed ? .red : .teal) } }
        }.navigationTitle("Patient pairing").disabled(account.busy).task { await refresh() }
    }
    private func refresh() async {
        sessions = []
        await account.perform { client in
            guard let token = account.session?.access_token else { throw StaffAPIError.authentication }
            sessions = try await client.patientSessions(admissionID: admission.id, token: token)
        }
    }
}

private struct PairingQRCode: View {
    let value: String
    private var qr: UIImage? {
        let filter = CIFilter.qrCodeGenerator(); filter.message = Data(value.utf8)
        guard let output = filter.outputImage, let image = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: image)
    }
    var body: some View {
        if let qr { Image(uiImage: qr).interpolation(.none).resizable().scaledToFit().frame(width: 190, height: 190).padding(16).background(.white).accessibilityLabel("Patient pairing QR code") }
    }
}
