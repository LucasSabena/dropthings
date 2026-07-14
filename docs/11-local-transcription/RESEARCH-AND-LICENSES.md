# Research and licenses

Research checked on 2026-07-14. Re-verify exact versions, SDK availability and terms
when implementation begins.

## Primary sources and proposed reuse

| Component/source | URL | License/terms | Use |
|---|---|---|---|
| whisper.cpp | `https://github.com/ggml-org/whisper.cpp` | MIT | Local inference helper |
| OpenAI Whisper | `https://github.com/openai/whisper` | MIT code and model weights | User-downloaded models |
| FFmpeg | `https://ffmpeg.org/` | LGPL/GPL depending build | Broad decode/normalization |

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
