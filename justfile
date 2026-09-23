# Justfile for the Slint Android app.
#
# Install just locally with: `cargo install just --locked`
# (or `brew install just`, `apt install just`, etc.)
# Run `just` with no arguments to see the recipe list. CI under
# .github/workflows/ci.yml invokes the same recipes you run locally.

set shell := ["bash", "-cu"]

# Show available recipes
default:
    @just --list

# Format all Rust code in place
fmt:
    cargo fmt --all

# Lint with clippy, treating warnings as errors
clippy:
    cargo clippy --workspace --all-targets -- -D warnings

# Run host-side workspace tests
test:
    cargo test --workspace

# Build a debug APK (multi-arch: aarch64 + x86_64)
build:
    # cargo-apk2 doesn't honor `default-members`; run from the app/ dir so
    # the cdylib package is selected unambiguously. --lib narrows it further to
    # the cdylib: without it cargo-apk2 also tries to package the `desktop`
    # example and fails looking for a non-existent examples/libdesktop.so.
    cd app && cargo apk2 build --lib

# Fast UI iteration with no emulator: builds the `desktop` example, which calls
# the same run_ui() the Android entry point does. Rendering is winit+FemtoVG
# here vs Skia on device, so layout matches but treat the device as the source
# of truth for pixel-level detail.
# Run the UI in a desktop window (no emulator needed)
desktop:
    cargo run -p slint_android_app --example desktop

# Build a release APK (multi-arch: aarch64 + x86_64)
release:
    cd app && cargo apk2 build --lib --release

# Builds a DEBUG apk. A release APK is unsigned unless a keystore
# is supplied, and an unsigned APK will not install - tapping it just gives
# "problem parsing the package". The debug build is auto-signed with the
# standard Android debug key, so it installs and proves packaging works.
# Use `just apk-release` (with a keystore) to cut something distributable.
#
# --lib packages only the cdylib. Without it cargo-apk2 also tries to APK any
# example target and fails looking for a .so that does not exist.
# `just` lists the LAST comment line as the description, so keep the one-liner
# immediately above the recipe.
# Build a debug APK and verify it is actually installable
apk:
    #!/usr/bin/env bash
    set -euo pipefail
    cd app && cargo apk2 build --lib
    cd "{{justfile_directory()}}"
    just _apk-verify debug

# Build a signed release APK. Requires a keystore; cargo-apk2 reads these two
# environment variables directly (no Cargo.toml config):
#   CARGO_APK_RELEASE_KEYSTORE           path to the .jks
#   CARGO_APK_RELEASE_KEYSTORE_PASSWORD  its password
# Without them the output is UNSIGNED and will not install.
# Build a signed release APK (needs CARGO_APK_RELEASE_KEYSTORE*)
apk-release:
    #!/usr/bin/env bash
    set -euo pipefail
    : "${CARGO_APK_RELEASE_KEYSTORE:?set CARGO_APK_RELEASE_KEYSTORE to your .jks path}"
    : "${CARGO_APK_RELEASE_KEYSTORE_PASSWORD:?set CARGO_APK_RELEASE_KEYSTORE_PASSWORD}"
    cd app && cargo apk2 build --lib --release
    cd "{{justfile_directory()}}"
    just _apk-verify release

# Print the path of the built APK (CI consumes this)
apk-path profile="debug":
    #!/usr/bin/env bash
    set -euo pipefail
    # NEVER just glob '*.apk'. cargo-apk2 emits TWO files: a pre-zipalign
    # <name>-unaligned.apk that CANNOT be installed, and the real <name>.apk.
    # Picking the wrong one ships something that fails at install time.
    apk="$(find "target/{{profile}}/apk" -maxdepth 1 -name '*.apk' ! -name '*-unaligned.apk' 2>/dev/null | head -1)"
    if [ -z "$apk" ]; then
        echo "no installable APK under target/{{profile}}/apk - run 'just apk' first" >&2
        exit 1
    fi
    printf '%s\n' "$apk"

