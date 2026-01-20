const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// Set your region (must match the client region in FirebaseFunctions.instanceFor)
const REGION = "us-central1"; // change if your project uses a different region

exports.setUserClaims = functions.region(REGION).https.onCall(async (data, context) => {
  const uid = data.uid;
  const role = data.role;
  const companyId = data.companyId;
  const perms = data.perms;

  if (!uid || !role || !companyId) {
    throw new functions.https.HttpsError("invalid-argument", "uid, role, and companyId are required");
  }

  await admin.auth().setCustomUserClaims(uid, { role, companyId, perms });
  await admin.auth().revokeRefreshTokens(uid);

  return { ok: true };
});

// Temporary/one-time helper to backfill claims from Firestore users collection
exports.backfillUserClaims = functions.region(REGION).https.onCall(async (_data, context) => {
  // Optional: restrict to super admins
  // if (!context.auth || context.auth.token.role !== "super_admin") {
  //   throw new functions.https.HttpsError("permission-denied", "Admins only");
  // }

  const snap = await admin.firestore().collection("users").get();
  let updated = 0;
  for (const doc of snap.docs) {
    const d = doc.data();
    const uid = doc.id;
    const role = (d.role || (d.permissions && d.permissions.role) || "").toString() || "user";
    const companyId = (d.companyId || d.company_id || "").toString();
    const perms = d.permissions || null;
    if (!companyId) continue; // skip if missing company
    await admin.auth().setCustomUserClaims(uid, { role, companyId, perms });
    updated++;
  }
  return { updated };
});
