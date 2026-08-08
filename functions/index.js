/**
 * Password reset by emailed one-time code.
 *
 * Firebase Auth cannot change the password of an account nobody is signed in
 * to, so the actual write has to happen here with the Admin SDK. The client
 * calls these three functions in order:
 *
 *   requestPasswordResetOtp  -> mails a 6-digit code
 *   verifyPasswordResetOtp   -> trades a correct code for a one-shot token
 *   resetPasswordWithOtp     -> spends the token and stores the new password
 *
 * Codes and tokens are only ever stored hashed, in a collection that the
 * security rules keep completely off-limits to clients.
 */

const crypto = require("node:crypto");

const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { defineSecret, defineString } = require("firebase-functions/params");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const nodemailer = require("nodemailer");

initializeApp();

// Keep this in sync with `passwordResetOtpLength` in
// lib/viewmodels/auth_viewmodel.dart.
const OTP_LENGTH = 6;
const OTP_TTL_MS = 10 * 60 * 1000;
const RESET_TOKEN_TTL_MS = 10 * 60 * 1000;
const MAX_ATTEMPTS = 5;
const RESEND_COOLDOWN_MS = 60 * 1000;
const COLLECTION = "passwordResetOtps";

// Change this in AppConfig.functionsRegion too if you move the deployment.
const REGION = "us-central1";

const SMTP_HOST = defineSecret("SMTP_HOST");
const SMTP_USER = defineSecret("SMTP_USER");
const SMTP_PASSWORD = defineSecret("SMTP_PASSWORD");
const SMTP_PORT = defineString("SMTP_PORT", { default: "465" });
const MAIL_FROM = defineString("MAIL_FROM", {
  default: "Little Learners <no-reply@littlelearners.app>",
});
// "smtp" sends directly with nodemailer. "firestore" instead writes to the
// `mail` collection, which the Firebase "Trigger Email from Firestore"
// extension picks up — use that if you would rather not manage SMTP secrets.
const MAIL_TRANSPORT = defineString("MAIL_TRANSPORT", { default: "smtp" });

const callOptions = {
  region: REGION,
  cors: true,
  secrets: [SMTP_HOST, SMTP_USER, SMTP_PASSWORD],
};

/** Deterministic document id so a parent can only ever hold one live code. */
function documentIdFor(email) {
  return crypto.createHash("sha256").update(email).digest("hex");
}

function hash(value, salt) {
  return crypto.createHash("sha256").update(`${salt}:${value}`).digest("hex");
}

/** Length-independent comparison, so a wrong guess leaks no timing signal. */
function safeEquals(a, b) {
  const left = Buffer.from(String(a));
  const right = Buffer.from(String(b));
  if (left.length !== right.length) return false;
  return crypto.timingSafeEqual(left, right);
}

function normalizeEmail(raw) {
  if (typeof raw !== "string") {
    throw new HttpsError("invalid-argument", "Enter a valid email address.");
  }
  const email = raw.trim().toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    throw new HttpsError("invalid-argument", "Enter a valid email address.");
  }
  return email;
}

