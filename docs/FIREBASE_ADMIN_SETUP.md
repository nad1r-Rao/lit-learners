# Firebase setup for the admin panel

Everything the admin portal needs from the Firebase console, and the exact
shape of the data it reads. Written for whoever owns the
`little-learner-9d2f1` project.

Nothing here can be done from the Dart code — it is all console work, which is
why it is written down rather than automated.

---

## The short version

1. Register a **web app** (§1) — without it the portal cannot run in a browser.
2. Deploy the rules (§2).
3. Create one **`adminUsers/{uid}`** document per admin (§3).
4. Enable **Storage** if media upload is wanted (§4).

---

## 1. Register a web app

**This is the blocker.** `Firebase.initializeApp()` reads
`google-services.json` on Android and `GoogleService-Info.plist` on iOS. **The
web has no equivalent file** — the config must be passed to the app explicitly,
and there is currently no web app registered on the project at all.

1. Firebase console → **Project settings → Your apps → Add app → Web**.
2. Nickname it (for example `little-learners-admin`). Hosting is not required.
3. Copy the `firebaseConfig` values it shows.

Then connect it, either way:

**A — generated file (recommended, covers every platform)**

```sh
dart pub global activate flutterfire_cli
flutterfire configure --project=little-learner-9d2f1
```

That writes `lib/firebase_options.dart`. Then in `lib/main.dart`, replace
`options: FirebaseWebOptions.resolveOrNull()` with
`options: DefaultFirebaseOptions.currentPlatform`.

**B — build-time values (nothing generated, nothing committed)**

```sh
flutter run -d chrome \
  --dart-define=FIREBASE_API_KEY=AIza... \
  --dart-define=FIREBASE_APP_ID=1:90244160657:web:xxxxxxxx \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=90244160657 \
  --dart-define=FIREBASE_PROJECT_ID=little-learner-9d2f1 \
  --dart-define=FIREBASE_AUTH_DOMAIN=little-learner-9d2f1.firebaseapp.com \
  --dart-define=FIREBASE_STORAGE_BUCKET=little-learner-9d2f1.firebasestorage.app
```

`lib/core/config/firebase_web_options.dart` is the seam that reads these. If
required values are missing, the app prints exactly which ones and falls back
to local data rather than crashing.

> A Firebase web API key is **not a secret**. It identifies the project; it
> authorizes nothing. Access is controlled by `firestore.rules` and
> `storage.rules`.

**How to tell it worked:** the admin login screen shows a yellow *"Not
connected to Firebase"* notice whenever Firebase did not start. When the notice
is gone, the portal is live.

---

## 2. Deploy the rules

The rules are in the repo but only take effect once deployed.

```sh
firebase login
firebase use little-learner-9d2f1
firebase deploy --only firestore:rules,storage
```

**Until this is done the admin screens fail with permission-denied.** That is
the rules being stale, not a bug in the screens.

(If the Firebase CLI is broken on your machine, see item 4 of
`MANUAL_SETUP.md`.)

---

## 3. Grant admin access — the `adminUsers` collection

Admin identity lives in its own collection, not on the parent record. A
back-office user is not a family, and granting admin should not require
inventing a parent document with children attached.

### Schema

```
adminUsers/{uid}          <- document id MUST be the Firebase Auth UID

  email        string     "nadir@example.com"
  role         string     "superAdmin" | "contentAdmin" | "analyticsViewer"
  isActive     bool       true
  displayName  string     "Nadir"                (optional)
  createdAt    timestamp                          (optional)
```

### Role ids and what they allow

| Role id | Manage content & media | Read statistics | Read parent accounts |
|---|:--:|:--:|:--:|
| `superAdmin` | ✅ | ✅ | ✅ |
| `contentAdmin` | ✅ | ✅ | ❌ |
| `analyticsViewer` | ❌ | ✅ | ❌ |

The role id strings are a **data contract** — they are the `name` values of
`AdminRole` in `lib/models/admin_role.dart`. Renaming one silently demotes
every account already carrying it.

Parent accounts are the narrowest permission because that list carries parent
email addresses.

### Steps

1. Firebase console → **Authentication → Users → Add user**. Create the admin's
   email and password. (Or have them sign up as a parent first — either way an
   Auth account must exist.)
2. **Copy the User UID** from that row.
3. Firestore → **Start collection** `adminUsers` → **Document ID = that UID**.
4. Add the fields above.

That is the whole grant. No Cloud Function, no Admin SDK, no custom claims
tooling.

### Behaviour worth knowing

- **An unknown or missing `role` denies access.** A typo does not fall back to
  a default; it locks the account out. Deliberate.
- **`isActive: false` suspends without deleting**, so the record of who had
  access survives. The portal says the account was deactivated rather than
  implying they never had rights.
- **`adminUsers` is not writable from any client** (`allow write: if false`).
  Otherwise an admin could promote themselves, and anyone who compromised an
  admin session could mint more admins. Grant only from the console or a
  trusted backend.
- **Legacy accounts still work.** An account with `parents/{uid}.role == 'admin'`
  is still accepted and mapped to `contentAdmin`. Once every admin has an
  `adminUsers` document, pass `allowLegacyParentRole: false` to
  `FirebaseAdminAuthRepository` in `lib/app.dart` and drop
  `isLegacyAdminParent()` from `firestore.rules`.

---

## 4. Enable Storage (needed for media upload)

Media upload in **Manage Content → Media library** writes to Firebase Storage.
Per `MANUAL_SETUP.md` item 1, **Storage has most likely never been enabled** on
this project, so uploads fail with `object-not-found`.

Firebase console → **Build → Storage → Get started**, accept the default
bucket, then deploy the storage rules (§2).

---

## 5. Verifying it works

In order — each step depends on the one before:

1. **Portal loads over Firebase** — admin login shows no yellow notice.
2. **Sign in** with an account that has an `adminUsers` document.
   - Wrong password → *Invalid Email or Password*
   - Valid account, no `adminUsers` document → *Access Denied: Admin Rights Required*
   - `isActive: false` → *This admin account has been deactivated*
3. **Dashboard counts are real** — child profiles, parent accounts, quizzes.
   All zero on an empty project is correct.
4. **Role gating** — sign in as `contentAdmin`; *View Parent Accounts* should
   not appear in the menu.
5. **Content round-trip** — create a module and a level, publish, and confirm
   `learningModules` / `learningLevels` documents appear in Firestore.
6. **Media upload** — only after §4.

---

## Known limits

- **The Firebase admin path has never been executed against a real project.**
  Everything was verified in demo mode, because no web app existed and this
  machine has no Android SDK. The code is written to the documented contract,
  but §5 is a genuine first run, not a re-test.
- **`isAdmin()` in the rules costs a document read per evaluation.** Fine at
  this scale. If admin traffic grows, move the role to a custom claim
  (`request.auth.token.role`), which needs the Admin SDK and a deploy step.
- **The Android package is still `com.example.little_learners`**, which blocks
  a Play Store release and must be changed *before* registering SHA
  fingerprints.
