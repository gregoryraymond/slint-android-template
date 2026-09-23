#!/usr/bin/env bash
# Rename this template into your own project, in one pass.
#
# GitHub's "Use this template" button copies files LITERALLY - it cannot run
# cargo-generate hooks. So rather than shipping {{placeholders}} (which would
# leave you with a repo that does not compile and a workspace rust-analyzer
# cannot load), this template ships a REAL, BUILDING project and renames it
# here.
#
#   ./init.sh --name my-app --package com.example.myapp --label "My App"
#
# Then the script deletes itself: it is template scaffolding, not part of your
# project. Re-running it on an already-initialised repo is a no-op because the
# strings it looks for are gone.
set -euo pipefail

NAME="" PKG="" LABEL="" ASSUME_YES=0

die() { echo "error: $*" >&2; exit 1; }

usage() {
    # Print the header comment block, stopping at the first non-comment line.
    # A hardcoded line range silently leaks code into --help as the block grows.
    awk 'NR>1 { if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "$0"
    cat <<'EOF'

Options:
  --name <kebab-case>     Project/crate name, e.g. my-app        (required)
  --package <reverse-dns> Android application id                 (required)
  --label "<text>"        Launcher label. Defaults to --name titlecased.
  -y, --yes               Do not prompt for confirmation.
EOF
}

while (( $# )); do
    case "$1" in
        --name)    NAME="${2:-}"; shift 2 ;;
        --package) PKG="${2:-}";  shift 2 ;;
        --label)   LABEL="${2:-}";shift 2 ;;
        -y|--yes)  ASSUME_YES=1;  shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown argument: $1 (try --help)" ;;
    esac
done

[[ -n "$NAME" ]] || { usage; echo; die "--name is required"; }
[[ -n "$PKG"  ]] || die "--package is required"

# A Cargo package name must be a valid identifier once hyphens become
# underscores; enforce the kebab form up front so we fail here rather than in
# the middle of a rewrite.
[[ "$NAME" =~ ^[a-z][a-z0-9]*(-[a-z0-9]+)*$ ]] \
    || die "--name must be lowercase kebab-case starting with a letter (got: $NAME)"

# Each dot-segment of an Android application id becomes a Java package
# component: lowercase, starts with a letter, no hyphens, at least two
# segments. Android rejects single-segment ids outright.
[[ "$PKG" =~ ^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$ ]] \
    || die "--package must be reverse-DNS, lowercase, >=2 dot-separated segments, no hyphens (got: $PKG)"

# 'java' and 'android' prefixes are reserved by the platform and will be
# rejected at install time, not build time - so catch it now.
case "$PKG" in
    java.*|javax.*|android.*) die "--package may not start with a platform-reserved prefix (java/javax/android)" ;;
esac

SNAKE="${NAME//-/_}"
if [[ -z "$LABEL" ]]; then
    LABEL="$(echo "$NAME" | tr '-' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')"
fi

cd "$(dirname "$0")"

# Replacing the snake prefix also fixes the core crate: slint_android_app_core
# is literally <prefix>_core, so one substitution covers both.
declare -a FROM=("slint_android_app" "slint-android-app" "com.example.slintandroidapp" "Slint Android App")
declare -a TO=("$SNAKE" "$NAME" "$PKG" "$LABEL")

echo "This will rewrite the project in place:"
for i in "${!FROM[@]}"; do printf "  %-30s -> %s\n" "${FROM[$i]}" "${TO[$i]}"; done
echo
if (( ! ASSUME_YES )); then
    read -r -p "Proceed? [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]] || { echo "aborted"; exit 1; }
fi

# Skip .git (rewriting object files would corrupt history) and target/.
mapfile -t files < <(find . -type f \
    -not -path './.git/*' -not -path './target/*' -not -name 'init.sh')

python3 - "$SNAKE" "$NAME" "$PKG" "$LABEL" "${files[@]}" <<'PY'
import sys, pathlib
snake, name, pkg, label = sys.argv[1:5]
subs = [("slint_android_app", snake), ("slint-android-app", name),
        ("com.example.slintandroidapp", pkg), ("Slint Android App", label)]
for f in sys.argv[5:]:
    p = pathlib.Path(f)
    try:
        t = p.read_text(encoding="utf8")
    except (UnicodeDecodeError, OSError):
        continue            # binary asset (icons etc.) - nothing to rename
    o = t
    for a, b in subs:
        t = t.replace(a, b)
    if t != o:
        p.write_text(t, encoding="utf8")
        print("  rewrote", f[2:])
PY

# The template's own README documents the TEMPLATE. Your project needs a README
# about your project, so swap in the generated-project one.
if [[ -f docs/PROJECT_README.md ]]; then
    mv docs/PROJECT_README.md README.md
    rmdir docs 2>/dev/null || true
    echo "  installed project README"
fi

rm -f "$0"
echo
echo "Done. init.sh has removed itself."
echo "Next:"
echo "  git add -A && git commit -m 'Initialise ${NAME} from slint-android-template'"
echo "  just run          # build + install the APK on a connected device/emulator"
