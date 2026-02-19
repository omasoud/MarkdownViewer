#!/bin/bash
# build.sh - Linux Snap packaging script for MarkView
# Stages engine payload, downloads/trims bundled pwsh, and creates Snap package.
# Supports amd64 and arm64 architectures.
#
# Usage:
#   ./build.sh              # Build for current architecture
#   ./build.sh arm64        # Build for arm64
#   ./build.sh amd64        # Build for amd64
#   ./build.sh --stage-only # Stage files only; don't run snapcraft

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

STAGE_ONLY=false
ARCH=""

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --stage-only) STAGE_ONLY=true ;;
        amd64|arm64|x86_64|aarch64) ARCH="$arg" ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

# Default to current architecture
if [ -z "$ARCH" ]; then
    ARCH="$(uname -m)"
fi

# Normalize arch name
case "$ARCH" in
    x86_64|amd64)   ARCH="amd64" ;;
    aarch64|arm64)   ARCH="arm64" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

echo "========================================="
echo "MarkView Linux Snap Build"
echo "========================================="
echo "Architecture: $ARCH"
echo "Repo root:    $REPO_ROOT"
echo ""

# Read pinned pwsh version
PWSH_CONFIG="$SCRIPT_DIR/build/pwsh-versions.json"
if [ ! -f "$PWSH_CONFIG" ]; then
    echo "ERROR: $PWSH_CONFIG not found"
    exit 1
fi

# Extract version and SHA from config (using pwsh for JSON parsing, fallback to grep)
if command -v pwsh &>/dev/null; then
    PWSH_VERSION=$(pwsh -NoProfile -Command "(Get-Content '$PWSH_CONFIG' -Raw | ConvertFrom-Json).version")
    PWSH_URL=$(pwsh -NoProfile -Command "(Get-Content '$PWSH_CONFIG' -Raw | ConvertFrom-Json).archives.'$ARCH'.url")
    PWSH_SHA256=$(pwsh -NoProfile -Command "(Get-Content '$PWSH_CONFIG' -Raw | ConvertFrom-Json).archives.'$ARCH'.sha256")
else
    # Fallback: extract with grep/sed (less robust)
    PWSH_VERSION=$(grep -o '"version": *"[^"]*"' "$PWSH_CONFIG" | head -1 | sed 's/.*"\([^"]*\)"/\1/')
    echo "WARNING: pwsh not available for JSON parsing; URL/SHA extraction may be imprecise"
    PWSH_URL="https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-${ARCH/amd64/x64}.tar.gz"
    PWSH_SHA256=""
fi

echo "PowerShell version: $PWSH_VERSION"
echo ""

# -----------------------------------------------
# 1) Stage app files
# -----------------------------------------------
echo "Staging app files..."

STAGE_DIR="$SCRIPT_DIR/staged"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/app" "$STAGE_DIR/bin" "$STAGE_DIR/meta/gui"

# Core engine files
cp "$REPO_ROOT/src/core/Open-Markdown.ps1"     "$STAGE_DIR/app/"
cp "$REPO_ROOT/src/core/script.js"              "$STAGE_DIR/app/"
cp "$REPO_ROOT/src/core/style.css"              "$STAGE_DIR/app/"
cp "$REPO_ROOT/src/core/highlight.min.js"       "$STAGE_DIR/app/"
cp "$REPO_ROOT/src/core/highlight-theme.css"    "$STAGE_DIR/app/"
cp "$REPO_ROOT/src/core/icons/markdown.ico"     "$STAGE_DIR/app/"

# Platform modules
cp "$REPO_ROOT/src/linux/MarkdownViewer.psm1"          "$STAGE_DIR/app/"
cp "$REPO_ROOT/src/core/MarkdownViewer.Shared.psm1"    "$STAGE_DIR/app/"

# Launcher
cp "$REPO_ROOT/src/linux/markview" "$STAGE_DIR/bin/"
chmod +x "$STAGE_DIR/bin/markview"

# Desktop integration
cp "$REPO_ROOT/src/linux/markview.desktop" "$STAGE_DIR/meta/gui/"
cp "$REPO_ROOT/src/linux/markview.png"     "$STAGE_DIR/meta/gui/"

echo "  App files staged to: $STAGE_DIR"

# -----------------------------------------------
# 2) Download and trim pwsh
# -----------------------------------------------
echo ""
echo "Preparing PowerShell runtime..."

CACHE_DIR="$SCRIPT_DIR/.cache"
mkdir -p "$CACHE_DIR"

# Map arch for download URL (GitHub uses x64, not amd64)
DL_ARCH="$ARCH"
if [ "$DL_ARCH" = "amd64" ]; then
    DL_ARCH="x64"
fi

TARBALL_NAME="powershell-${PWSH_VERSION}-linux-${DL_ARCH}.tar.gz"
CACHED_TARBALL="$CACHE_DIR/$TARBALL_NAME"

