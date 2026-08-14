#!/bin/bash
# Sign-MarkViewApp.sh - signs MarkView.app for local or Developer ID distribution.

set -euo pipefail

APP_PATH=""
IDENTITY="${MARKVIEW_CODESIGN_IDENTITY:--}"
PWSH_ENTITLEMENTS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --app)
            APP_PATH="$2"
            shift 2
            ;;
        --identity)
            IDENTITY="$2"
            shift 2
            ;;
        --pwsh-entitlements)
            PWSH_ENTITLEMENTS="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

if [[ -z "$APP_PATH" ]]; then
    echo "Usage: $0 --app /path/to/MarkView.app [--identity <codesign identity>] --pwsh-entitlements file" >&2
    exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
    echo "App bundle not found: $APP_PATH" >&2
    exit 1
fi

SIGN_ARGS=(--force --sign "$IDENTITY" --options runtime)
if [[ "$IDENTITY" != "-" ]]; then
    SIGN_ARGS+=(--timestamp)
else
    SIGN_ARGS+=(--timestamp=none)
fi

if [[ -z "$PWSH_ENTITLEMENTS" || ! -f "$PWSH_ENTITLEMENTS" ]]; then
    echo "PowerShell entitlements file not found: $PWSH_ENTITLEMENTS" >&2
    exit 1
fi

echo "Signing app: $APP_PATH"
echo "Identity: $IDENTITY"

PWSH_DIR="$APP_PATH/Contents/Resources/pwsh"
if [[ -d "$PWSH_DIR" ]]; then
    while IFS= read -r file_path; do
        if file "$file_path" | grep -q "Mach-O"; then
            if [[ "$file_path" == "$PWSH_DIR/pwsh" ]]; then
                codesign "${SIGN_ARGS[@]}" --entitlements "$PWSH_ENTITLEMENTS" "$file_path"
            else
                codesign "${SIGN_ARGS[@]}" "$file_path"
            fi
        fi
    done < <(find "$PWSH_DIR" -type f \( -perm -111 -o -name "*.dylib" -o -name "*.so" -o -name "*.bundle" \))
fi

HOST="$APP_PATH/Contents/MacOS/MarkViewHost"
if [[ -f "$HOST" ]]; then
    codesign "${SIGN_ARGS[@]}" "$HOST"
fi

codesign "${SIGN_ARGS[@]}" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "Signing complete."
