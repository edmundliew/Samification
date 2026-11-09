import SwiftUI

/// Shared instructions contain no credentials or patient-specific pairing codes.
struct TesterHelpView: View {
    var body: some View {
        List {
            Section {
                Label("Start with Try demo", systemImage: "play.circle.fill")
                    .font(.headline)
                Text("New to Samification? Explore the game on one device without a login or game code. For connected testing, use a clinician device and a separate patient device.")
                Text("TestFlight beta · Use fictional records only.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("How the app works") {
                Label("Clinician prepares medicines", systemImage: "list.clipboard")
                Label("Assigns challenge and provides game code", systemImage: "paperplane")
                Label("Patient plays and shares results", systemImage: "pills")
                Label("Clinician reviews attempts and evidence", systemImage: "chart.bar")
            }
            Section {
                NavigationLink { demoGuide } label: {
                    Label("1 · Try the demo on one device", systemImage: "play.circle")
                }
                NavigationLink { clinicianGuide } label: {
                    Label("2 · Clinician: assign and get a game code", systemImage: "person.crop.rectangle")
                }
                NavigationLink { patientGuide } label: {
                    Label("3 · Patient: join and play", systemImage: "pills")
                }
                NavigationLink { resultsGuide } label: {
                    Label("4 · Clinician: review the results", systemImage: "chart.bar")
                }
                NavigationLink { troubleshooting } label: {
                    Label("Stuck? Find help here", systemImage: "wrench.and.screwdriver")
                }
            } header: {
                Text("Step-by-step guides")
            } footer: {
                Text("Help does not end your patient session. Return to the Play tab to continue.")
            }
            Section("What results mean") {
                Text("Dose preparation measures correct tablet quantities. Schedule placement measures placement in the expected day periods. Assistance & retries preserves the first answer, subsequent attempts and hints.")
                Text("Game results measure performance in this virtual challenge. They do not measure actual medication adherence or automatically qualify anyone for self-administration. A clinician makes that decision under local policy.")
            }
        }.navigationTitle("Help")
    }

    private var demoGuide: some View {
        List {
            Section("No sign-in or code needed") {
                HelpStep(number: 1, title: "Open Try demo", text: "On the welcome screen, tap Try demo. If you are on the game-code screen, tap Back first. Connected clinicians can sign out from Account to return to the welcome screen.", symbol: "play.circle")
                HelpStep(number: 2, title: "Assign a challenge", text: "In the Clinician demo preview, open Assign. The four sample medicines are already confirmed. Select a fictional patient, choose Practice mode if wanted, then tap Assign to that patient.", symbol: "paperplane")
                HelpStep(number: 3, title: "Open the patient preview", text: "Tap Open patient preview, then open the assigned challenge. Demo previews share this device's fictional workspace; they do not send anything to another device.", symbol: "person")
                HelpStep(number: 4, title: "Play, then inspect results", text: "Fill and check the tray. Try an error, a hint and a corrected answer, then share the results. Switch the demo preview to Clinician and open Results to inspect each attempt.", symbol: "chart.bar")
            }
        }.navigationTitle("Try the demo")
    }

    private var clinicianGuide: some View {
        List {
            Section("Connected testing · clinician device") {
                HelpStep(number: 1, title: "Sign in", text: "Choose Staff sign-in on the welcome screen. Use the test clinician email and password supplied separately by the test organiser. New staff accounts need ward approval; creating an account alone does not grant access.", symbol: "person.crop.rectangle")
                HelpStep(number: 2, title: "Select the fictional patient", text: "Open Patients and select the intended admission. The supplied review account uses App Review Ward (fictional only) and patient APPLE-REVIEW-001. Check the ward and patient before continuing.", symbol: "person.2")
                HelpStep(number: 3, title: "Check the medicines", text: "For the supplied test patient, expand Confirmed regimen history to review the four medicines. To test a new CSV, tap Import fictional medication CSV, review names, doses, strengths, day periods and directions, resolve issues, then tap Confirm regimen. Importing is optional for the preloaded patient.", symbol: "list.clipboard")
                HelpStep(number: 4, title: "Assign a fresh challenge", text: "Under Assign current regimen, choose Practice mode for guided testing, then tap Save challenge assignment. Check Assignments for its status. A completed challenge is locked; assign a fresh challenge for a new run.", symbol: "paperplane")
                HelpStep(number: 5, title: "Generate the game code", text: "Under Patient access, tap Pair a patient device. Tap Generate pairing code, then Copy pairing code. This pairing code is the patient's game code. A new code replaces any unused code for that admission.", symbol: "qrcode")
                HelpStep(number: 6, title: "Give it to the patient tester", text: "On the separate patient device, choose Play Samification, paste the complete code and tap Continue. The code expires after 15 minutes and can be claimed by one patient identity. QR scanning is not connected in this beta; paste the text code.", symbol: "iphone.and.arrow.forward")
            }
        }.navigationTitle("Clinician setup")
    }

    private var patientGuide: some View {
        List {
            Section("Connected testing · patient device") {
                HelpStep(number: 1, title: "Join the challenge", text: "Choose Play Samification on the welcome screen. Ask your clinician for a fresh game code, paste it in Game code and tap Continue. Patients do not need a staff account or email sign-in.", symbol: "qrcode")
                HelpStep(number: 2, title: "Open your assignment", text: "In My challenges, expand the patient and regimen entry, then tap Open medication challenge. If nothing appears, tap Refresh assigned challenges or ask the clinician to save an assignment.", symbol: "tray")
                HelpStep(number: 3, title: "Read and prepare", text: "Use Open medication reference to check the instructions. Select Morning, Afternoon, Evening or Bedtime, then tap a medication package image to add one tablet there. Or drag the image directly into a compartment. Swipe the medicine row sideways to find more medicines.", symbol: "pills")
                HelpStep(number: 4, title: "Adjust your tray", text: "Tap a tablet already in the tray to remove it. Clear all empties the current tray. Clearing does not erase previous submissions or hint counts.", symbol: "arrow.counterclockwise")
                HelpStep(number: 5, title: "Check and learn", text: "Tap Check my daily tray. Incorrect answers show red feedback; correct answers show green. Ask for a hint appears after an incorrect answer. Change the tray and check again. Each submission and hint is recorded.", symbol: "checkmark.circle")
                HelpStep(number: 6, title: "Finish and share", text: "After checking your latest tray, tap Finish & share results. Wait for confirmation. Sharing locks the challenge and makes the saved evidence available to the clinician.", symbol: "paperplane")
            }
            Section("Keep the session open") {
                Text("You can use the Help tab and return to Play. Closing the app completely currently loses the temporary patient sign-in. Ask your clinician for a new game code and, if needed, a fresh challenge. Ending the patient session also ends connected access.")
            }
        }.navigationTitle("Patient play guide")
    }

    private var resultsGuide: some View {
        List {
            Section("Back on the clinician device") {
                HelpStep(number: 1, title: "Open the patient's evidence", text: "In Patients, select the same admission, then tap Review challenge evidence. Tap Refresh results if the new challenge is not listed, then open it.", symbol: "chart.bar")
                HelpStep(number: 2, title: "Inspect every attempt", text: "Compare first-attempt correctness with the final answer. Inspect dose preparation, schedule placement, extras, omissions, total submissions, retries, first correct attempt and hint/reference use. A corrected answer does not overwrite the first attempt.", symbol: "list.bullet.rectangle")
                HelpStep(number: 3, title: "Review the audit timeline", text: "Check the sequence of start, submissions, assistance and finish events. Practice and assessment results are labelled separately. Results retain the regimen version used in the challenge.", symbol: "clock")
                HelpStep(number: 4, title: "Record a separate review", text: "If testing clinician review, select the appropriate review outcome, enter your rationale and tap Save review. The game does not approve self-administration on its own.", symbol: "square.and.pencil")
            }
        }.navigationTitle("Review results")
    }

    private var troubleshooting: some View {
        List {
            Section("I don't have a game code") {
                Text("A clinician must sign in, select the admission, save a challenge assignment, then open Pair a patient device → Generate pairing code. Use Try demo if you only want to explore without a clinician.")
            }
            Section("Continue is disabled or the code failed") {
                Text("Paste the whole text code, not the patient name or QR image. Codes expire after 15 minutes and are single-use for a patient identity. Ask for a new code if expired, replaced or already used.")
            }
            Section("No challenge is available") {
                Text("Tap Refresh assigned challenges. Ask the clinician to check that the correct admission has a current assignment. Completed or superseded challenges cannot be restarted; the clinician can save a fresh challenge.")
            }
            Section("Sign-in or ward access failed") {
                Text("Check the email and password supplied by the test organiser. Staff need an approved ward membership. A patient game code does not work in Staff sign-in. If your session expired, sign in again.")
            }
            Section("A save or share failed") {
                Text("Check your connection and the displayed message. If Retry pending action is shown, use it to resend the same pending action. For clinician saves, refresh the latest status before saving again. Do not assume results were shared until the app confirms completion.")
            }
            Section("Send useful beta feedback") {
                Text("Use TestFlight's feedback option. Include your device, the screen, the steps you took, what you expected and what happened. Include a screenshot when useful. Keep passwords, game codes and real patient details out of feedback.")
            }
        }.navigationTitle("Troubleshooting")
    }
}
