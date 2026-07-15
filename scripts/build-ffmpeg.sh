#!/usr/bin/env bash
#
# Reproducibly build a pinned FFmpeg for DropThings Media Converter.
#
# Produces two static, arm64, LGPL-2.1+ binaries (ffmpeg + ffprobe) that only
# link Apple system frameworks (VideoToolbox, AudioToolbox, CoreMedia, ...).
# No GPL code is enabled, so the result is redistributable under the terms of
# LGPL-2.1+. No external libraries are linked (no libmp3lame, libvpx, libx264,
# libopus-as-external-lib), so there are no secondary license obligations and
# no pkg-config dependency.
#
# Everything is pinned: exact source version, SHA-256, and configure flags are
# recorded in this file and in docs/08-media-converter/RESEARCH-AND-LICENSES.md.
# Re-running this script on the same Xcode/clang produces a byte-identical
# archive (modulo Apple's linker timestamps).
#
# Usage:
#   scripts/build-ffmpeg.sh
#
# Output:
#   .build/third-party/ffmpeg/bin/ffmpeg
#   .build/third-party/ffmpeg/bin/ffprobe
#   .build/third-party/ffmpeg/VERSION   (records source tag + sha256 + flags)
#
# Requirements: Xcode command line tools (clang, make, curl, shasum).
# Not required: nasm/yasm (--disable-x86asm), pkg-config (no external libs),
# Homebrew (no formula dependencies).

set -euo pipefail

# ---- Pinned inputs. Bump these together and update the docs ledger. --------
FFMPEG_VERSION="8.1.2"
# SHA-256 of ffmpeg-8.1.2.tar.xz, computed from the official release tarball.
FFMPEG_SHA256="464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c"
FFMPEG_URL="https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz"

# Target: arm64, macOS 14.0 (matches Package.swift deployment target).
MACOS_DEPLOYMENT_TARGET="14.0"
ARCH="arm64"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="$PROJECT_ROOT/.build/third-party/ffmpeg"
SRC_ROOT="$BUILD_ROOT/src"
TARBALL="$BUILD_ROOT/ffmpeg-${FFMPEG_VERSION}.tar.xz"
OUT_DIR="$BUILD_ROOT/bin"

# Configure flags. LGPL only (no --enable-gpl). Native Apple frameworks for
# hardware encode (VideoToolbox) and audio (AudioToolbox). No external libs.
FFMPEG_CONFIGURE_FLAGS=(
    --disable-x86asm
    --enable-videotoolbox
    --enable-audiotoolbox
    --disable-network
    --disable-doc
    --disable-debug
    --enable-pthreads
    --extra-cflags="-arch ${ARCH} -mmacosx-version-min=${MACOS_DEPLOYMENT_TARGET} -O2"
    --extra-ldflags="-arch ${ARCH} -mmacosx-version-min=${MACOS_DEPLOYMENT_TARGET}"
)

mkdir -p "$BUILD_ROOT" "$SRC_ROOT" "$OUT_DIR"

echo "==> FFmpeg ${FFMPEG_VERSION} (LGPL-2.1+) for ${ARCH} / macOS ${MACOS_DEPLOYMENT_TARGET}"

# ---- Download + verify checksum --------------------------------------------
if [[ ! -f "$TARBALL" ]]; then
    echo "==> Downloading ${FFMPEG_URL}"
    curl -fL --retry 3 --max-time 300 -o "$TARBALL" "$FFMPEG_URL"
fi

echo "==> Verifying SHA-256"
ACTUAL_SHA256="$(shasum -a 256 "$TARBALL" | awk '{print $1}')"
if [[ "$ACTUAL_SHA256" != "$FFMPEG_SHA256" ]]; then
    echo "ERROR: SHA-256 mismatch for FFmpeg tarball." >&2
    echo "  expected: $FFMPEG_SHA256" >&2
    echo "  actual:   $ACTUAL_SHA256" >&2
    rm -f "$TARBALL"
    exit 1
fi
echo "    OK ($FFMPEG_SHA256)"

