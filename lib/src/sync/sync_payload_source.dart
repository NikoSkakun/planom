/// The slice of [BackupService] that [SyncController] needs: produce the
/// current space's payload and apply a pulled one. Kept as an interface so the
/// controller's orchestration (encryption detection, passphrase routing) can be
/// tested without constructing the full backup/controller graph.
abstract interface class SyncPayloadSource {
  /// Builds the active space's backup payload as a plain JSON string.
  Future<String> buildPayloadJson();

  /// Applies a pulled plain JSON payload, replacing local data. Returns
  /// `true` when the payload was accepted and applied.
  Future<bool> importPayloadJson(String plainJson);
}
