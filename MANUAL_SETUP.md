# Manual setup required

Things that cannot be fixed from the Dart code alone. Each item lists the
symptom you see in the app, the cause, and what to do about it.

Ordered roughly by how much they hurt.

---

## 1. Avatar photo upload fails

**Symptom** — picking a photo on the child profile page shows
`Avatar upload failed: No object exists at the desired reference`.

**Cause** — `No object exists at the desired reference` is Firebase Storage's
`object-not-found`. The upload path (`profileAvatars/{parentId}/...`) and the
rules in `storage.rules` are both correct, and `parentId` really is the Firebase
Auth UID, so the reference is right. What is missing is the bucket itself:
**Storage has most likely never been enabled** for the project
`little-learner-9d2f1`. Enabling Auth and Firestore does not enable Storage.

**Fix**

1. Firebase console → **Build → Storage → Get started**. Accept the default
   bucket and pick a location. This is the step that actually creates
   `little-learner-9d2f1.firebasestorage.app`.
2. Deploy the storage rules (see item 3).
3. Retry the upload.

**If it still fails**, check that the bucket name in
`android/app/google-services.json` (`storage_bucket`) matches what the console
shows under Storage. A project created before the `.firebasestorage.app` naming
change may expect `little-learner-9d2f1.appspot.com` instead; if so, re-download
`google-services.json` from the console.

The app no longer blocks on this: a failed upload now offers to save the profile
with a colour avatar instead of silently discarding everything you typed.

---

## 2. Leaderboard rules need deploying

**Symptom** — the leaderboard screen said *Leaderboard could not load.*

**Cause** — the delete rule read `resource.data.parentId` without checking that
`resource` exists. Deleting a document that is not there made the rule error out
and deny the request, which failed every leaderboard refresh.

**Fix** — the rule is already corrected in `firestore.rules`; it just has to be
deployed (see item 3). The Dart side is fixed and needs nothing from you.

Note the app only publishes scores for children with **leaderboard opt-in
enabled** on their profile. If no profile has it on, an empty board is correct
behaviour, not a bug.

---

## 3. Deploying rules and indexes

Both `firestore.rules` and `storage.rules` are in the repo but are only live once
deployed.

```bash
firebase deploy --only firestore:rules,storage
```

`firestore.indexes.json` still declares a composite index on the leaderboard
`entries` collection. The app no longer needs it — the query was reduced to a
single `orderBy` that runs on Firestore's automatic index — so deploying it is
optional:

```bash
firebase deploy --only firestore:indexes   # optional
```

---

## 4. The Firebase CLI on this machine is broken

**Symptom** — any `firebase` command dies with:

```
Error: ENOENT: no such file or directory, open
'.../lib/node_modules/firebase-tools/lib/templates/hosting/init.js'
```

**Cause** — a partially installed `firebase-tools` under the Herd-managed Node
(`v22.12.0`). The package directory is missing its `templates` folder.

**Fix**

```bash
npm uninstall -g firebase-tools
npm install -g firebase-tools
firebase login
firebase use little-learner-9d2f1
```

You need this working before items 2 and 3 can be done.

---

## 5. iOS is not configured for Firebase

**Symptom** — the app builds and runs on Android but Firebase features fail or
crash on an iOS device or simulator.

**Cause** — `ios/Runner/GoogleService-Info.plist` does not exist. Only the
Android side (`android/app/google-services.json`) was ever added.

**Fix**

1. Firebase console → Project settings → **Add app → iOS**, using the bundle id
   from `ios/Runner.xcodeproj`.
2. Download `GoogleService-Info.plist` into `ios/Runner/`.
3. Add it to the Runner target in Xcode so it ships in the bundle.

Alternatively run `flutterfire configure`, which writes a
`lib/firebase_options.dart` covering every platform at once. The project does not
currently have that file — `Firebase.initializeApp()` relies on the per-platform
config files instead.

---

## 6. Audio cues are silent

**Symptom** — the speaker button on activity cards and the Koala guide never
plays anything.

**Cause** — `assets/audio/learning/` and `assets/audio/koala/` are declared in
`pubspec.yaml` but are empty. Every `audioCueKey` in `lib/data/seed_content.dart`
(for example `trace_letter_a`, `english_apple`) points at a file that was never
recorded.

**Fix** — drop `<cueKey>.mp3` files into the matching folder. The player resolves
`audioCueKey` to `assets/audio/learning/<cueKey>.mp3` and fails quietly when the
file is absent, so this degrades gracefully and can be filled in over time.

---

## 7. Video lessons point at a placeholder clip

**Symptom** — every video lesson plays the same butterfly clip.

**Cause** — `videoUrl` in the video levels points at
`flutter.github.io/assets-for-api-docs/.../butterfly.mp4`, a Flutter sample asset
used as a stand-in.

**Fix** — replace the `videoUrl` values in `lib/data/seed_content.dart` with real
lesson URLs, or upload the lessons to Firebase Storage and use their download
URLs. **Bump `bundledContentRevision` at the top of that file** when you do, or
devices that already ran the app will keep the old content.

---

## Editing bundled content

Not a bug, but the thing most likely to waste your time.

The local SQLite database is seeded from `lib/data/seed_content.dart` **once**.
Edits to that file never reach a device that has already run the app unless
`bundledContentRevision` changes. The repository compares the stamp on launch and
reinstalls the bundle when it differs, keeping level progress and downloaded
flags intact.

So: **every time you touch `seed_content.dart`, bump `bundledContentRevision`.**
