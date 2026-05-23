#!/bin/bash
set -euo pipefail

# Installs the Flutter SDK so `flutter analyze` / `flutter test` work in
# Claude Code on the web sessions. Idempotent and non-interactive.
# Runs only in remote (web) containers; local machines already have Flutter.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

FLUTTER_VERSION="3.24.5"
FLUTTER_DIR="$HOME/flutter"
FLUTTER_BIN="$FLUTTER_DIR/bin"

# Clone the SDK once; the container filesystem is cached after the hook
# completes, so later sessions reuse this without re-downloading.
if [ ! -x "$FLUTTER_BIN/flutter" ]; then
  git clone --depth 1 -b "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

git config --global --add safe.directory "$FLUTTER_DIR" || true
export PATH="$FLUTTER_BIN:$PATH"

# Disable analytics/first-run prompts so the toolchain stays non-interactive,
# then bootstrap the bundled Dart SDK and fetch package dependencies.
flutter --disable-analytics >/dev/null 2>&1 || true
flutter precache --universal
(cd "$CLAUDE_PROJECT_DIR" && flutter pub get)

# Persist Flutter on PATH for the rest of this session.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$FLUTTER_BIN:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi
