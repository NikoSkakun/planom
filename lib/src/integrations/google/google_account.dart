/// A connected Google account. Planom can hold any number of these at once.
///
/// The account's refresh token is **not** stored here — it lives in
/// `flutter_secure_storage` keyed by [id]. This object only carries the
/// display identity and the chosen integration mode.
class GoogleAccount {
  const GoogleAccount({
    required this.id,
    required this.email,
    required this.readOnly,
  });

  /// Stable account identity. We use the primary calendar id, which is the
  /// account's email address.
  final String id;

  final String email;

  /// True when the account was connected in read-only mode (Planom requested
  /// only the `calendar.readonly` scope). Every calendar on a read-only
  /// account surfaces as non-editable, regardless of access role.
  final bool readOnly;

  GoogleAccount copyWith({String? email, bool? readOnly}) => GoogleAccount(
        id: id,
        email: email ?? this.email,
        readOnly: readOnly ?? this.readOnly,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'readOnly': readOnly,
      };

  static GoogleAccount fromJson(Map<String, dynamic> m) => GoogleAccount(
        id: m['id'] as String,
        email: (m['email'] as String?) ?? (m['id'] as String),
        readOnly: (m['readOnly'] as bool?) ?? false,
      );
}