if [ -f "$CACHED_TARBALL" ]; then
    echo "  Using cached: $CACHED_TARBALL"
    # Verify hash if available
    if [ -n "$PWSH_SHA256" ]; then
        ACTUAL_SHA=$(sha256sum "$CACHED_TARBALL" | awk '{print $1}')
        if [ "$ACTUAL_SHA" != "$PWSH_SHA256" ]; then
            echo "  WARNING: Hash mismatch on cached file. Re-downloading."
            rm -f "$CACHED_TARBALL"
        fi
    fi
fi

if [ ! -f "$CACHED_TARBALL" ]; then
    if [ -z "$PWSH_URL" ]; then
        PWSH_URL="https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-${DL_ARCH}.tar.gz"
    fi
    echo "  Downloading PowerShell $PWSH_VERSION ($ARCH)..."
    echo "  URL: $PWSH_URL"
    wget -q --show-progress "$PWSH_URL" -O "$CACHED_TARBALL"

    # Verify hash
    if [ -n "$PWSH_SHA256" ]; then
        ACTUAL_SHA=$(sha256sum "$CACHED_TARBALL" | awk '{print $1}')
        if [ "$ACTUAL_SHA" != "$PWSH_SHA256" ]; then
            echo "ERROR: SHA256 hash mismatch!"
            echo "  Expected: $PWSH_SHA256"
            echo "  Actual:   $ACTUAL_SHA"
            rm -f "$CACHED_TARBALL"
            exit 1
        fi
        echo "  Hash verified OK"
    else
        echo "  WARNING: No SHA256 hash configured; skipping verification"
    fi
fi

# Extract pwsh directly into staged/pwsh/ (single dump part for snapcraft)
PWSH_DIR="$STAGE_DIR/pwsh"
mkdir -p "$PWSH_DIR"
echo "  Extracting..."
tar xzf "$CACHED_TARBALL" -C "$PWSH_DIR"

# Trim pwsh using the PowerShell trimming script
if command -v pwsh &>/dev/null; then
    echo "  Trimming PowerShell bundle..."
    pwsh -NoProfile -File "$SCRIPT_DIR/scripts/Trim-PwshBundle-Linux.ps1" -PwshRoot "$PWSH_DIR"
elif [ -x "$PWSH_DIR/pwsh" ]; then
    echo "  Trimming PowerShell bundle (using extracted pwsh)..."
    "$PWSH_DIR/pwsh" -NoProfile -File "$SCRIPT_DIR/scripts/Trim-PwshBundle-Linux.ps1" -PwshRoot "$PWSH_DIR"
else
    echo "  WARNING: Cannot trim; pwsh not available. Bundle will be larger than necessary."
fi

# Verify trimmed bundle
if command -v pwsh &>/dev/null; then
    echo "  Verifying trimmed bundle..."
    pwsh -NoProfile -File "$SCRIPT_DIR/scripts/Verify-MarkViewPwsh-Linux.ps1" \
        -ScriptPath "$STAGE_DIR/app/Open-Markdown.ps1" \
        -ModulePath "$STAGE_DIR/app/MarkdownViewer.psm1" \
        -SharedModulePath "$STAGE_DIR/app/MarkdownViewer.Shared.psm1" \
        -PwshDir "$PWSH_DIR"
fi

echo "  PowerShell runtime ready at: $PWSH_DIR"

# -----------------------------------------------
# 3) Summary / Build snap
# -----------------------------------------------
echo ""
echo "Staging complete."
echo ""

# Show sizes
du -sh "$STAGE_DIR/app" | awk '{print "  App:  "$1}'
du -sh "$STAGE_DIR/pwsh" | awk '{print "  Pwsh: "$1}'
du -sh "$STAGE_DIR" | awk '{print "  Total: "$1}'
echo ""

if [ "$STAGE_ONLY" = true ]; then
    echo "Stage-only mode; skipping snapcraft."
    echo "To build the snap manually:"
    echo "  cd $SCRIPT_DIR && snapcraft --destructive-mode"
    echo "Then move the .snap to output/:"
    echo "  mkdir -p output && mv *.snap output/"
    exit 0
fi

# Build snap
if ! command -v snapcraft &>/dev/null; then
    echo "WARNING: snapcraft not installed. Install with: sudo snap install snapcraft --classic"
    echo "Staged files are ready at:"
    echo "  $STAGE_DIR"
    echo "  $PWSH_DIR"
    exit 0
fi

echo "Building snap for $ARCH..."
cd "$SCRIPT_DIR"
snapcraft --destructive-mode --platform "$ARCH"

# Move .snap to output/ for consistency with win-msix
mkdir -p "$SCRIPT_DIR/output"
mv -f "$SCRIPT_DIR"/*.snap "$SCRIPT_DIR/output/" 2>/dev/null || true

echo ""
echo "Build complete!"
ls -la "$SCRIPT_DIR/output/"*.snap 2>/dev/null