/** Mirrors Validators.password on the client, so the rules cannot drift. */
function assertStrongPassword(password) {
  if (typeof password !== "string" || password.length === 0) {
    throw new HttpsError("invalid-argument", "Password is required.");
  }
  if (password.length < 8) {
    throw new HttpsError("invalid-argument", "Use at least 8 characters.");
  }
  if (!/[A-Z]/.test(password)) {
    throw new HttpsError(
      "invalid-argument",
      "Add at least one uppercase letter."
    );
  }
  if (!/[0-9]/.test(password)) {
    throw new HttpsError("invalid-argument", "Add at least one number.");
  }
  if (!/[!@#$%^&*(),.?":{}|<>]/.test(password)) {
    throw new HttpsError(
      "invalid-argument",
      "Add at least one special character."
    );
  }
}

function generateOtp() {
  const max = 10 ** OTP_LENGTH;
  // randomInt is uniform; Math.random is not, and this guards an account.
  return String(crypto.randomInt(0, max)).padStart(OTP_LENGTH, "0");
}

function otpEmail(otp) {
  const minutes = OTP_TTL_MS / 60000;
  return {
    subject: `${otp} is your Little Learners reset code`,
    text: [
      "Someone asked to reset the password on this Little Learners account.",
      "",
      `Your code is ${otp}. It expires in ${minutes} minutes.`,
      "",
      "If this was not you, ignore this email — the password has not changed.",
    ].join("\n"),
    html: `
      <div style="font-family:system-ui,sans-serif;max-width:480px;margin:auto">
        <h2 style="color:#4D2DD4;margin-bottom:4px">Little Learners</h2>
        <p style="color:#27245C">
          Someone asked to reset the password on this account. Enter this code
          in the app:
        </p>
        <p style="font-size:34px;font-weight:800;letter-spacing:8px;
                  color:#27245C;margin:20px 0">${otp}</p>
        <p style="color:#27245C">It expires in ${minutes} minutes.</p>
        <p style="color:#6b6b8a;font-size:13px">
          If this was not you, ignore this email — the password has not changed.
        </p>
      </div>`,
  };
}

async function sendOtpEmail(email, otp) {
  const message = otpEmail(otp);

  if (MAIL_TRANSPORT.value() === "firestore") {
    // Handed to the Trigger Email extension rather than sent from here.
    await getFirestore().collection("mail").add({
      to: [email],
      message,
      createdAt: FieldValue.serverTimestamp(),
    });
    return;
  }

  const port = Number(SMTP_PORT.value());
  const transport = nodemailer.createTransport({
    host: SMTP_HOST.value(),
    port,
    secure: port === 465,
    auth: { user: SMTP_USER.value(), pass: SMTP_PASSWORD.value() },
  });

  await transport.sendMail({
    from: MAIL_FROM.value(),
    to: email,
    subject: message.subject,
    text: message.text,
    html: message.html,
  });
}

exports.requestPasswordResetOtp = onCall(callOptions, async (request) => {
  const email = normalizeEmail(request.data?.email);

  try {
    await getAuth().getUserByEmail(email);
  } catch (error) {
    if (error.code === "auth/user-not-found") {
      throw new HttpsError("not-found", "No account found for this email.");
    }
    throw error;
  }

  const db = getFirestore();
  const ref = db.collection(COLLECTION).doc(documentIdFor(email));
  const existing = await ref.get();

  if (existing.exists) {
    const lastSentAt = existing.data().lastSentAt?.toMillis() ?? 0;
    if (Date.now() - lastSentAt < RESEND_COOLDOWN_MS) {
      throw new HttpsError(
        "resource-exhausted",
        "Wait a minute before asking for another code."
      );
    }
  }

  const otp = generateOtp();
  const salt = crypto.randomBytes(16).toString("hex");

  await ref.set({
    email,
    salt,
    otpHash: hash(otp, salt),
    expiresAt: Date.now() + OTP_TTL_MS,
    attempts: 0,
    resetTokenHash: null,
    resetTokenExpiresAt: null,
    lastSentAt: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
  });

  try {
    await sendOtpEmail(email, otp);
  } catch (error) {
    // Do not leave a live code behind for an email that never went out.
    await ref.delete();
    logger.error("Failed to send reset OTP", error);
    throw new HttpsError(
      "internal",
      "The code could not be emailed. Check the SMTP settings and try again."
    );
  }

  return { sent: true };
});

exports.verifyPasswordResetOtp = onCall(callOptions, async (request) => {
  const email = normalizeEmail(request.data?.email);
  const otp = String(request.data?.otp ?? "").trim();

  if (otp.length !== OTP_LENGTH) {
    throw new HttpsError("invalid-argument", "That code is not correct.");
  }

  const db = getFirestore();
  const ref = db.collection(COLLECTION).doc(documentIdFor(email));
  const snapshot = await ref.get();

  if (!snapshot.exists) {
    throw new HttpsError(
      "failed-precondition",
      "This code has expired. Request a new one."
    );
  }

  const data = snapshot.data();
  if (!data.otpHash || Date.now() > data.expiresAt) {
    await ref.delete();
    throw new HttpsError(
      "failed-precondition",
      "This code has expired. Request a new one."
    );
  }
  if ((data.attempts ?? 0) >= MAX_ATTEMPTS) {
    await ref.delete();
    throw new HttpsError(
      "permission-denied",
      "Too many attempts. Request a new code."
    );
  }

  if (!safeEquals(hash(otp, data.salt), data.otpHash)) {
    await ref.update({ attempts: FieldValue.increment(1) });
    throw new HttpsError("invalid-argument", "That code is not correct.");
  }

  const resetToken = crypto.randomBytes(32).toString("hex");
  await ref.update({
    // Spend the code: only the token opens the last step from here.
    otpHash: null,
    attempts: 0,
    resetTokenHash: hash(resetToken, data.salt),
    resetTokenExpiresAt: Date.now() + RESET_TOKEN_TTL_MS,
  });

  return { resetToken };
});

exports.resetPasswordWithOtp = onCall(callOptions, async (request) => {
  const email = normalizeEmail(request.data?.email);
  const resetToken = String(request.data?.resetToken ?? "");
  const newPassword = request.data?.newPassword;

  assertStrongPassword(newPassword);

  const db = getFirestore();
  const ref = db.collection(COLLECTION).doc(documentIdFor(email));
  const snapshot = await ref.get();

  if (!snapshot.exists) {
    throw new HttpsError(
      "unauthenticated",
      "Verify the code again before continuing."
    );
  }

  const data = snapshot.data();
  const tokenExpired =
    !data.resetTokenExpiresAt || Date.now() > data.resetTokenExpiresAt;

  if (
    !data.resetTokenHash ||
    tokenExpired ||
    !safeEquals(hash(resetToken, data.salt), data.resetTokenHash)
  ) {
    throw new HttpsError(
      "unauthenticated",
      "Verify the code again before continuing."
    );
  }

  // Burn the token before touching the account, so a retry cannot reuse it.
  await ref.delete();

  const user = await getAuth().getUserByEmail(email);
  await getAuth().updateUser(user.uid, { password: newPassword });
  // Sessions opened with the old password should not survive the change.
  await getAuth().revokeRefreshTokens(user.uid);

  await db.collection("parents").doc(user.uid).set(
    {
      passwordUpdatedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return { updated: true };
});
