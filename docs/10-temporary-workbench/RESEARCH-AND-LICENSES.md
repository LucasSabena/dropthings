# Research and licenses

Research checked on 2026-07-14. Re-verify exact versions, SDK availability and terms
when implementation begins.

## Primary sources and proposed reuse

| Component/source | URL | License/terms | Use |
|---|---|---|---|
| Apple documents/data/pasteboard | `https://developer.apple.com/documentation/appkit/documents_data_and_pasteboard` | Apple SDK terms | Document/package architecture |
| Core Graphics | `https://developer.apple.com/documentation/coregraphics` | Apple SDK terms | Canvas/export |
| Excalidraw | `https://github.com/excalidraw/excalidraw` | MIT | Interaction research only; no copied code/assets |

## Rules

- Pin exact source tag/commit, checksum, build flags and modifications.
- Record every copied/adapted source file, bundled executable, model and fixture.
- Do not ship a binary/model whose source or redistribution rights are unclear.
- Prefer Apple system frameworks for narrow supported operations.
- Never infer capability from extension alone; use runtime/build capability facts.
- Update this file in the same commit that adds or changes a dependency.

## Product-specific cautions

- Autosave must never write every pointer sample or replace a valid package with a partial one.
- Unknown future item types should be preserved or opened read-only, not silently discarded.
- Undo/image memory needs strict budgets and downsampling.
- Do not commit private/client assets as fixtures.
