# Sync setup

Architecture lives in `lib/src/sync/`. Each backend is a concrete
`SyncProvider` implementation; the `SyncController` orchestrates
encryption, push, and pull regardless of which provider is selected.

## iCloud (free, iOS / iPadOS / macOS only)

The Dart side is fully implemented (`ICloudSyncProvider`) and wired into
Settings → Sync. To make it work on a real device, one-time Xcode steps
are required — Flutter cannot configure entitlements.

### One-time Xcode setup

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select the **Runner** target → **Signing & Capabilities**.
3. Click **+ Capability** → add **iCloud**.
4. Under iCloud, tick **iCloud Documents**.
5. Click **+** under Containers, choose **Specify custom containers**, and
   create one named `iCloud.com.planom.app`
   (must match `_defaultContainerId` in `icloud_sync_provider.dart`; change
   one or the other if you want a different id).
6. Verify Xcode added a `Runner/Runner.entitlements` file with:
   ```xml
   <key>com.apple.developer.icloud-container-identifiers</key>
   <array>
       <string>iCloud.com.planom.app</string>
   </array>
   <key>com.apple.developer.icloud-services</key>
   <array>
       <string>CloudDocuments</string>
   </array>
   ```
7. Check that `ios/Runner/Info.plist` still has the `NSUbiquitousContainers`
   block (already committed). The container id inside must match step 5.
8. Make sure your Apple Developer account has iCloud enabled for the App ID.

### Testing

- iCloud only works on real devices or simulators signed into an iCloud
  account. Signed-out simulators throw `iCloudConnectionOrPermission`.
- After enabling Sync → iCloud in Settings, the app pushes the encrypted
  snapshot to the container. Verify it appears in **Files app → iCloud
  Drive → Planom** on the device.
- On a second device signed into the same iCloud account, install the
  build, enable Sync → iCloud, enter the same passphrase, then **Pull
  from cloud**. The local data should be replaced with the first device's
  snapshot.

### Threat model

- The cloud copy is encrypted with AES-GCM-256 under a key derived
  (PBKDF2-SHA256, 100k iterations) from the user's passphrase before it
  leaves the device. Apple holds bytes only; without the passphrase they
  cannot read the contents.
- The passphrase lives in flutter_secure_storage (iOS Keychain), not in
  the SQLite database or backups. Losing it means losing the ability to
  decrypt the cloud copy — there is no recovery path. This trade-off is
  intentional and matches Obsidian Sync / Standard Notes.

## Other backends (deferred)

- **Planom Account** — paid tier, will use Supabase or PocketBase. UI is
  scaffolded ("Coming soon"); plug in the provider by implementing
  `SyncProvider` and wiring `SyncController._providerFor`.
- **Custom Server** — bring-your-own URL (PocketBase or WebDAV). Same
  contract as above; needs only a settings field for the URL.
