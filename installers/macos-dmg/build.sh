#!/bin/bash
# build.sh - macOS DMG packaging script for MarkView.
# Stages MarkView.app, bundles trimmed arm64 PowerShell, and optionally creates a DMG.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ARCH="arm64"
STAGE_ONLY=false
SKIP_PWSH_TRIM=false
SKIP_SIGN=false

for arg in "$@"; do
    case "$arg" in
        --stage-only) STAGE_ONLY=true ;;
        --skip-pwsh-trim) SKIP_PWSH_TRIM=true ;;
        --skip-sign) SKIP_SIGN=true ;;
        arm64) ARCH="arm64" ;;
        x64|x86_64|amd64)
            echo "macOS packaging is arm64-only for the first release." >&2
            exit 1
            ;;
        *)
            echo "Unknown argument: $arg" >&2
            exit 1
            ;;
    esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "macOS packaging must be run on macOS." >&2
    exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
    echo "This first macOS package target must be built on arm64." >&2
    exit 1
fi

for cmd in pwsh curl shasum swiftc plutil sips iconutil; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Required command not found: $cmd" >&2
        exit 1
    fi
done

if [[ "$STAGE_ONLY" == false ]] && ! command -v hdiutil >/dev/null 2>&1; then
    echo "Required command not found: hdiutil" >&2
    exit 1
fi

MARKVIEW_CSPROJ="$REPO_ROOT/src/host/MarkdownViewerHost/MarkdownViewerHost.csproj"
MARKVIEW_VERSION="${MARKVIEW_VERSION:-$(pwsh -NoProfile -Command "([xml](Get-Content -Raw -LiteralPath '$MARKVIEW_CSPROJ')).Project.PropertyGroup.Version")}"
MIN_MACOS_VERSION="${MARKVIEW_MIN_MACOS_VERSION:-14.0}"

PWSH_CONFIG="$SCRIPT_DIR/build/pwsh-versions.json"
PWSH_VERSION="$(pwsh -NoProfile -Command "(Get-Content '$PWSH_CONFIG' -Raw | ConvertFrom-Json).version")"
PWSH_URL="$(pwsh -NoProfile -Command "(Get-Content '$PWSH_CONFIG' -Raw | ConvertFrom-Json).archives.arm64.url")"
PWSH_SHA256="$(pwsh -NoProfile -Command "(Get-Content '$PWSH_CONFIG' -Raw | ConvertFrom-Json).archives.arm64.sha256")"

STAGE_DIR="$SCRIPT_DIR/staged"
APP_NAME="MarkView.app"
APP_PATH="$STAGE_DIR/$APP_NAME"
CONTENTS_DIR="$APP_PATH/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
APP_RESOURCES_DIR="$RESOURCES_DIR/app"
PWSH_DIR="$RESOURCES_DIR/pwsh"
CLI_DIR="$STAGE_DIR/bin"

echo "========================================="
echo "MarkView macOS DMG Build"
echo "========================================="
echo "Architecture:       $ARCH"
echo "MarkView version:   $MARKVIEW_VERSION"
echo "Minimum macOS:      $MIN_MACOS_VERSION"
echo "PowerShell version: $PWSH_VERSION"
echo "Repo root:          $REPO_ROOT"
echo ""

echo "[1/9] Preparing staging directory..."
rm -rf "$STAGE_DIR"
mkdir -p "$MACOS_DIR" "$APP_RESOURCES_DIR" "$PWSH_DIR" "$CLI_DIR"

echo "[2/9] Staging engine payload..."
cp "$REPO_ROOT/src/core/Open-Markdown.ps1" "$APP_RESOURCES_DIR/"
cp "$REPO_ROOT/src/core/script.js" "$APP_RESOURCES_DIR/"
cp "$REPO_ROOT/src/core/style.css" "$APP_RESOURCES_DIR/"
cp "$REPO_ROOT/src/core/highlight.min.js" "$APP_RESOURCES_DIR/"
cp "$REPO_ROOT/src/core/highlight-theme.css" "$APP_RESOURCES_DIR/"
cp "$REPO_ROOT/src/core/icons/markdown.ico" "$APP_RESOURCES_DIR/"
cp "$REPO_ROOT/src/core/MarkdownViewer.Shared.psm1" "$APP_RESOURCES_DIR/"
cp "$REPO_ROOT/src/mac/MarkdownViewer.psm1" "$APP_RESOURCES_DIR/"
cp "$REPO_ROOT/src/mac/markview" "$CLI_DIR/"
chmod +x "$CLI_DIR/markview"

echo "[3/9] Generating app icon..."
pwsh -NoProfile -File "$SCRIPT_DIR/scripts/New-MarkViewIcns.ps1" \
    -SourcePng "$REPO_ROOT/src/linux/markview.png" \
    -OutputIcns "$RESOURCES_DIR/markview.icns"

