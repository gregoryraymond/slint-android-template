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
    # the cdylib package is selected unambiguously.
    cd app && cargo apk2 build

# Build a release APK (multi-arch: aarch64 + x86_64)
release:
    cd app && cargo apk2 build --release

# This is what .github/workflows/android.yml calls, so packaging is identical
# locally and in CI - a green `just apk` here means the workflow's build step
# will pass too. `just` uses the LAST comment line as the listed description,
# so keep the one-liner below immediately above the recipe.
# Build a release APK and verify one was actually produced
apk:
    #!/usr/bin/env bash
    set -euo pipefail
    cd app && cargo apk2 build --release
    cd "{{justfile_directory()}}"
    # cargo-apk2 writes under target/<triple>/release/apk/. Fail loudly if the
    # build "succeeded" but emitted nothing - otherwise CI would upload air.
    apk="$(find target -name '*.apk' -print -quit)"
    if [ -z "$apk" ]; then
        echo "no APK produced under target/" >&2
        exit 1
    fi
    ls -lh "$apk"

# Print the path of the built APK (CI consumes this; run `just apk` first)
apk-path:
    #!/usr/bin/env bash
    set -euo pipefail
    apk="$(find target -name '*.apk' -print -quit)"
    if [ -z "$apk" ]; then
        echo "no APK found - run 'just apk' first" >&2
        exit 1
    fi
    printf '%s\n' "$apk"

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
    cd app && cargo apk2 run

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
