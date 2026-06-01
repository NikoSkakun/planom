import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../notes/markdown_view.dart';
import '../utils/fast_route.dart';
import 'legal_content.dart';
import 'settings_widgets.dart';

/// Settings → About hub: app version plus links to the bundled, offline
/// Privacy Policy and Terms of Service documents.
class AboutLegalView extends StatelessWidget {
  const AboutLegalView({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.sectionAbout),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            SettingsSectionHeader(s.sectionAbout),
            _InfoRow(label: s.version, value: kAppVersionName),
            const SizedBox(height: 18),
            SettingsSectionHeader(s.legal),
            SettingsNavRow(
              label: s.privacyPolicy,
              onTap: () => Navigator.of(context).push(
                FastRoute<void>(
                  builder: (_) => LegalDocumentView(
                    title: s.privacyPolicy,
                    markdown: kPrivacyPolicyMarkdown,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 1),
            SettingsNavRow(
              label: s.termsOfService,
              onTap: () => Navigator.of(context).push(
                FastRoute<void>(
                  builder: (_) => LegalDocumentView(
                    title: s.termsOfService,
                    markdown: kTermsOfServiceMarkdown,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen reader for a bundled legal document rendered from markdown.
class LegalDocumentView extends StatelessWidget {
  const LegalDocumentView({
    super.key,
    required this.title,
    required this.markdown,
  });

  final String title;
  final String markdown;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(title),
      ),
      child: SafeArea(
        // MarkdownView (non-shrinkWrap) supplies its own scroll view; the
        // read-only `onTap` is a no-op since there is nothing to edit.
        child: MarkdownView(
          data: markdown,
          onTap: (_) {},
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        ),
      ),
    );
  }
}

/// Non-tappable row showing a label and a trailing value (e.g. version).
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiarySystemBackground,
      context,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 17,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}