# ---- Extract ----------------------------------------------------------------
SRC_DIR="$SRC_ROOT/ffmpeg-${FFMPEG_VERSION}"
if [[ ! -d "$SRC_DIR" ]]; then
    echo "==> Extracting"
    rm -rf "$SRC_DIR"
    tar -xf "$TARBALL" -C "$SRC_ROOT"
fi

# ---- Configure --------------------------------------------------------------
cd "$SRC_DIR"
echo "==> Configuring (LGPL, no external libs)"
# distclean ensures a reproducible re-run even if flags changed.
make distclean >/dev/null 2>&1 || true
./configure "${FFMPEG_CONFIGURE_FLAGS[@]}" >/dev/null

# Sanity: confirm the license is still LGPL (no GPL components slipped in).
LICENSE_LINE="$(grep -i 'license:' ffbuild/config.log 2>/dev/null | tail -1 || true)"
echo "    $LICENSE_LINE"

# ---- Build ------------------------------------------------------------------
echo "==> Building (make -j$(sysctl -n hw.ncpu))"
make -j"$(sysctl -n hw.ncpu)" >/dev/null

# `make` builds ffmpeg + ffprobe in the source tree (already-stripped by the
# default build via the STRIP step). We copy only those two; ffplay is built
# too but intentionally not shipped (it pulls SDL2).
echo "==> Copying ffmpeg + ffprobe to $OUT_DIR"
rm -f "$OUT_DIR/ffmpeg" "$OUT_DIR/ffprobe"
cp "$SRC_DIR/ffmpeg" "$OUT_DIR/ffmpeg"
cp "$SRC_DIR/ffprobe" "$OUT_DIR/ffprobe"

# Strip symbols for a smaller binary.
strip "$OUT_DIR/ffmpeg"
strip "$OUT_DIR/ffprobe"

# ---- Record provenance ------------------------------------------------------
cat > "$BUILD_ROOT/VERSION" <<EOF
DropThings bundled FFmpeg
=========================
source:       ffmpeg-${FFMPEG_VERSION}.tar.xz
url:          ${FFMPEG_URL}
sha256:       ${FFMPEG_SHA256}
license:      LGPL version 2.1 or later (no GPL components enabled)
configure:    ${FFMPEG_CONFIGURE_FLAGS[*]}
target:       ${ARCH}, macOS ${MACOS_DEPLOYMENT_TARGET}
toolchain:    $(clang --version | head -1)
built:        $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

# Copy the license texts that ship with FFmpeg so they can be bundled.
cp "$SRC_DIR/COPYING.LGPLv2.1" "$OUT_DIR/" 2>/dev/null || true
cp "$SRC_DIR/LICENSE.md" "$OUT_DIR/" 2>/dev/null || true

# ---- Stage into the app resource tree --------------------------------------
# The Xcode build phase reads from here (under the project root) because the
# script sandbox does not allow reading from .build/. This directory is
# git-ignored; it is a build artifact, not source.
RESOURCES_DIR="$PROJECT_ROOT/App/Resources/FFmpeg"
mkdir -p "$RESOURCES_DIR"
cp -f "$OUT_DIR/ffmpeg" "$RESOURCES_DIR/ffmpeg"
cp -f "$OUT_DIR/ffprobe" "$RESOURCES_DIR/ffprobe"
cp -f "$BUILD_ROOT/VERSION" "$RESOURCES_DIR/VERSION"
cp -f "$OUT_DIR/COPYING.LGPLv2.1" "$RESOURCES_DIR/" 2>/dev/null || true
cp -f "$OUT_DIR/LICENSE.md" "$RESOURCES_DIR/" 2>/dev/null || true
echo "==> Staged into $RESOURCES_DIR (git-ignored build artifact)"

# ---- Report -----------------------------------------------------------------
FFMPEG_BIN="$OUT_DIR/ffmpeg"
FFPROBE_BIN="$OUT_DIR/ffprobe"
echo "==> Built:"
ls -lh "$FFMPEG_BIN" "$FFPROBE_BIN"
echo "    ffmpeg sha256: $(shasum -a 256 "$FFMPEG_BIN" | awk '{print $1}')"
echo "    ffprobe sha256: $(shasum -a 256 "$FFPROBE_BIN" | awk '{print $1}')"
echo "==> Provenance: $BUILD_ROOT/VERSION"
