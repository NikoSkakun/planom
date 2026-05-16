# CI/CD — TestFlight Deployment

Automated iOS builds run on GitHub Actions and upload to TestFlight via Fastlane.  
Every push to `main` (or a manual trigger) produces a signed `.ipa` and submits it.

Certificates and provisioning profiles are managed **automatically** by Fastlane
using the App Store Connect API key — no private certificates repository, no local
Mac bootstrapping, and no `fastlane match` required.

---

## Table of contents

1. [Prerequisites](#1-prerequisites)
2. [Generate the App Store Connect API Key](#2-generate-the-app-store-connect-api-key)
3. [Encode the .p8 key for GitHub Secrets](#3-encode-the-p8-key-for-github-secrets)
4. [Add secrets to GitHub](#4-add-secrets-to-github)
5. [Fill in the placeholders](#5-fill-in-the-placeholders)
6. [Trigger the first build](#6-trigger-the-first-build)
7. [Secret reference](#7-secret-reference)

---

## 1. Prerequisites

| Tool | Install |
|------|---------|
| Xcode (latest stable) | Mac App Store |
| Ruby ≥ 3.2 | Comes with macOS; or `brew install ruby` |
| Bundler | `gem install bundler` |
| Flutter | https://docs.flutter.dev/get-started/install |

From the repo root, install Fastlane and its dependencies:

```bash
bundle install
```

You do **not** need CocoaPods installed locally — the CI runner installs it automatically.

---

## 2. Generate the App Store Connect API Key

1. Open **App Store Connect → Users and Access → Integrations → App Store Connect API**  
   Direct URL: https://appstoreconnect.apple.com/access/integrations/api

2. Click **"+"** to generate a new key.

3. Give it a name (e.g. `GitHub Actions`) and set the role to **App Manager**.

4. Download the `.p8` file **immediately** — Apple only shows it once.

5. Note down:
   - **Key ID** — 10-character string shown in the table (e.g. `ABC1234DEF`)
   - **Issuer ID** — UUID at the top of the page, shared across all your keys

The API key gives Fastlane permission to create and download distribution certificates
and provisioning profiles on every CI run, so no pre-generated credentials need to be
stored anywhere.

---

## 3. Encode the .p8 key for GitHub Secrets

GitHub Secrets can't store binary files or multi-line values reliably,
so the `.p8` content is stored as a single line with literal `\n` sequences.

```bash
# macOS
cat AuthKey_YOURKEYID.p8 | awk 'NF {printf "%s\\n", $0}' | pbcopy
```

The clipboard now contains a single line like:  
`-----BEGIN PRIVATE KEY-----\nMIGTA...\n-----END PRIVATE KEY-----`

Paste that as the value of `APP_STORE_CONNECT_API_KEY_CONTENT`.

---

## 4. Add secrets to GitHub

1. Go to your repository on GitHub.
2. Navigate to **Settings → Secrets and variables → Actions**.
3. Click **"New repository secret"** for each entry below.

| Secret name | Where to get the value |
|-------------|------------------------|
| `APP_STORE_CONNECT_API_KEY_ID` | Key ID from App Store Connect (step 2) |
| `APP_STORE_CONNECT_API_KEY_ISSUER_ID` | Issuer ID from App Store Connect (step 2) |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | Encoded `.p8` content from step 3 |

That's it — only three secrets needed.

---

## 5. Fill in the placeholders

Search for `YOUR_` across the project and replace:

| File | Placeholder | Replace with |
|------|-------------|--------------|
| `fastlane/Appfile` | `YOUR_BUNDLE_ID` | Your app's bundle identifier, e.g. `com.yourcompany.planom` |
| `fastlane/Appfile` | `YOUR_APPLE_ID` | Your Apple ID email |
| `fastlane/Appfile` | `YOUR_ITC_TEAM_ID` | App Store Connect team ID (numeric) |
| `fastlane/Appfile` | `YOUR_DEV_TEAM_ID` | Developer Portal team ID (10-char, find in Xcode → Signing & Capabilities) |
| `fastlane/Fastfile` | `YOUR_BUNDLE_ID` | Same bundle identifier (appears in the `sigh` call and `export_options`) |
| `.github/workflows/testflight.yml` | `FLUTTER_VERSION` | Your Flutter version (run `flutter --version` to check) |

---

## 6. Trigger the first build

### Automatic

Push any commit to `main`:

```bash
git push origin main
```

### Manual

1. Go to the **Actions** tab in your GitHub repository.
2. Select the **"TestFlight"** workflow in the left sidebar.
3. Click **"Run workflow"** → choose branch `main` → click the green **"Run workflow"** button.

The full pipeline takes roughly 15–20 minutes on a cold cache,
~8–10 minutes once gem and pub caches are warm.

After a successful run, the build appears in App Store Connect under
**TestFlight → Builds** within a few minutes (Apple's processing takes 5–15 min).

---

## 7. Secret reference

See `.env.example` in the repository root for a full list with descriptions.

```
APP_STORE_CONNECT_API_KEY_ID
APP_STORE_CONNECT_API_KEY_ISSUER_ID
APP_STORE_CONNECT_API_KEY_CONTENT
```

---

## Troubleshooting

**`No profiles for 'com.yourcompany.planom' were found`**  
→ Make sure `YOUR_BUNDLE_ID` in `fastlane/Fastfile` matches the bundle ID registered
  in App Store Connect and in Xcode's Signing & Capabilities tab.

**`The provided API key does not have permission`**  
→ The API key role must be **App Manager** or **Admin**. Regenerate the key with the
  correct role if needed.

**`flutter: command not found` in CI**  
→ Make sure `FLUTTER_VERSION` in the workflow matches an actual Flutter release tag.  
   Check available tags at https://docs.flutter.dev/release/archive

**Build number conflict on TestFlight**  
→ The pipeline stamps the build number with a timestamp (`YYYYMMDDHHmmSS`),
  so conflicts should not occur. If they do, check that no other pipeline is running
  concurrently (the `concurrency` key in the workflow should prevent this).
