# CI/CD — Android Tester Distribution

Automated Android builds run on GitHub Actions and distribute a **signed APK** to
testers via **Firebase App Distribution** using Fastlane.

The workflow is **manual** (`workflow_dispatch`) — App Distribution emails/notifies
testers on every release, so builds are triggered on demand rather than on every
push. (Contrast with the iOS `TestFlight` workflow, which runs on every push to `main`.)

This mirrors the iOS pipeline (`README_CICD.md`): secrets live in GitHub, binary
material is base64-encoded, and Fastlane does the upload.

---

## Table of contents

1. [Prerequisites](#1-prerequisites)
2. [Generate the upload keystore](#2-generate-the-upload-keystore)
3. [Create the Firebase project & Android app](#3-create-the-firebase-project--android-app)
4. [Create a Google Cloud service account](#4-create-a-google-cloud-service-account)
5. [Encode the keystore & service account for secrets](#5-encode-the-keystore--service-account-for-secrets)
6. [Add secrets to GitHub](#6-add-secrets-to-github)
7. [Create tester groups & invite testers](#7-create-tester-groups--invite-testers)
8. [Trigger a build](#8-trigger-a-build)
9. [Verify](#9-verify)
10. [Secret reference](#10-secret-reference)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Prerequisites

| Tool | Install |
|------|---------|
| JDK 17 (Temurin) | https://adoptium.net (CI uses Temurin 17) |
| Flutter | https://docs.flutter.dev/get-started/install |
| Ruby ≥ 3.2 | `brew install ruby` / system Ruby |
| Bundler | `gem install bundler` |
| Firebase project access | https://console.firebase.google.com |

From the repo root, install Fastlane + the Firebase App Distribution plugin:

```bash
bundle install
```

The plugin is declared in `fastlane/Pluginfile` and loaded via the `Gemfile`, so
`bundle install` records it in `Gemfile.lock`.

> **App identifier:** the Android `applicationId` is **`app.planom`** (in
> `android/app/build.gradle`), matching the iOS bundle id. The Firebase Android app
> **must** be registered with this exact package name.

---

## 2. Generate the upload keystore

Create a release keystore (do this **once** and keep it safe — losing it means you
can't ship updates that overwrite an installed build):

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

You'll be prompted for a store password, a key password, and a distinguished name.
Note the **alias** (`upload`), the **store password**, and the **key password**.

The keystore (`*.jks`) and `key.properties` are already gitignored
(`android/.gitignore`) — never commit them.

### Local release builds (optional)

To build a signed APK on your machine, copy `upload-keystore.jks` into `android/`
and create `android/key.properties`:

```properties
storeFile=upload-keystore.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=upload
keyPassword=YOUR_KEY_PASSWORD
```

Then `flutter build apk --release`. Without `key.properties`, release builds fall
back to debug signing so `flutter run --release` still works.

---

## 3. Create the Firebase project & Android app

1. https://console.firebase.google.com → **Add project** (or pick an existing one).
2. In the project, **Add app → Android**.
3. Set the **Android package name** to **`app.planom`** (must match `applicationId`).
4. You can skip downloading `google-services.json` — App Distribution does **not**
   require it (it's only needed when integrating Firebase SDKs into the app).
5. Open **Project settings → General → Your apps** and copy the **App ID**, of the
   form `1:1234567890:android:abcdef0123456789`. This is your `FIREBASE_APP_ID`.

---

## 4. Create a Google Cloud service account

Fastlane authenticates with a service-account JSON key (the modern,
non-interactive approach).

1. https://console.cloud.google.com → select the **same project** as Firebase.
2. **IAM & Admin → Service Accounts → Create service account**
   (e.g. name `github-app-distribution`).
3. Grant the role **Firebase App Distribution Admin**
   (`roles/firebaseappdistro.admin`).
4. Open the service account → **Keys → Add key → Create new key → JSON** → download.
5. If uploads fail with a "not enabled" error, enable the API:
   **APIs & Services → Enable APIs** → *Firebase App Distribution API*
   (`firebaseappdistribution.googleapis.com`).

---

## 5. Encode the keystore & service account for secrets

GitHub secrets store text, so base64-encode the two binary/JSON files:

```bash
# macOS
base64 -i upload-keystore.jks | pbcopy            # → ANDROID_KEYSTORE_BASE64
base64 -i service-account.json | pbcopy           # → FIREBASE_SERVICE_ACCOUNT

# Linux
base64 -w0 upload-keystore.jks                    # → ANDROID_KEYSTORE_BASE64
base64 -w0 service-account.json                   # → FIREBASE_SERVICE_ACCOUNT
```

---

## 6. Add secrets to GitHub

Repository → **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Value |
|--------|-------|
| `ANDROID_KEYSTORE_BASE64` | base64 of `upload-keystore.jks` (step 5) |
| `ANDROID_KEYSTORE_PASSWORD` | keystore store password (step 2) |
| `ANDROID_KEY_ALIAS` | key alias, e.g. `upload` |
| `ANDROID_KEY_PASSWORD` | key password (step 2) |
| `FIREBASE_APP_ID` | Firebase Android App ID (step 3) |
| `FIREBASE_SERVICE_ACCOUNT` | base64 of the service-account JSON (step 5) |
| `FIREBASE_TESTER_GROUPS` | comma-separated tester group aliases, e.g. `dev,qa` |

---

## 7. Create tester groups & invite testers

1. Firebase console → **App Distribution → Testers & Groups**.
2. Create a group; note its **alias** (must match `FIREBASE_TESTER_GROUPS`).
3. Add tester email addresses to the group.

Testers receive an invite email and install builds via the **Firebase App Tester**
app (or the web link). Every distributed release notifies the targeted groups.

---

## 8. Trigger a build

1. Repo → **Actions** tab → **Android Distribution** workflow.
2. **Run workflow** → choose the branch → **Run workflow**.

The pipeline: sets up Flutter + Java, decodes the keystore + service account,
builds a signed release APK (`versionCode` stamped from a timestamp), and runs the
Fastlane `android_beta` lane to upload to Firebase App Distribution.

---

## 9. Verify

**Locally** (optional):

```bash
# With android/upload-keystore.jks + android/key.properties in place:
flutter build apk --release

# Confirm it's signed with the upload key (not the debug key):
$ANDROID_HOME/build-tools/<version>/apksigner verify --print-certs \
  build/app/outputs/flutter-apk/app-release.apk

# Distribute from your machine:
export FIREBASE_APP_ID="1:...:android:..."
export FIREBASE_SERVICE_ACCOUNT_FILE="$PWD/service-account.json"
export FIREBASE_TESTER_GROUPS="dev"
bundle exec fastlane android android_beta
```

**In CI:** watch the **Build release APK** and **Run Fastlane android_beta lane**
steps pass. The `android-release-apk` artifact is attached to the run.

**Testers:** Firebase console → **App Distribution → Releases** shows the new
release with its version/build number and targeted groups; testers in the group
receive the invite/update notification.

---

## 10. Secret reference

```
ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
FIREBASE_APP_ID
FIREBASE_SERVICE_ACCOUNT
FIREBASE_TESTER_GROUPS
```

---

## 11. Troubleshooting

**`APK not found at build/app/outputs/flutter-apk/app-release.apk`**
→ The Flutter build step failed or was skipped. Check the **Build release APK** logs.

**Upload fails: permission / API not enabled**
→ Ensure the service account has **Firebase App Distribution Admin** and the
   *Firebase App Distribution API* is enabled in the GCP project (step 4).

**`Default FirebaseApp is not initialized` / wrong app**
→ `FIREBASE_APP_ID` must be the Android App ID (`1:...:android:...`), and the
   registered package must equal `applicationId` (`app.planom`).

**Testers don't get the build**
→ Confirm the group alias in `FIREBASE_TESTER_GROUPS` matches a group in
   App Distribution and that testers were added to it.

**`buildNumber: … is greater than the maximum allowed value of 2100000000`**
→ Flutter caps `versionCode` at 2,100,000,000. The workflows stamp it with
   minutes-since-epoch (`$(($(date +%s) / 60))` ≈ 29.6M today), which is monotonic
   and stays well under the cap. Don't switch to a `yymmddHHMM`-style timestamp — it
   overflows.
