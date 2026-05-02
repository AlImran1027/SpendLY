/**
 * Spendly — Firebase Cloud Functions
 *
 * These functions send FCM push notifications for split-bill events so that
 * recipients and initiators are alerted even when the app is closed.
 *
 * DEPLOY STEPS
 * ─────────────
 * 1. npm install -g firebase-tools        (if not already installed)
 * 2. cd functions && npm install
 * 3. firebase login
 * 4. firebase use spendly-295d9           (or: firebase use --add)
 * 5. firebase deploy --only functions
 *
 * REQUIRED Firestore rules (already documented in split_bill_service.dart)
 */

const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

// ─── Helper ───────────────────────────────────────────────────────────────────

/**
 * Fetches the FCM token stored on a userProfile document.
 * Returns null if the document does not exist or has no token.
 */
async function getFcmToken(uid) {
  const doc = await db.collection("userProfiles").doc(uid).get();
  if (!doc.exists) return null;
  return doc.data().fcmToken || null;
}

/**
 * Sends an FCM message to a single token. Silently ignores invalid tokens
 * (which happen when a user reinstalls the app and the old token expires).
 */
async function sendToToken(token, title, body, data = {}) {
  try {
    await messaging.send({
      token,
      notification: { title, body },
      data,
      android: {
        priority: "high",
        notification: { channelId: "spendly_alerts" },
      },
      apns: {
        payload: { aps: { sound: "default", badge: 1 } },
      },
    });
  } catch (err) {
    // Stale / invalid tokens produce 'messaging/registration-token-not-registered'
    // — safe to ignore since the token will be refreshed on next app open.
    if (err.code !== "messaging/registration-token-not-registered") {
      console.error("sendToToken error:", err.message);
    }
  }
}

// ─── Trigger 1: New split request created ─────────────────────────────────────

/**
 * Fires when a new splitRequest document is written to Firestore.
 * Sends an FCM notification to every recipient so they're alerted even if
 * the app is closed.
 */
exports.onSplitRequestCreated = onDocumentCreated(
  "splitRequests/{splitId}",
  async (event) => {
    const data = event.data.data();
    const splitId = event.params.splitId;

    const recipientUids = data.recipientUids || [];
    const initiatorName = data.initiatorName || data.initiatorEmail || "Someone";
    const merchant = data.merchant || "a bill";
    const amountPerPerson = (data.amountPerPerson || 0).toFixed(2);

    const sendPromises = recipientUids.map(async (uid) => {
      const token = await getFcmToken(uid);
      if (!token) return;
      await sendToToken(
        token,
        `Split Request from ${initiatorName}`,
        `${merchant} · Your share: ${amountPerPerson}`,
        { type: "split_request", splitId }
      );
    });

    await Promise.all(sendPromises);
  }
);

// ─── Trigger 2: Recipient status changed ──────────────────────────────────────

/**
 * Fires when a splitRequest document is updated.
 *
 * Cases handled:
 *   • A recipient changes their status to 'rejected' →
 *     notify the initiator so they see the rejection banner.
 *   • A recipient changes their status to 'accepted' AND all recipients are
 *     now accepted → notify the initiator that the split is fully confirmed.
 *   • retriedAt changes (initiator retried) →
 *     notify each still-pending recipient again.
 */
exports.onSplitRequestUpdated = onDocumentUpdated(
  "splitRequests/{splitId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const splitId = event.params.splitId;

    const initiatorUid = after.initiatorUid;
    const merchant = after.merchant || "a bill";
    const amountPerPerson = (after.amountPerPerson || 0).toFixed(2);
    const beforeRecipients = before.recipients || {};
    const afterRecipients = after.recipients || {};

    // ── Case A: A recipient just rejected ──────────────────────────────────
    const newlyRejected = Object.entries(afterRecipients).filter(
      ([uid, r]) =>
        beforeRecipients[uid]?.status !== "rejected" && r.status === "rejected"
    );
    if (newlyRejected.length > 0) {
      const names = newlyRejected
        .map(([, r]) => r.name || r.email || "Someone")
        .join(", ");
      const token = await getFcmToken(initiatorUid);
      if (token) {
        await sendToToken(
          token,
          "Split Request Declined",
          `${names} declined the ${merchant} split`,
          { type: "split_rejected", splitId }
        );
      }
    }

    // ── Case B: All recipients just accepted ───────────────────────────────
    const allAcceptedNow = Object.values(afterRecipients).every(
      (r) => r.status === "accepted"
    );
    const wasAlreadySaved = after.initiatorExpenseSaved === true;
    const allAcceptedBefore = Object.values(beforeRecipients).every(
      (r) => r.status === "accepted"
    );
    if (allAcceptedNow && !allAcceptedBefore && !wasAlreadySaved) {
      const token = await getFcmToken(initiatorUid);
      if (token) {
        await sendToToken(
          token,
          `Split Accepted — ${merchant}`,
          `Everyone accepted! Your share (${amountPerPerson}) was added to expenses.`,
          { type: "split_all_accepted", splitId }
        );
      }
    }

    // ── Case C: Initiator retried — notify pending recipients again ────────
    const retriedBefore = before.retriedAt;
    const retriedAfter = after.retriedAt;
    const wasRetried =
      retriedAfter &&
      (!retriedBefore ||
        retriedAfter.toMillis() !== retriedBefore.toMillis());

    if (wasRetried) {
      const pendingUids = Object.entries(afterRecipients)
        .filter(([, r]) => r.status === "pending")
        .map(([uid]) => uid);

      const initiatorName =
        after.initiatorName || after.initiatorEmail || "Someone";

      const sendPromises = pendingUids.map(async (uid) => {
        const token = await getFcmToken(uid);
        if (!token) return;
        await sendToToken(
          token,
          `Retry: Split Request from ${initiatorName}`,
          `${merchant} · Your share: ${amountPerPerson}`,
          { type: "split_retry", splitId }
        );
      });

      await Promise.all(sendPromises);
    }
  }
);
