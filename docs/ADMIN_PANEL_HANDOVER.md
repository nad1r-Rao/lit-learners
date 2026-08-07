# Admin Panel — Implementation & Handover

**Branch:** `feat/admin-panel` (14 commits off `main` @ `4733d74`)
**Date:** 2026-08-07
**Status:** Complete against the written specification. **Not production-verified** — see [Caveats](#caveats-read-before-trusting-this).

Read this before touching the admin panel or the sync layer. It records what
exists, what is deliberately unfinished, and what is already built but never
called — so nothing here gets rebuilt from scratch.

---

## 1. What was implemented

All six admin requirements and use cases UC-18, UC-19, UC-20.

| Spec item | Where |
|---|---|
| UC-18 admin login, separate session | `lib/repositories/admin_auth_repository.dart`, `firebase_admin_auth_repository.dart`, `lib/viewmodels/admin_auth_viewmodel.dart`, `lib/views/admin/admin_login_page.dart` |
| Req 1 — dashboard counts | `lib/views/admin/admin_dashboard_page.dart` |
| Req 2 — four-item menu | same |
| Req 3 / UC-19 — manage content | `lib/views/admin/admin_content_page.dart` (pre-existing, migrated to admin session) |
| UC-19 step 4 — media upload | `lib/views/admin/admin_media_page.dart`, `lib/viewmodels/admin_media_viewmodel.dart` |
| Req 4 — parent accounts | `lib/views/admin/admin_parent_accounts_page.dart` |
| Req 5 — progress statistics | `lib/views/admin/admin_progress_statistics_page.dart` |
| Req 6 / UC-20 — logout | `confirmAdminLogout()` in `lib/views/admin/widgets/admin_scaffold.dart` |
| Statistics data | `lib/models/admin_stats.dart`, `admin_stats_repository.dart`, `firestore_admin_stats_repository.dart`, `local_admin_stats_repository.dart` |
| Admin read rules | `firestore.rules` |

**Important:** the admin panel was **not** greenfield. A dashboard, an 803-line
content CRUD page with a draft/review/published workflow, `AuthorizedAdminContentRepository`
and admin Firestore rules already existed. This work extended and re-shaped
that. Check what exists before building anything "new".

### Access

Parent login screen → **Admin login** link → `/admin/login`.

Demo mode credentials (seeded in `InMemoryAdminAuthRepository`, demo only):

```
admin@littlelearners.local / Admin@123
```

Firebase mode: set `parents/{uid}.role` to `admin` from a trusted console.

---

## 2. Key design decisions

**The admin session is genuinely separate.** UC-18 requires it. In Firebase mode
`FirebaseAdminAuthRepository` authenticates against a **secondary `FirebaseApp`**.
Using the default app would replace `FirebaseAuth.instance.currentUser` and leak
admin identity into the parent/child flow, making the separation cosmetic. Do
not "simplify" this back to the default app.

**Two authorization repositories now exist.** `AdminSessionAuthorizationRepository`
(admin session) gates admin work. `AuthAdminAuthorizationRepository` (parent
session) is retained for flows keyed off a parent with `role == admin`. Pick
deliberately.

**Firestore rules had to change.** Requirements 4 and 5 were *impossible* before:
parents could only read their own documents, so any system-wide count failed
with permission-denied. Admins now have read access to `parents`,
`childProfiles` and `levelProgress`, plus collection-group rules — those queries
are evaluated against wildcard matches, not the nested paths. Writes are
unchanged and stay parent-only.

**`moduleId` on `MediaAsset` is nullable.** The storage layer stays usable for
app-wide assets (splash art, Koala Guide audio). The "media belongs to a module"
rule is enforced in the admin upload path, which is where UC-19 scopes it.

---

## 3. Caveats — read before trusting this

### 3.1 The Firebase admin path has never executed

`FirebaseAdminAuthRepository` and `FirestoreAdminStatsRepository` are **written
but never run against a real Firebase project.** Every verification was done in
demo mode (`--dart-define=USE_FIREBASE=false`).

This is untested code. The secondary-`FirebaseApp` initialization and the
`count()` aggregation queries are the highest-risk parts. **Test these before
any demo or release.**

Why it could not be tested here: Firebase project `little-learner-9d2f1` has
only an Android app registered (no web app), and this machine has no Android
SDK. See §5.

### 3.2 A published module can still have no levels

The UC-19 rule "each module must have at least one level" is enforced in
`AdminContentViewModel.publishModule`, **not** in `createModule`.

`createModule(isPublished: true)` can therefore still create a published module
with zero levels. Guarding creation was tried and reverted — a module has no
levels at the moment it is created, so it blocked authoring a module and its
first level in one session, which the existing tests show is the intended flow.

To close it: validate existing published modules, or show a warning badge in
the module list. Not a silent bug — just incomplete.

### 3.3 Demo mode does not persist, and its two stores have different lifetimes

- Parent accounts live in `InMemoryAuthRepository` — **wiped on page reload**.
- Child profiles live in SQLite → IndexedDB on web — **persist across reloads**.

This produced a real confusion during development: the dashboard showed child
profiles from earlier sessions next to a parent count that had reset.
`LocalAdminStatsRepository` now filters out profiles whose parent no longer
exists, so both numbers measure the same thing.

For a genuinely clean slate: Chrome DevTools → Application → Storage → Clear
site data.

### 3.4 A behaviour change was made deliberately

The admin shortcut on the profile-selection screen was **removed**. It routed a
parent-session admin through the parental lock into the dashboard; under
separate sessions that dead-ends at "Access Denied".

**If the client expects an admin to reach the portal while signed in as a
parent, that conflicts with UC-18 and needs a decision.**

### 3.5 An earlier defect worth not repeating

The first version of `InMemoryAdminStatsRepository` returned **hardcoded demo
numbers** (3 parents / 6 children / 18 quizzes) that never changed regardless of
app activity. It looked like a real repository and cost debugging time — the
symptom was mistaken for a Firebase sync problem.

Replaced by `LocalAdminStatsRepository`, which computes from live DAOs.
`InMemoryAdminStatsRepository` still exists for tests. **Do not wire it into the
app.** If a metric cannot be computed, surface that rather than inventing a
number.

---

## 4. Already built but never called — do not rebuild

Found during a connection audit on 2026-08-05. All of this is complete, tested
code that the running app never reaches.

### 4.1 `BackendSyncCoordinator` is never invoked — highest priority

Constructed in `lib/app.dart` and registered as a Provider. **`syncNow()` is
called from nowhere.**

It is the connectivity-aware orchestrator with retry/backoff that implements
the client's stated key principle — *"online-first with offline learning… new
content is only updated when the internet is available."* **That principle is
therefore not implemented as designed.**

Sync does happen, but ad-hoc from viewmodels: profiles on
`ProfileViewModel.loadProfiles`, progress on level completion, content on admin
publish, leaderboard on load. No connectivity checks, no backoff, no
coordination.

This is the single highest-value gap in the app.

### 4.2 Three complete screens are unreachable

Routed in `app_router.dart`, never navigated to:

| Screen | Lines | Note |
|---|---|---|
| `LeaderboardPage` | 408 | A leaderboard tab is embedded in `profile_selection_page` instead |
| `LearnerDetailPage` | 186 | Only reachable from `LeaderboardPage`, so transitively dead |
| `ParentRemindersPage` | 325 | No entry point at all, despite a full viewmodel + Firestore repository |

### 4.3 Backends with no UI

- **`NotificationDeliveryRepository`** — nothing converts a due reminder into a
  delivery, so the notification half of reminders never runs.
- **`AdminKoalaGuideRepository`** — full CRUD, Firestore repo, sync service and
  authorization wrapper, but **no admin screen**. This is admin-domain work and
  the most obvious next piece of the panel.

---

## 5. Getting Firebase working

Required before the admin panel can be considered shippable (see §3.1).

1. Register a **web app** for `little-learner-9d2f1` in the Firebase console.
   *Requires the project owner's Google account — cannot be done from the code.*
2. `flutterfire configure` → generates `lib/firebase_options.dart`.
3. Pass `options: DefaultFirebaseOptions.currentPlatform` in
   `Firebase.initializeApp()` (`lib/main.dart`).
4. `firebase deploy --only firestore:rules` — **without this the parent-accounts
   and statistics screens return permission-denied.** Not a UI bug.
5. Drop `--dart-define=USE_FIREBASE=false`.

Also: `android/app/google-services.json` still uses the placeholder package
`com.example.little_learners`, which blocks any Play Store release.

---

## 6. Environment

Set up 2026-08-02 on Windows 11.

- Repo: `D:\Projects\lit-learners`
- Flutter SDK: `D:\dev\flutter` (3.44.8, Dart 3.12.2), on the user PATH.
  `pubspec.lock` pins **Flutter ≥3.38.4 / Dart ≥3.10.3**.
- Run in a browser:
  ```
  flutter run -d chrome --web-port 8080 --dart-define=USE_FIREBASE=false
  ```
- **No Android SDK installed** — `flutter build apk` will fail.
- On a fresh clone, regenerate the web SQLite worker:
  ```
  dart run sqflite_common_ffi_web:setup
  ```
  (`web/sqflite_sw.js` and `web/sqlite3.wasm` are committed so a clone runs
  without this; consider gitignoring them instead.)
- A white screen in the browser is usually a stale Flutter debug bootstrap, not
  a broken build. Hard-refresh (Ctrl+Shift+R) and use the Chrome window
  `flutter run` opened, not an old tab bound to a dead debug service.

**`file_picker` 11 removed `FilePicker.platform`** — `pickFiles` is now static.
Older tutorials will mislead you.

---

## 7. Verification status

| Check | Result |
|---|---|
| `flutter analyze` | No issues |
| `flutter test` | **147 passing** (was 121 before this work) |
| `flutter build web` | Succeeds |
| Runs in Chrome, demo mode | Verified, no runtime exceptions |
| Runs against Firebase | **Never attempted** — see §3.1 |
| Runs on Android/iOS | **Never attempted** — no SDK on this machine |

Intermediate commits are grouped as coherent thematic units for reviewability;
the **final branch state** is what was verified above.

---

## 8. Suggested next steps

1. **Wire `BackendSyncCoordinator`** (§4.1). Already built and tested;
   implements the principle the client called out as key.
2. **Register the Firebase web app** (§5) so a third of the admin panel stops
   being untested code.
3. **Add the Koala Guide admin screen** (§4.3) — backend complete, admin-domain.
4. Decide on the unreachable screens (§4.2): wire them up or delete them.

Deferred by the project owner, explicitly *not* now:

- High-quality charts/graphics for the statistics screen.
- Overall UI/UX enhancement pass.

Also outstanding from an earlier analysis, unrelated to the admin panel: the app
targets ages 1–4 but is almost entirely text-driven — `ContentItem` has **no
image field** (`visualLabel` is a string like `'Three apples'` rendered as
text), and **88 referenced audio cue keys have no audio files**. There is no
localization infrastructure despite a full Urdu module.
