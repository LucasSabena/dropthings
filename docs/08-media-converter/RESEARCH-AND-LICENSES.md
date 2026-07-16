# Research and licenses

Research checked on 2026-07-14. Re-verify exact versions, SDK availability and terms
when implementation begins.

## Primary sources and proposed reuse

| Component/source | URL | License/terms | Use |
|---|---|---|---|
| Apple media frameworks | `https://developer.apple.com/documentation/` | Apple SDK terms | Native probe/encode paths |
| FFmpeg formats | `https://ffmpeg.org/ffmpeg-formats.html` | Documentation | Capability research |
| FFmpeg legal | `https://ffmpeg.org/legal.html` | LGPL-2.1+ or GPL depending build | Broad media helper |

## Rules

- Pin exact source tag/commit, checksum, build flags and modifications.
- Record every copied/adapted source file, bundled executable, model and fixture.
- Do not ship a binary/model whose source or redistribution rights are unclear.
- Prefer Apple system frameworks for narrow supported operations.
- Never infer capability from extension alone; use runtime/build capability facts.
- Update this file in the same commit that adds or changes a dependency.

## Product-specific cautions

- FFmpeg must be pinned and reproducibly built; publish exact source, configure line, patches, checksums and notices.
- Do not expose a setting the chosen backend ignores.
- Do not finalize an output before successful re-probe.
- Replace-original stays disabled until rollback/recovery is proven.

## Current implementation state (2026-07-15)

The module is fully implemented across all phases (0–4) and registered in
`AppServices`. FFmpeg is reproducibly built and bundled.

- **Native image conversion** (PNG/JPEG/HEIC/TIFF) ships through ImageIO/CoreGraphics adapters in `Sources/DropThingsPlatform/Media/`. The current macOS ImageIO destination list does not provide a WebP encoder, so WebP is not exposed. No third-party dependency; covered by Apple SDK terms.
- **`DropThingsMediaConverterKit`** (Foundation-only) holds the typed models, preset resolver, resize math, the typed FFmpeg argument builder (argument arrays, never shell strings), and the XPC wire protocol.
- **`MediaConverterEngine`** XPC helper (mirrors `AudioControlEngine`) runs FFmpeg in an isolated process so a codec crash can never terminate DropThings. Embedded at `Contents/XPCServices/MediaConverterEngine.xpc`.
- **Audio/video conversion** runs through the helper: `MediaConverterPipeline` routes audio/video requests to the helper via `XPCMediaConverterEngineClient`; the helper builds typed argv arrays with `FFmpegArgumentBuilder` and runs the bundled binary with `Process` (never a shell).

## Bundled FFmpeg — pinned provenance

Built by `scripts/build-ffmpeg.sh`. Reproducible: same source + same clang produces byte-identical archives (modulo the linker's build timestamp).

| Field | Value |
|---|---|
| Source | `ffmpeg-8.1.2.tar.xz` |
| Source URL | `https://ffmpeg.org/releases/ffmpeg-8.1.2.tar.xz` |
| Source SHA-256 | `464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c` |
| License | **LGPL version 2.1 or later** (no `--enable-gpl`; no GPL components) |
| Target | `arm64`, `macOS 14.0` |
| Toolchain | Apple clang 21.0.0 (Xcode 26.6) |
| External libraries | **None** — links only Apple system frameworks (VideoToolbox, AudioToolbox, CoreMedia, AVFoundation, etc.) |
| Patches | None |

### Configure line

```
./configure \
  --disable-x86asm \
  --enable-videotoolbox \
  --enable-audiotoolbox \
  --disable-network \
  --disable-doc \
  --disable-debug \
  --enable-pthreads \
  --extra-cflags="-arch arm64 -mmacosx-version-min=14.0 -O2" \
  --extra-ldflags="-arch arm64 -mmacosx-version-min=14.0"
```

### Produced binaries (SHA-256)

These are recomputed on every `scripts/build-ffmpeg.sh` run; the values below
are from the build used to stage this release:

| Binary | SHA-256 |
|---|---|
| `ffmpeg` | `f7bb270f590464a35ae115679f329f8b3964bb5015b047de3f1d48f678a3068b` |
| `ffprobe` | `add4921de258494d0a06b452337fcec6801e87184058ac2adf8142d76269849a` |

> Binaries are not committed to git (21 MB each, build artifacts). The full
> provenance record is regenerated at `.build/third-party/ffmpeg/VERSION` and
> staged into the bundle at `Contents/SharedSupport/FFmpeg/VERSION` alongside
> `COPYING.LGPLv2.1`.

### Capabilities of this build

Because no external libraries are linked, capability is narrower than a full
FFmpeg build. This is reflected truthfully in `MediaCapabilityManifest.shipped`
so the UI never offers a conversion the backend cannot perform:

| Family | Encoders available | Not available (needs external lib) |
|---|---|---|
| Image | PNG, JPEG, HEIC, TIFF (native ImageIO) | WebP (no verified encoder in the shipped backend) |
| Audio | AAC (native), FLAC, Opus (native), PCM/WAV | MP3 (needs `libmp3lame`) |
| Video | H.264 via `h264_videotoolbox` | HEVC is not exposed in 0.7.0; VP8/VP9/WebM needs `libvpx`; software H.264 needs GPL `libx264` |

Containers/muxers available: MP4, MOV, Matroska/MKV, WAV, FLAC, Ogg/Opus.

### Rebuilding

```
scripts/build-ffmpeg.sh          # builds + stages into App/Resources/FFmpeg
```

The Xcode build phase "Embed FFmpeg" (target `MediaConverterEngine`) copies the
staged binary into `MediaConverterEngine.xpc/Contents/SharedSupport/FFmpeg/`
on every build. On a fresh checkout without the staged binary, the phase is a
no-op and `BundledFFmpegResolver` reports `.unavailable`.
