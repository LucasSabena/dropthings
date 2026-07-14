# New modules integration map

```text
DropThingsCore
  ├─ semantic shortcut values
  ├─ ModuleRegistry / settings / permissions / diagnostics
  ├─ PasteboardHub contracts
  └─ FileActionRegistry contracts

DropThingsMediaKit -> Foundation only
DropThingsTranscriptionKit -> Foundation only
DropThingsDesignSystem -> Core
DropThingsPlatform -> Core + justified kits
DropThingsModules -> Core + DesignSystem + Platform + justified kits
App target -> explicit registration after quality gates
```

## Cross-module behavior without imports

| Producer | Consumer | Boundary |
|---|---|---|
| Session Recorder output | Local Transcription | Core FileActionRegistry |
| Session Recorder output | Media Converter | Core FileActionRegistry |
| Smart Clipboard files/images | Workbench/Converter | Core FileActionRegistry |
| Clipboard History + Smart Clipboard | NSPasteboard | Core PasteboardHub + Platform backend |
| Converter + Transcription + Recorder | Media facts/output/transcode | MediaKit + Platform |
| Recorder active session | Keep-awake behavior | Generic Platform power assertion |

Documentation/source may exist while a module stays excluded from runtime
composition. Registration is the final release action, not the first implementation
step.
