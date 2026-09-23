# syntax=docker/dockerfile:1.7
#
# Dev container for slint_mobile.
#
# What this image documents (and provides):
#   - Rust stable + aarch64-linux-android target
#   - cargo-apk2 (active fork of cargo-apk; the APK packager)
#   - JDK 17 (required by Android build-tools / aapt2 + cargo-apk2's javac path)
#   - Kotlin compiler (cargo-apk2 invokes kotlinc when a crate declares
#     kotlin_sources; harmless when nothing does)
#   - Android SDK: platform-tools, platforms;android-34, build-tools;34.0.0
#   - Android NDK r27 (Slint's Skia renderer needs NDK >= 25)
#   - Native deps Skia drags in via slint (fontconfig, ssl, pkg-config)
#
# Versions are pinned via build args so this file also serves as the
# canonical record of "what versions does this project build against".

FROM mcr.microsoft.com/devcontainers/rust:1-bookworm

ARG ANDROID_API=34
ARG ANDROID_BUILD_TOOLS=34.0.0
ARG ANDROID_NDK_VERSION=27.0.12077973
ARG ANDROID_CMDLINE_TOOLS=11076708

ENV ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    ANDROID_NDK_ROOT=/opt/android-sdk/ndk/${ANDROID_NDK_VERSION} \
    JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
    PATH=/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:${PATH}

# --- System packages --------------------------------------------------------
# openjdk-17 → required by sdkmanager and the Android build-tools.
# unzip/wget → bootstrapping the SDK below.
# adb        → so `cargo apk2 run` can talk to devices/emulators.
# pkg-config, libfontconfig1-dev, libssl-dev → transitive native deps from
#   Slint's Skia renderer on Linux host builds (cargo check on the host
#   side; the Android build links its own copies via the NDK).
RUN apt-get update && apt-get install -y --no-install-recommends \
        openjdk-17-jdk-headless \
        unzip \
        wget \
        ca-certificates \
        adb \
        pkg-config \
        libfontconfig1-dev \
        libssl-dev \
        clang \
        cmake \
        ninja-build \
    && rm -rf /var/lib/apt/lists/*

# --- Android SDK + NDK ------------------------------------------------------
RUN mkdir -p "${ANDROID_HOME}/cmdline-tools" \
    && cd /tmp \
    && wget -q "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS}_latest.zip" -O cmdtools.zip \
    && unzip -q cmdtools.zip -d "${ANDROID_HOME}/cmdline-tools" \
    && mv "${ANDROID_HOME}/cmdline-tools/cmdline-tools" "${ANDROID_HOME}/cmdline-tools/latest" \
    && rm cmdtools.zip \
    && yes | sdkmanager --licenses > /dev/null \
    && sdkmanager --install \
        "platform-tools" \
        "platforms;android-${ANDROID_API}" \
        "build-tools;${ANDROID_BUILD_TOOLS}" \
        "ndk;${ANDROID_NDK_VERSION}" \
    && chmod -R a+rX "${ANDROID_HOME}"

# --- Kotlin compiler --------------------------------------------------------
# cargo-apk2 only shells out to kotlinc when a crate declares
# kotlin_sources, but bundling it here makes that path zero-config when a
# downstream crate (e.g. slint-android-gestures) opts in.
ARG KOTLIN_VERSION=1.9.0
ENV KOTLIN_HOME=/opt/kotlinc \
    PATH=/opt/kotlinc/bin:${PATH}
RUN wget -q "https://github.com/JetBrains/kotlin/releases/download/v${KOTLIN_VERSION}/kotlin-compiler-${KOTLIN_VERSION}.zip" -O /tmp/kotlinc.zip \
    && unzip -q /tmp/kotlinc.zip -d /opt \
    && rm /tmp/kotlinc.zip

# --- Rust Android target + cargo-apk2 ---------------------------------------
# Run as the vscode user so cargo's install dir is in $HOME/.cargo and
# matches what rust-analyzer / the user's shell will see at runtime.
USER vscode
RUN rustup target add aarch64-linux-android x86_64-linux-android \
    && cargo install cargo-apk2 just --locked

# Sanity check: print versions at image-build time so any drift is obvious
# in the build log.
RUN rustc --version \
    && cargo --version \
    && cargo apk2 --version \
    && just --version \
    && javac -version \
    && kotlinc -version \
    && sdkmanager --version

USER root