echo "[4/9] Generating Info.plist..."
sed \
    -e "s/__VERSION__/$MARKVIEW_VERSION/g" \
    -e "s/__MIN_MACOS__/$MIN_MACOS_VERSION/g" \
    "$REPO_ROOT/src/host/MarkdownViewerMacHost/Info.plist.template" > "$CONTENTS_DIR/Info.plist"
plutil -lint "$CONTENTS_DIR/Info.plist"

echo "[5/9] Compiling Swift host..."
swiftc "$REPO_ROOT/src/host/MarkdownViewerMacHost/MarkViewHost.swift" \
    -o "$MACOS_DIR/MarkViewHost" \
    -framework AppKit \
    -framework Foundation
chmod +x "$MACOS_DIR/MarkViewHost"

echo "[6/9] Preparing bundled PowerShell..."
CACHE_DIR="$SCRIPT_DIR/.cache"
mkdir -p "$CACHE_DIR"
TARBALL_NAME="powershell-${PWSH_VERSION}-osx-arm64.tar.gz"
CACHED_TARBALL="$CACHE_DIR/$TARBALL_NAME"

if [[ -f "$CACHED_TARBALL" ]]; then
    ACTUAL_SHA="$(shasum -a 256 "$CACHED_TARBALL" | awk '{print tolower($1)}')"
    if [[ "$ACTUAL_SHA" != "$PWSH_SHA256" ]]; then
        echo "Cached PowerShell archive hash mismatch; re-downloading."
        rm -f "$CACHED_TARBALL"
    fi
fi

if [[ ! -f "$CACHED_TARBALL" ]]; then
    echo "Downloading $PWSH_URL"
    curl -L --fail "$PWSH_URL" -o "$CACHED_TARBALL"
fi

ACTUAL_SHA="$(shasum -a 256 "$CACHED_TARBALL" | awk '{print tolower($1)}')"
if [[ "$ACTUAL_SHA" != "$PWSH_SHA256" ]]; then
    echo "PowerShell archive SHA256 mismatch." >&2
    echo "  Expected: $PWSH_SHA256" >&2
    echo "  Actual:   $ACTUAL_SHA" >&2
    exit 1
fi

tar xzf "$CACHED_TARBALL" -C "$PWSH_DIR"
chmod +x "$PWSH_DIR/pwsh"

if [[ "$SKIP_PWSH_TRIM" == false ]]; then
    echo "[7/9] Trimming bundled PowerShell..."
    pwsh -NoProfile -File "$SCRIPT_DIR/scripts/Trim-PwshBundle-macOS.ps1" -PwshRoot "$PWSH_DIR"
else
    echo "[7/9] Skipping PowerShell trim."
fi

echo "[8/9] Verifying staged runtime..."
pwsh -NoProfile -File "$SCRIPT_DIR/scripts/Verify-MarkViewPwsh-macOS.ps1" \
    -ScriptPath "$APP_RESOURCES_DIR/Open-Markdown.ps1" \
    -ModulePath "$APP_RESOURCES_DIR/MarkdownViewer.psm1" \
    -SharedModulePath "$APP_RESOURCES_DIR/MarkdownViewer.Shared.psm1" \
    -PwshDir "$PWSH_DIR"

echo "[9/9] Signing app..."
if [[ "$SKIP_SIGN" == true ]]; then
    echo "Skipping signing."
else
    "$SCRIPT_DIR/scripts/Sign-MarkViewApp.sh" --app "$APP_PATH"
fi

echo ""
echo "Staging complete."
du -sh "$APP_PATH" | awk '{print "  App: " $1}'

if [[ "$STAGE_ONLY" == true ]]; then
    echo "Stage-only mode; skipping DMG creation."
    echo "Staged app: $APP_PATH"
    exit 0
fi

echo "Creating DMG..."
DMG_ROOT="$SCRIPT_DIR/dmg/root"
DMG_NAME="MarkView_${MARKVIEW_VERSION}_${ARCH}.dmg"
DMG_PATH="$SCRIPT_DIR/output/$DMG_NAME"

rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT" "$SCRIPT_DIR/output"
cp -R "$APP_PATH" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"
rm -f "$DMG_PATH"

hdiutil create \
    -volname "MarkView" \
    -srcfolder "$DMG_ROOT" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

if [[ "${MARKVIEW_CODESIGN_IDENTITY:-}" != "" ]]; then
    codesign --force --sign "$MARKVIEW_CODESIGN_IDENTITY" "$DMG_PATH"
fi

echo ""
echo "Build complete: $DMG_PATH"
echo "For public distribution, notarize and staple the DMG with xcrun notarytool and xcrun stapler."
