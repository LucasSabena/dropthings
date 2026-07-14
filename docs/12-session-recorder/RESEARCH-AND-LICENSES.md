# Research and licenses

Research checked on 2026-07-14. Re-verify exact versions, SDK availability and terms
when implementation begins.

## Primary sources and proposed reuse

| Component/source | URL | License/terms | Use |
|---|---|---|---|
| WWDC22 Meet ScreenCaptureKit | `https://developer.apple.com/videos/play/wwdc2022/10156/` | Apple developer material | System audio capture |
| WWDC24 ScreenCaptureKit updates | `https://developer.apple.com/videos/play/wwdc2024/10088/` | Apple developer material | Microphone stream output/recording APIs |
| ScreenCaptureKit | `https://developer.apple.com/documentation/screencapturekit` | Apple SDK terms | Capture |
| AVFoundation | `https://developer.apple.com/documentation/avfoundation` | Apple SDK terms | Microphone/writer/playback |

## Rules

- Pin exact source tag/commit, checksum, build flags and modifications.
- Record every copied/adapted source file, bundled executable, model and fixture.
- Do not ship a binary/model whose source or redistribution rights are unclear.
- Prefer Apple system frameworks for narrow supported operations.
- Never infer capability from extension alone; use runtime/build capability facts.
- Update this file in the same commit that adds or changes a dependency.

## Product-specific cautions

- Persistent status item cannot be hideable while recording; app shell may need a required-while-active visibility policy.
- System and mic must use sample/host timestamps and bounded drift correction—not UI arrival time.
- Suggestions remain off by default and only open preflight; they never request permission or create a file.
- Recording consent/law reminders should be neutral product copy, not legal advice.
