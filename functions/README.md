# Emergency SMS backend

`sendEmergencySms` runs whenever MediTrack creates an `emergency_alerts` document. It reads the patient's `emergency_profiles/{patientId}` contacts, converts Sri Lankan mobile numbers such as `0712345678` to E.164 (`+94712345678`), creates a unique 60-minute access link, and asks Twilio to send an SOS SMS with that link.

## One-time setup

1. Create a Twilio account and an SMS-capable sender number.
2. Install the function dependencies:

   ```powershell
   cd functions
   npm install
   cd ..
   ```

3. Store the Twilio values as Firebase secrets. Do not put them in the Flutter app or commit them to Git:

   ```powershell
   firebase functions:secrets:set TWILIO_ACCOUNT_SID
   firebase functions:secrets:set TWILIO_AUTH_TOKEN
   firebase functions:secrets:set TWILIO_FROM_NUMBER
   ```

   Enter the sender in E.164 form, for example `+15017122661`.

4. Deploy the backend:

   ```powershell
   firebase deploy --only functions:sendEmergencySms
   ```

Cloud Functions deployment and outbound SMS normally require Firebase billing to be enabled and an active Twilio account.

## Test

1. Save your own contact in **Emergency profile** using `0712345678` or `+94712345678`.
2. In the debug test screen, tap **Create test event**.
3. Open Firestore `emergency_alerts` and inspect `smsStatus`, `smsDeliveries`, and `accessLink`.

`queued` means Twilio accepted the request; it is not a carrier delivery guarantee. Twilio logs provide final delivery information.

Every SOS creates a different `access_tokens` document. The recipient can only use the link until its 60-minute expiry, and the existing temporary-access screen can revoke it.
