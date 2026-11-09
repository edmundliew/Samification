# Store and TestFlight copy — draft

Not submitted. Use the private App Review Information fields for the review username/password. Never put the password or a patient pairing code into public text, this file, screenshots or release notes.

## App identity

Name: Samification

Subtitle: Practise your medication routine

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
