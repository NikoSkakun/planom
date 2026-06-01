/// Bundled, offline legal documents shown in Settings → About.
///
/// These are the canonical English texts. They are intentionally kept out of
/// the localization tables in `strings.dart`: legal copy should not be
/// machine-translated, and the UI chrome around them (row labels, titles) is
/// localized instead. If you localize these documents later, swap the getters
/// here for a locale-aware lookup.
///
/// **Keep in sync** with the hosted versions you submit to the App Store /
/// Play Console and the `lastUpdated` date below when the text changes.
library;

/// Human-readable app version shown in the About screen. Mirror `pubspec.yaml`
/// (`version:` → `<name>+<build>`). Kept as a constant so the About screen has
/// no runtime/plugin dependency (no `package_info_plus`).
const String kAppVersionName = '1.0.0';

/// Effective date for both documents below. Update when the copy changes.
const String kLegalLastUpdated = 'June 1, 2026';

/// Contact address for privacy / legal enquiries.
const String kLegalContactEmail = 'coloristique@gmail.com';

const String kPrivacyPolicyMarkdown = '''
# Privacy Policy

**Last updated: $kLegalLastUpdated**

Planom ("the app", "we", "us") is a personal task, note, calendar, and habit
manager. This policy explains what data the app handles and how. The short
version: **Planom is local-first. Your content stays on your device unless you
explicitly turn on a sync or integration feature.**

## Data you create

Tasks, notes, calendar events, routines, contacts (birthdays), lists, folders,
tags, and attached photo icons are stored **locally on your device** in a
private database. We do not operate a server that receives this content, and we
do not sell, rent, or share it.

## What we do not collect

- We do **not** include analytics, advertising, or third-party tracking SDKs.
- We do **not** collect usage statistics, device identifiers, or your location.
- We do **not** create an account or require you to sign in to use the app.

## App lock (PIN / password / biometrics)

If you enable the app lock, your PIN or password is **never stored in plain
text**. Only a salted, key-stretched cryptographic hash is kept on the device,
and it is excluded from backups. Biometric verification (Face ID, Touch ID,
Windows Hello) is performed by your operating system; Planom never receives your
biometric data.

## iCloud sync (optional, off by default)

If you turn on iCloud sync, an encrypted or plain backup of the active space is
written to **your own iCloud Drive container**. This data is handled by Apple
under Apple's terms and privacy policy. You can additionally set a passphrase to
end-to-end encrypt the backup with AES-256-GCM, in which case the passphrase is
stored only in your device's secure storage (Keychain / Keystore) and is never
uploaded. Planom has no access to your iCloud data.

## Google Calendar (optional, off by default)

If you connect a Google account, Planom requests calendar access so it can show
your Google events alongside Planom events and, for calendars you can write to,
create or edit events you make in the app. Google Calendar data is fetched
directly from Google to your device and cached locally for offline display. It
is **not** sent to any Planom server. Our use of information received from
Google APIs adheres to the
[Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy),
including the Limited Use requirements. You can disconnect at any time in
Settings → Google Calendar, which removes the stored tokens and cached events
from your device.

## Notifications

Local reminders are scheduled on-device by your operating system. No reminder
content leaves your device to deliver a notification.

## Backups and exports

When you export a backup, Planom creates a `.planom` file containing your data
(optionally encrypted with your passphrase). Once you share or save that file,
how it is stored and who can access it is up to you.

## Children

Planom is not directed at children under 13, and we do not knowingly collect
personal information from them.

## Changes to this policy

We may update this policy as the app evolves. Material changes will be reflected
here with a new "Last updated" date.

## Contact

Questions about privacy? Email **$kLegalContactEmail**.
''';

const String kTermsOfServiceMarkdown = '''
# Terms of Service

**Last updated: $kLegalLastUpdated**

Please read these terms before using Planom ("the app"). By installing or using
the app, you agree to them.

## License

You are granted a personal, non-exclusive, non-transferable, revocable license
to use Planom on devices you own or control, for your personal or internal
purposes, subject to these terms and the rules of the app store you obtained it
from.

## Your content and your responsibility

You retain all rights to the content you create in Planom. Because your data is
stored locally, **you are responsible for it** — including keeping backups.
Uninstalling the app, resetting data, or losing/replacing your device can
permanently delete your content. Use the export and sync features if you want
redundancy.

## Third-party services

Optional features connect to third-party services (for example Apple iCloud and
Google Calendar). Your use of those services is governed by their own terms and
privacy policies, and they are provided by their respective owners, not by us.

## Acceptable use

You agree not to use the app to break the law, to infringe others' rights, or to
attempt to disrupt, reverse-engineer for malicious purposes, or compromise the
security of the app or any connected service, except where such restriction is
prohibited by applicable law.

## No warranty

The app is provided **"as is" and "as available," without warranties of any
kind**, whether express or implied, including fitness for a particular purpose,
merchantability, and non-infringement. We do not warrant that the app will be
uninterrupted, error-free, or that data will never be lost.

## Limitation of liability

To the maximum extent permitted by law, we will not be liable for any indirect,
incidental, special, consequential, or punitive damages, or for any loss of data
or profits, arising out of or related to your use of (or inability to use) the
app.

## Changes

We may update the app and these terms over time. Continued use after changes
take effect constitutes acceptance of the revised terms.

## Contact

Questions about these terms? Email **$kLegalContactEmail**.
''';
