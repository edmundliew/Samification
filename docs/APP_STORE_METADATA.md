# Store and TestFlight copy — build 8 preparation

Not submitted. Use the private App Review Information fields for the review username/password. Never put the password or a patient pairing code into public text, this file, screenshots or release notes.

## App identity

Name: Samification

Subtitle: Practise medication routines

Primary category proposal: Medical

Keywords: medication,practice,patient,education,clinician,medicine,training,tray

## Description

Samification helps patients practise organising their medicines through visual medication challenges, and helps clinicians review performance on those tasks.

For patients:
- Select Play Samification and enter the game code from your care team.
- Read your assigned medication reference.
- Tap or drag medication images into Morning, Afternoon, Evening and Bedtime tray compartments.
- Check your tray, review feedback and practise again.

For clinicians:
- Review a medication CSV and confirm names, strengths, doses, instructions and day periods.
- Assign a practice or assessment challenge to a patient admission.
- Review dose preparation, schedule placement, first-attempt performance, retries and assistance used.
- Inspect recorded evidence and save a separate clinical review.

A fictional Try demo experience is available without sign-in or a patient game code.

Challenge results describe performance on virtual medication tasks. They do not verify that medication was taken, measure actual medication adherence, or automatically qualify someone for self-administration. Clinical decisions remain with the care team under local policy. Medication images are reference illustrations and must be checked against the actual product supplied.

## TestFlight — What to test

Development pilot: use fictional records only.

Please test:
1. Staff email/password sign-in, sign-out and session restoration.
2. Medication CSV upload, name edits, validation and regimen confirmation.
3. Assignment of practice and assessment challenges.
4. Patient device pairing using a fresh game code from the fictional admission.
5. Medication selection by tap and drag, horizontal medicine scrolling, four time compartments, removing a tray tablet and Clear all.
6. Incorrect feedback, hints, retries, correct submission and sharing/locking a completed challenge.
7. Clinician evidence, first-attempt results, retry/assistance counts and separate clinical review.
8. iPhone/iPad layout, larger text, VoiceOver and device background/foreground behavior.

Report device model, iOS/iPadOS version, steps and expected/actual behavior through TestFlight feedback. Include only fictional data. Do not include passwords or game codes.

## Private reviewer notes

Use the credentials in App Review Information. The review identity is scoped only to App Review Ward (fictional only), with no administrator access. Open APPLE-REVIEW-001 · Fictional patient to see the four-medication regimen. Generate a fresh patient game code when testing; codes expire in 15 minutes. For the connected patient workflow use a second device. Try demo provides a single-device fictional clinician/patient walkthrough.

## Remaining public submission details

Public support URL/contact, privacy policy URL and retention/deletion procedures, App Review contact phone, screenshots, age-rating questionnaire and App Privacy declarations must be completed before public submission. Do not invent contact details or claim a retention period that has not been established.

Technical privacy inventory for preparing those declarations: staff names/emails and Auth IDs, scoped membership/access requests, patient aliases/admission IDs, prescribed medication snapshots/imported CSV, assigned challenge actions and scoring evidence, clinician review rationale and access/clinical audit events. These support app functionality; there is no advertising or cross-app tracking integration in this source. Backend uses the configured Supabase project; sessions use Apple Keychain for staff and memory for temporary patient sessions. A privacy manifest does not replace the App Store privacy disclosures or a public privacy policy.


## Build 8 preparation checkpoint — 9 November 2026

The Help guide is included in native build 0.2.0 (8). It is accessible before sign-in, from the patient Help tab, clinician Help tab and demo guide. The iPad simulator displayed the guide and clinician code-generation steps successfully. Build 7 was a source checkpoint and was not uploaded.

App Store Connect version 0.2.0 has promotional text, description, keywords, copyright and owner contact name/email entered. The save was rejected because the private review phone is missing; these new edits are not yet confirmed persisted. Do not navigate away until saved. Existing protected reviewer credentials remain present.

Owner approved public support/privacy contact: edmund_liew@live.com. Private review name: Yong Hock Liew. The actual phone number is still requested. Do not use a fabricated phone, placeholder policy URL, expired game code or unsupported privacy declaration.

Required product screenshots: iPhone large-display set (for example 1320×2868) and iPad 13-inch set (2064×2752 or 2048×2732). The 1640×2360 iPad A16 Help capture is useful review evidence but does not satisfy the required 13-inch set. An App Review walkthrough attachment is separate from the optional public 15–30 second App Preview. Capture real app screens using fictional records and exclude credentials/codes.

Public submission gaps found in source: account creation exists but in-app account deletion is absent; temporary patient identity is not persisted across cold restart; privacy/support pages and a real retention/deletion procedure are not yet published; the build is labelled a development beta. Do not represent this build as an approved or clinically validated production service. Do not submit invented answers to data collection, content rights or regulated-device questions.

Apple references checked 9 November 2026:
- https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications
- https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion
- https://developer.apple.com/app-store/review/guidelines/


Media/archive outcome: The iPad A16 Help page and clinician walkthrough were observed in the native simulator. One original 1640×2360 Help screenshot was saved. Repeated native-control timeouts prevented completion of the 13-inch simulator captures, walkthrough video and archive distribution. Archive was started in Xcode but no success/upload outcome was observed. No video, complete required screenshot set, build 8 upload, review submission or approval is claimed. Current live internal TestFlight build remains 0.2.0 (6).