# Gate the APK before anyone tries to install it. Each check here corresponds
# to a failure that ships silently: a truncated .so from a cache-restored
# broken build installs then crashes; a missing launcher activity installs
# with no icon and cannot be opened at all.
[private]
_apk-verify profile:
    #!/usr/bin/env bash
    set -euo pipefail
    apk="$(just apk-path {{profile}})"
    bt="$(ls -d "${ANDROID_HOME:?ANDROID_HOME not set}"/build-tools/*/ | sort -V | tail -1)"
    echo "APK: $apk"; ls -lh "$apk"
    echo "=== manifest ==="
    "${bt}aapt" dump badging "$apk" | grep -E 'package:|sdkVersion:|launchable-activity:|native-code:' || true
    echo "=== signature ==="
    "${bt}apksigner" verify --print-certs "$apk" | grep -E 'Verified using|Signer .* certificate' || true
    if [ "{{profile}}" = "release" ] && "${bt}apksigner" verify --print-certs "$apk" | grep -qi 'Android Debug'; then
        echo "ERROR: release APK is signed with the DEBUG key - signing did not take" >&2
        exit 1
    fi
    size="$(unzip -l "$apk" | awk '/lib\/arm64-v8a\/.*\.so/ {print $1; exit}')"
    echo "arm64-v8a native lib = ${size:-MISSING} bytes"
    if [ -z "$size" ] || [ "$size" -lt 1000000 ]; then
        echo "ERROR: arm64 native lib missing or truncated (${size:-0} bytes)" >&2
        exit 1
    fi
    if ! "${bt}aapt" dump badging "$apk" | grep -q 'launchable-activity:'; then
        echo "ERROR: no launchable-activity - installs but has no launcher icon" >&2
        exit 1
    fi
    echo "APK verified."

# Idempotent: re-running on an existing AVD is a no-op for creation. Picks
# the system-image ABI to match the host: x86_64 on Intel/AMD, arm64-v8a
# on Apple Silicon. Requires ANDROID_HOME pointing at a working SDK.
# Create an Android emulator (AVD "slint") and download its system image
setup-emulator:
    #!/usr/bin/env bash
    set -euo pipefail
    : "${ANDROID_HOME:?ANDROID_HOME is not set — install the Android SDK or use the devcontainer}"
    case "$(uname -m)" in
      arm64|aarch64) abi=arm64-v8a ;;
      x86_64|amd64)  abi=x86_64 ;;
      *) echo "Unsupported host arch: $(uname -m)"; exit 1 ;;
    esac
    image="system-images;android-34;default;${abi}"
    sdkmanager_bin="${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager"
    avdmanager_bin="${ANDROID_HOME}/cmdline-tools/latest/bin/avdmanager"
    emulator_bin="${ANDROID_HOME}/emulator/emulator"
    echo "Installing $image (this may download ~700MB on first run)..."
    # `yes |` would trip `set -o pipefail` with SIGPIPE (141) once sdkmanager
    # closes stdin; a finite stream of "y" lines avoids that.
    printf 'y\n%.0s' {1..100} | "$sdkmanager_bin" --install "$image" > /dev/null
    if "$emulator_bin" -list-avds | grep -qx slint; then
        echo "AVD 'slint' already exists — skipping create."
    else
        echo "Creating AVD 'slint'..."
        echo "no" | "$avdmanager_bin" create avd -n slint -k "$image" --force
    fi
    echo "Done. Run 'just run' to launch the app."

# Starts the "slint" AVD if no device is connected. Set AVD=<name> to use
# a different one. Run 'just setup-emulator' once first if you don't have
# any AVDs yet.
# Build, install, and launch the app on emulator/device
run:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! adb get-state > /dev/null 2>&1; then
        : "${ANDROID_HOME:?ANDROID_HOME is not set}"
        emulator_bin="${ANDROID_HOME}/emulator/emulator"
        avd="${AVD:-$("$emulator_bin" -list-avds | head -n 1)}"
        if [ -z "$avd" ]; then
            echo "No AVD found. Run 'just setup-emulator' to create one,"
            echo "or set AVD=<name> just run to use an existing AVD."
            exit 1
        fi
        echo "Starting emulator: $avd"
        emulator_args=(-avd "$avd" -no-boot-anim -no-snapshot-save)
        # Auto-enable headless mode on boxes without a display (e.g. CI).
        if [ -z "${DISPLAY:-}" ] || [ "${HEADLESS:-0}" = "1" ]; then
            emulator_args+=(-no-window -gpu swiftshader_indirect)
        fi
        "$emulator_bin" "${emulator_args[@]}" > /tmp/emulator.log 2>&1 &
    fi
    echo "Waiting for device + full boot..."
    adb wait-for-device
    adb shell 'while [ "$(getprop sys.boot_completed | tr -d "\r")" != "1" ]; do sleep 2; done'
    echo "Device ready."
    cd app && cargo apk2 run --lib

# Full local CI pipeline (mirrors what runs on PRs)
ci: fmt-check clippy test

# --- private helpers (callable, but hidden from `just --list`) -------------

# CI-only: verify formatting without modifying files
[private]
fmt-check:
    cargo fmt --all -- --check

# CI-only: install Linux apt packages Slint's Skia renderer needs to build
[private]
install-host-deps:
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends \
        pkg-config \
        libfontconfig1-dev \
        libfreetype6-dev \
        clang \
        cmake \
        ninja-build
