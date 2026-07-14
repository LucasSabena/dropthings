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
