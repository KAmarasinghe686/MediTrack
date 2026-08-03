const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const twilio = require("twilio");
const crypto = require("crypto");

admin.initializeApp();

// Configure these with the Firebase CLI. Never put their values in Flutter code.
const twilioAccountSid = defineSecret("TWILIO_ACCOUNT_SID");
const twilioAuthToken = defineSecret("TWILIO_AUTH_TOKEN");
const twilioFromNumber = defineSecret("TWILIO_FROM_NUMBER");
const emergencyAccessDurationMs = 60 * 60 * 1000;
const accessPageUrl = "https://meditrack-gr05.web.app/access.html";

/** Converts Sri Lankan local numbers and E.164 values to E.164. */
function normalizePhoneNumber(value) {
  const phone = String(value ?? "").trim().replace(/[\s()-]/g, "");
  if (/^\+\d{8,15}$/.test(phone)) return phone;
  if (/^94\d{9}$/.test(phone)) return `+${phone}`;
  if (/^0\d{9}$/.test(phone)) return `+94${phone.substring(1)}`;
  return null;
}

function getEmergencyContacts(profile) {
  const contacts = profile?.emergencyContacts;
  if (!contacts || typeof contacts !== "object") return [];

  return Object.entries(contacts)
    .map(([name, value]) => {
      const phone = typeof value === "string" ? value : value?.phone;
      return { name, phone: normalizePhoneNumber(phone) };
    })
    .filter((contact) => contact.phone !== null);
}

function emergencyMessage(alert, accessUrl) {
  const reason = String(alert.reason || "Emergency alert");
  const location = Number.isFinite(alert.latitude) && Number.isFinite(alert.longitude)
    ? ` Location: https://maps.google.com/?q=${alert.latitude},${alert.longitude}`
    : " Location is unavailable.";
  return `MediTrack EMERGENCY: ${reason}. Please contact the patient immediately.${location} Medical access (valid 60 min): ${accessUrl}`;
}

async function createEmergencyAccessLink({ patientId, alertId }) {
  const token = crypto.randomBytes(32).toString("base64url");
  const expiresAt = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + emergencyAccessDurationMs),
  );
  const accessUrl = `${accessPageUrl}?token=${encodeURIComponent(token)}`;

  await admin.firestore().collection("access_tokens").add({
    userId: patientId,
    token,
    expiresAt,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    durationMinutes: 60,
    isRevoked: false,
    purpose: "emergency_sos",
    emergencyAlertId: alertId,
  });

  return { accessUrl, expiresAt };
}

exports.sendEmergencySms = onDocumentCreated(
  {
    document: "emergency_alerts/{alertId}",
    region: "asia-southeast1",
    secrets: [twilioAccountSid, twilioAuthToken, twilioFromNumber],
  },
  async (event) => {
    const alert = event.data?.data();
    if (!alert?.patientId) {
      logger.error("Emergency alert is missing patientId", { alertId: event.params.alertId });
      return;
    }

    const alertRef = event.data.ref;
    await alertRef.update({
      smsStatus: "sending",
      smsUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    try {
      const profileSnapshot = await admin
        .firestore()
        .collection("emergency_profiles")
        .doc(alert.patientId)
        .get();
      const recipients = getEmergencyContacts(profileSnapshot.data());

      if (recipients.length === 0) {
        await alertRef.update({
          smsStatus: "no_valid_contacts",
          smsUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        logger.warn("Emergency alert has no valid SMS contacts", {
          alertId: event.params.alertId,
          patientId: alert.patientId,
        });
        return;
      }

      const { accessUrl, expiresAt } = await createEmergencyAccessLink({
        patientId: alert.patientId,
        alertId: event.params.alertId,
      });
      const client = twilio(twilioAccountSid.value(), twilioAuthToken.value());
      const body = emergencyMessage(alert, accessUrl);
      const results = await Promise.allSettled(
        recipients.map((recipient) =>
          client.messages.create({
            body,
            from: twilioFromNumber.value(),
            to: recipient.phone,
          }),
        ),
      );

      const deliveries = results.map((result, index) => ({
        name: recipients[index].name,
        phone: recipients[index].phone,
        status: result.status === "fulfilled" ? "queued" : "failed",
        messageSid: result.status === "fulfilled" ? result.value.sid : null,
        error: result.status === "rejected" ? String(result.reason) : null,
      }));
      const queuedCount = deliveries.filter(
        (delivery) => delivery.status === "queued",
      ).length;
      const smsStatus = queuedCount === deliveries.length
        ? "queued"
        : queuedCount === 0
          ? "failed"
          : "partially_failed";

      await alertRef.update({
        smsStatus,
        smsDeliveries: deliveries,
        accessLink: accessUrl,
        accessLinkExpiresAt: expiresAt,
        smsUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      logger.error("Unable to send emergency SMS", error, {
        alertId: event.params.alertId,
      });
      await alertRef.update({
        smsStatus: "failed",
        smsError: String(error),
        smsUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  },
);
