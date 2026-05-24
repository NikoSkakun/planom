# Sync setup

Architecture lives in `lib/src/sync/`. Each backend is a concrete
`SyncProvider`; `SyncController` orchestrates push/pull/encryption regardless
of which provider is selected.

## iCloud (free, iOS / iPadOS / macOS only)

Fully automated through the existing TestFlight workflow — **no Xcode
required**.

### What's in the repo

| File | What it does |
|---|---|
| `lib/src/sync/icloud_sync_provider.dart` | Dart side of the push/pull/list calls |
| `lib/src/settings/sync_settings_view.dart` | Settings → Sync UI |
| `ios/Runner/Runner.entitlements` | iCloud Documents capability + container id |
| `ios/Runner/Info.plist` (`NSUbiquitousContainers`) | Container metadata for iOS |
| `ios/Runner.xcodeproj/project.pbxproj` | `CODE_SIGN_ENTITLEMENTS` wired into all three build configs |
| `fastlane/Fastfile` (`ensure_icloud_capability`) | Enables iCloud capability on the App ID via App Store Connect API on every build |
| `.github/workflows/testflight.yml` | Exposes `force_regen` input for the provisioning-profile regen |

### How the build flow works

1. On every build, Fastlane calls `ensure_icloud_capability` which checks
   the App ID `app.planom` via the App Store Connect API and enables the
   iCloud capability if it isn't already on. Idempotent.
2. If a capability was just added (or you triggered the workflow with
   `force_regen=true`), Fastlane calls `match` with `force: true` to
   regenerate the provisioning profile with the new entitlements. The new
   profile is committed back to the certificates repo for subsequent builds.
3. Otherwise `match` reuses the cached profile — no extra Apple round trip.
4. The build signs with the regenerated profile and produces an IPA that
   includes the iCloud Drive entitlement.

### What you need to do once

**No Xcode required.** Two browser-only steps, one CI trigger, total ~3 min.

**Step 1 — Create the iCloud Container in your browser (one-time):**

The App Store Connect REST API does not expose iCloud Container CRUD to
API-key authentication (verified against both `/v1/iCloudContainers` and
`/v1/cloudContainers` — Apple returns "resource does not exist" on both).
Container management is only available via the legacy Apple-ID Spaceship
path, which we deliberately avoid in CI. So this one step lives in the
web portal:

1. Open <https://developer.apple.com/account/resources/identifiers/list/cloudContainer>
2. Click **+** → register a new iCloud Container
   - **Description:** `Planom`
   - **Identifier:** `iCloud.app.planom`
3. Open <https://developer.apple.com/account/resources/identifiers/list>
4. Click **app.planom** → scroll to **iCloud** → click **Configure** (or **Edit**) →
   tick the `iCloud.app.planom` container → **Save**

If you skip Step 1, the first CI run will fail with a clear message and
the exact two URLs above — you can do it then.

**Step 2 — Trigger the first build with profile regen:**

Actions → TestFlight → **Run workflow** → tick **Force-regenerate the
provisioning profile** → Run. This bakes the iCloud entitlement +
container reference into the cached profile in your `ios-certificates`
repo. Subsequent pushes to `main` rebuild normally without the flag.

If `ensure_icloud_capability` fails with "Bundle ID not found", your ASC
API key needs both **App Manager** and **Developer** roles (Users → Keys
in App Store Connect). Read-only keys can't write capabilities.

### Container identifier

Container id is `iCloud.app.planom` (matches the bundle id, which is what
Apple recommends). Defined in four places that must stay in sync:

- `ios/Runner/Runner.entitlements` → `com.apple.developer.icloud-container-identifiers`
- `ios/Runner/Info.plist` → `NSUbiquitousContainers` key
- `lib/src/sync/icloud_sync_provider.dart` → `_defaultContainerId`
- Apple Developer Portal → CloudContainer record (the one you create in Step 1)

### What CI handles automatically

On every build, `ensure_icloud_capability` in `fastlane/Fastfile`:

1. Authenticates via ASC API key (no Apple ID needed)
2. Enables the iCloud capability on `app.planom` if not already enabled
3. *Tries* to create + link the iCloud container via the ASC REST API
   under both `/v1/iCloudContainers` and `/v1/cloudContainers`. If Apple
   accepts either (today they don't, but Apple may add this), CI is fully
   self-serve and Step 1 above becomes obsolete.
4. When any of the above flipped state, `match` runs with `force: true`
   to regenerate the provisioning profile.

### Testing on devices

iCloud only works on real devices (or simulators) signed into iCloud:

- Install the build from TestFlight.
- Settings → Sync → tap iCloud — connection should succeed with no
  passphrase prompt (E2E is opt-in; see below).
- Tap **Push now**. The encrypted snapshot lands in the Files app →
  iCloud Drive → Planom.
- Install on a second device with the same iCloud account, tap iCloud →
  **Pull from cloud**. Local data is replaced with the first device's
  snapshot.

### E2E encryption (opt-in)

By default, sync uploads plain JSON. Apple still encrypts it in transit
and at rest, but Apple holds the keys. Users can opt into client-side
end-to-end encryption from Settings → Sync → Encryption → **Set
passphrase**. After setting, the next push uploads the AES-GCM-256
envelope (PBKDF2-SHA256, 100k iterations) and other devices need the
same passphrase to pull.

Loss of passphrase = the cloud copy cannot be decrypted. No recovery
path. The UI surfaces this explicitly.

## Other backends (deferred)

- **Planom Account** — paid tier, will use Supabase or PocketBase. UI is
  scaffolded ("Coming soon"); plug in by implementing `SyncProvider` and
  wiring `SyncController._providerFor`.
- **Custom Server** — bring-your-own URL (PocketBase or WebDAV). Same
  contract as above; needs only a settings field for the URL.
