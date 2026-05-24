import 'sync_state.dart';

/// Backend-agnostic contract for a single sync target. The controller doesn't
/// care whether the bytes end up in iCloud Drive, a PocketBase instance, or
/// the user's own S3 bucket — only that push/pull/check work.
///
/// All `Future`s should resolve quickly (push/pull may take seconds; that's
/// fine). Throw a [SyncException] on user-actionable failures (network,
/// auth, missing config); throw normally on programming errors.
abstract class SyncProvider {
  /// Stable identifier matching [SyncBackend].
  SyncBackend get backend;

  /// `true` when this provider can be used on the current platform / build.
  /// iCloud returns false on Android/Linux/Windows, etc.
  Future<bool> isAvailable();

  /// `true` once the provider has whatever configuration it needs (account,
  /// container id, URL, passphrase). The UI uses this to decide whether to
  /// surface a "Set up" CTA vs the regular Sync Now button.
  Future<bool> isConfigured();

  /// Uploads [encryptedPayload] (already E2E-encrypted by the controller) to
  /// the backend's well-known location for this app, overwriting whatever
  /// was there before.
  Future<void> push(List<int> encryptedPayload);

  /// Fetches the latest payload from the backend. Returns `null` if there's
  /// nothing there yet (fresh install on a new device that hasn't pushed).
  Future<List<int>?> pull();

  /// Returns the modification time of the most recent remote payload, or
  /// null if absent. Lets the UI show "Last sync: 2m ago" without doing a
  /// full pull.
  Future<DateTime?> lastRemoteUpdate();

  /// Removes the remote payload. Used when the user disables sync.
  Future<void> wipeRemote();
}

/// Thrown by providers for user-actionable failures. Message is shown
/// verbatim in the UI banner.
class SyncException implements Exception {
  SyncException(this.message);
  final String message;

  @override
  String toString() => 'SyncException: $message';
}
