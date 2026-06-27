#!/bin/bash
# Release-MarkViewDmg.sh - builds, notarizes, staples, and validates a Developer ID signed MarkView DMG.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MACOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$MACOS_DIR/../.." && pwd)"

IDENTITY="${MARKVIEW_CODESIGN_IDENTITY:-}"
NOTARY_PROFILE="${MARKVIEW_NOTARY_PROFILE:-markview-notary}"
NOTARY_TIMEOUT="${MARKVIEW_NOTARY_TIMEOUT:-1h}"
DMG_PATH=""
SKIP_BUILD=false

usage() {
    cat <<'EOF'
Usage: Release-MarkViewDmg.sh [options]

Builds a Developer ID signed DMG, submits it to Apple's notary service, staples
the ticket, and validates the final distributable.

Options:
  --identity <name>             Developer ID Application signing identity.
                                May also be set with MARKVIEW_CODESIGN_IDENTITY.
  --keychain-profile <name>     notarytool keychain profile (default: markview-notary).
                                May also be set with MARKVIEW_NOTARY_PROFILE.
  --timeout <duration>          notarytool wait timeout (default: 1h).
                                May also be set with MARKVIEW_NOTARY_TIMEOUT.
  --dmg <path>                  Existing DMG to notarize. Defaults to the current
                                versioned output path.
  --skip-build                  Do not run build.sh; notarize the existing DMG.
  -h, --help                    Show this help.

Before first use, store notary credentials once:
  xcrun notarytool store-credentials markview-notary
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --identity)
            IDENTITY="$2"
            shift 2
            ;;
        --keychain-profile|--profile)
            NOTARY_PROFILE="$2"
            shift 2
            ;;
        --timeout)
            NOTARY_TIMEOUT="$2"
            shift 2
            ;;
        --dmg)
            DMG_PATH="$2"
            shift 2
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "macOS release packaging must be run on macOS." >&2
    exit 1
fi

for cmd in pwsh codesign xcrun spctl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Required command not found: $cmd" >&2
        exit 1
    fi
done

MARKVIEW_CSPROJ="$REPO_ROOT/src/host/MarkdownViewerHost/MarkdownViewerHost.csproj"
MARKVIEW_VERSION="${MARKVIEW_VERSION:-$(pwsh -NoProfile -Command "([xml](Get-Content -Raw -LiteralPath '$MARKVIEW_CSPROJ')).Project.PropertyGroup.Version")}"

if [[ -z "$DMG_PATH" ]]; then
    DMG_PATH="$MACOS_DIR/output/MarkView_${MARKVIEW_VERSION}_arm64.dmg"
fi

if [[ "$SKIP_BUILD" == false ]]; then
    if [[ -z "$IDENTITY" || "$IDENTITY" == "-" ]]; then
        echo "Developer ID signing identity is required for a public release DMG." >&2
        echo "Use --identity or MARKVIEW_CODESIGN_IDENTITY." >&2
        exit 1
    fi

    echo "Building Developer ID signed DMG..."
    MARKVIEW_CODESIGN_IDENTITY="$IDENTITY" "$MACOS_DIR/build.sh"
fi

if [[ ! -f "$DMG_PATH" ]]; then
    echo "DMG not found: $DMG_PATH" >&2
    exit 1
fi

echo "Verifying DMG code signature..."
codesign --verify --verbose=2 "$DMG_PATH"

echo "Submitting DMG for notarization..."
xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait \
    --timeout "$NOTARY_TIMEOUT"

echo "Stapling notarization ticket..."
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

echo "Assessing DMG with Gatekeeper..."
spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"

echo ""
echo "Release DMG is signed, notarized, stapled, and ready to publish:"
echo "  $DMG_PATH"
