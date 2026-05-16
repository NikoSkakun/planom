# CI/CD — TestFlight Deployment

Automated iOS builds run on GitHub Actions and upload to TestFlight via Fastlane.  
Every push to `main` (or a manual trigger) produces a signed `.ipa` and submits it.

---

## Table of contents

1. [Prerequisites](#1-prerequisites)
2. [Generate the App Store Connect API Key](#2-generate-the-app-store-connect-api-key)
3. [Bootstrap certificates with Fastlane Match](#3-bootstrap-certificates-with-fastlane-match)
4. [Encode the .p8 key for GitHub Secrets](#4-encode-the-p8-key-for-github-secrets)
5. [Add secrets to GitHub](#5-add-secrets-to-github)
6. [Fill in the placeholders](#6-fill-in-the-placeholders)
7. [Trigger the first build](#7-trigger-the-first-build)
8. [Secret reference](#8-secret-reference)

---

## 1. Prerequisites

| Tool | Install |
|------|---------|
| Xcode (latest stable) | Mac App Store |
| Xcode Command Line Tools | `xcode-select --install` |
| Ruby ≥ 3.2 | Comes with macOS; or `brew install ruby` |
| Bundler | `gem install bundler` |
| CocoaPods | `gem install cocoapods` |
| Flutter | https://docs.flutter.dev/get-started/install |

From the repo root, install Fastlane and its dependencies:

```bash
bundle install
```

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

---

## 3. Bootstrap certificates with Fastlane Match

Match stores encrypted certificates in a private Git repository.  
You only need to do this once from your Mac.

### 3a. Create a private certificates repo

Create an **empty private repository** on GitHub (or any Git host), e.g.  
`https://github.com/YOUR_ORG/ios-certificates.git`

### 3b. Initialise Match

```bash
bundle exec fastlane match init
```

When prompted, choose **git** storage and enter your certificates repo URL.  
This writes `fastlane/Matchfile` (already scaffolded for you).

### 3c. Generate and upload App Store certs

```bash
bundle exec fastlane match appstore
```

Match will:
- Create an App Store distribution certificate (if you don't have one)
- Create an App Store provisioning profile for your bundle ID
- Encrypt both and push them to your certificates repo

Choose a strong **MATCH_PASSWORD** when prompted — you'll need it as a GitHub Secret.

### 3d. Verify locally

```bash
bundle exec fastlane match appstore --readonly
```

Should complete without errors.

---

## 4. Encode the .p8 key for GitHub Secrets

GitHub Secrets can't store binary files or multi-line values reliably,  
so the `.p8` content is stored as a single line with literal `\n` sequences.

```bash
# macOS
cat AuthKey_YOURKEYID.p8 | awk 'NF {printf "%s\\n", $0}' | pbcopy
```

The clipboard now contains a single line like:  
`-----BEGIN PRIVATE KEY-----\nMIGTA...\n-----END PRIVATE KEY-----`

Paste that as the value of `APP_STORE_CONNECT_API_KEY_CONTENT`.

### Generate MATCH_GIT_BASIC_AUTHORIZATION

```bash
echo -n "your_github_username:ghp_yourPersonalAccessToken" | base64 | pbcopy
```

The GitHub Personal Access Token needs **repo** (read) scope on the certificates repo.  
Create one at: https://github.com/settings/tokens

---

## 5. Add secrets to GitHub

1. Go to your repository on GitHub.
2. Navigate to **Settings → Secrets and variables → Actions**.
3. Click **"New repository secret"** for each entry below.

| Secret name | Where to get the value |
|-------------|------------------------|
| `APP_STORE_CONNECT_API_KEY_ID` | Key ID from App Store Connect (step 2) |
| `APP_STORE_CONNECT_API_KEY_ISSUER_ID` | Issuer ID from App Store Connect (step 2) |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | Encoded `.p8` content from step 4 |
| `MATCH_PASSWORD` | Password you chose when running `match init` |
| `MATCH_GIT_URL` | HTTPS URL of your certificates repo |
| `MATCH_GIT_BASIC_AUTHORIZATION` | Base64 `username:token` from step 4 |

---

## 6. Fill in the placeholders

Search for `YOUR_` across the project and replace:

| File | Placeholder | Replace with |
|------|-------------|--------------|
| `fastlane/Appfile` | `YOUR_BUNDLE_ID` | Your app's bundle identifier, e.g. `com.yourcompany.planom` |
| `fastlane/Appfile` | `YOUR_APPLE_ID` | Your Apple ID email |
| `fastlane/Appfile` | `YOUR_ITC_TEAM_ID` | App Store Connect team ID (numeric, find in Appfile after first `fastlane` run) |
| `fastlane/Appfile` | `YOUR_DEV_TEAM_ID` | Developer Portal team ID (10-char, find in Xcode → Signing & Capabilities) |
| `fastlane/Matchfile` | `YOUR_BUNDLE_ID` | Same bundle identifier |
| `fastlane/Matchfile` | `YOUR_APPLE_ID` | Same Apple ID |
| `fastlane/Fastfile` | `YOUR_BUNDLE_ID` | Same bundle identifier (appears in `export_options`) |
| `.github/workflows/testflight.yml` | `FLUTTER_VERSION` | Your Flutter version (run `flutter --version` to check) |

---

## 7. Trigger the first build

### Automatic

Push any commit to `main`:

```bash
git push origin main
```

### Manual

1. Go to **Actions** tab in your GitHub repository.
2. Select the **"TestFlight"** workflow in the left sidebar.
3. Click **"Run workflow"** → choose branch `main` → click the green **"Run workflow"** button.

Watch the run — the full pipeline takes roughly 15–20 minutes on a cold cache,  
~8–10 minutes once gem and pub caches are warm.

After a successful run, the build appears in App Store Connect under  
**TestFlight → Builds** within a few minutes (processing takes 5–15 min on Apple's side).

---

## 8. Secret reference

See `.env.example` in the repository root for a full list with descriptions.

```
APP_STORE_CONNECT_API_KEY_ID
APP_STORE_CONNECT_API_KEY_ISSUER_ID
APP_STORE_CONNECT_API_KEY_CONTENT
MATCH_PASSWORD
MATCH_GIT_URL
MATCH_GIT_BASIC_AUTHORIZATION
```

---

## Troubleshooting

**`No profiles for 'com.yourcompany.planom' were found`**  
→ Run `bundle exec fastlane match appstore` locally, then re-push.

**`Invalid curve name` or certificate errors**  
→ Your MATCH_PASSWORD is wrong, or the certificates repo URL is incorrect.

**`flutter: command not found` in CI**  
→ Make sure `FLUTTER_VERSION` in the workflow matches an actual Flutter release tag.  
   Check available tags at https://docs.flutter.dev/release/archive

**Build number conflict on TestFlight**  
→ The pipeline stamps the build number with a timestamp (`YYYYMMDDHHmmSS`),  
   so conflicts should not occur. If they do, check that no other pipeline is running concurrently.
