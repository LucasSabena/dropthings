# Research and licenses

Research checked on 2026-07-14. Re-verify exact versions, SDK availability and terms
when implementation begins.

## Primary sources and proposed reuse

| Component/source | URL | License/terms | Use |
|---|---|---|---|
| NSPasteboard | `https://developer.apple.com/documentation/appkit/nspasteboard` | Apple SDK terms | Pasteboard backend |
| Uniform Type Identifiers | `https://developer.apple.com/documentation/uniformtypeidentifiers` | Apple SDK terms | Typed representations |
| Accessibility | `https://developer.apple.com/documentation/applicationservices/accessibility` | Apple SDK terms | Optional paste automation |

## Rules

- Pin exact source tag/commit, checksum, build flags and modifications.
- Record every copied/adapted source file, bundled executable, model and fixture.
- Do not ship a binary/model whose source or redistribution rights are unclear.
- Prefer Apple system frameworks for narrow supported operations.
- Never infer capability from extension alone; use runtime/build capability facts.
- Update this file in the same commit that adds or changes a dependency.

## Product-specific cautions

- Two pasteboard observers or content-hash-only deduplication will create races/duplicates.
- Accessibility must remain optional for basic use.
- Ambiguous strings must retain general text actions.
- Logs/crash diagnostics must contain only type, size and action IDs—not content.
