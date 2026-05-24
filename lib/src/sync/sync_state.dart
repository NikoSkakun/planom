// Sync subsystem types — kept in one file so the rest of the codebase can
// reason about sync without pulling in any backend-specific imports.

/// Which backend a user has selected. Each value maps to a concrete
/// [SyncProvider] implementation in `lib/src/sync/`.
enum SyncBackend {
  /// Disabled — no remote copy, nothing leaves the device.
  none,

  /// Apple iCloud Drive. Free for users on their existing iCloud quota.
  /// iOS / iPadOS / macOS only.
  icloud,

  /// Planom-hosted (Supabase or PocketBase, decided later). Paid tier.
  /// Cross-platform.
  planom,

  /// Bring-your-own server (custom URL speaking PocketBase / WebDAV / S3).
  /// Free; user manages hosting.
  custom,
}

extension SyncBackendX on SyncBackend {
  String get id => name;

  static SyncBackend fromId(String? id) {
    return SyncBackend.values.firstWhere(
      (e) => e.id == id,
      orElse: () => SyncBackend.none,
    );
  }
}

/// Coarse-grained lifecycle of an in-flight sync operation. The UI maps this
/// to icons / progress / error banners.
enum SyncStatus {
  idle,
  pushing,
  pulling,
  succeeded,
  failed,
  notConfigured,
  passphraseRequired,
  notAvailable,
}

/// Compact snapshot exposed by [SyncController] for the UI to bind to.
class SyncSnapshot {
  const SyncSnapshot({
    required this.backend,
    required this.status,
    this.lastSyncAt,
    this.lastError,
  });

  final SyncBackend backend;
  final SyncStatus status;
  final DateTime? lastSyncAt;
  final String? lastError;

  SyncSnapshot copyWith({
    SyncBackend? backend,
    SyncStatus? status,
    DateTime? lastSyncAt,
    String? lastError,
    bool clearError = false,
  }) =>
      SyncSnapshot(
        backend: backend ?? this.backend,
        status: status ?? this.status,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        lastError: clearError ? null : (lastError ?? this.lastError),
      );

  static const initial = SyncSnapshot(
    backend: SyncBackend.none,
    status: SyncStatus.idle,
  );
}
