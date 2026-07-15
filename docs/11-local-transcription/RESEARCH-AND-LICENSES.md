# Research and licenses

Research checked on 2026-07-14. Re-verify exact versions, SDK availability and terms
before bundling any artifact.

## Primary sources and proposed reuse

| Component/source | URL | License/terms | Use |
|---|---|---|---|
| whisper.cpp v1.9.1, commit `f049fff95a089aa9969deb009cdd4892b3e74916` | `https://github.com/ggml-org/whisper.cpp/releases/tag/v1.9.1` | MIT | Official XCFramework, C API and Metal backend; the app ships its arm64 slice |
| OpenAI Whisper | `https://github.com/openai/whisper` | MIT code and model weights | User-downloaded models |
| FFmpeg | `https://ffmpeg.org/` | LGPL/GPL depending build | Proposed for Phase 2; not added |

## Pinned Phase 1 model manifest

Files are fetched only after an explicit user action from the whisper.cpp model
repository at `https://huggingface.co/ggerganov/whisper.cpp`. The recorded digest is
the SHA-256 LFS object identifier exposed by the host and is verified over the
downloaded bytes before installation.

| Model | File | Bytes | SHA-256 |
|---|---|---:|---|
| Tiny multilingual | `ggml-tiny.bin` | 77,691,713 | `be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21` |
| Base multilingual | `ggml-base.bin` | 147,951,465 | `60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe` |
| Small multilingual | `ggml-small.bin` | 487,601,967 | `1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b` |

## Reuse ledger

- No whisper.cpp, Whisper or FFmpeg source file has been copied into this repository.
- SwiftPM fetches the upstream `whisper-v1.9.1-xcframework.zip` release asset. Its
  pinned archive SHA-256 is
  `8c3ecbe73f48b0cb9318fc3058264f951ab336fd530e82c4ccdd2298d1311a4c`.
- The app embeds the upstream `whisper.framework` only inside
  `TranscriptionEngine.xpc`; model files and test fixtures are not bundled.
- `TranscriptionEngine/ThirdPartyNotices.txt` ships the upstream copyright and
  complete MIT license alongside the framework.
- Metal is enabled. Core ML remains optional and is not distributed because its
  generated model artifact is not part of this reproducible package.

## Rules

- Pin exact source tag/commit, checksum, build flags and modifications.
- Record every copied/adapted source file, bundled executable, model and fixture.
- Do not ship a binary/model whose source or redistribution rights are unclear.
- Prefer Apple system frameworks for narrow supported operations.
- Never infer capability from extension alone; use runtime/build capability facts.
- Update this file in the same commit that adds or changes a dependency.

## Product-specific cautions

- Pin exact whisper.cpp/model/VAD artifacts, versions, checksums, licenses and build flags.
- Do not claim resume unless a real checkpoint format exists; interrupted jobs restart honestly.
- Core ML is optional until generation/distribution is reproducible.
- Do not add diarization without separate model/license/privacy research.
