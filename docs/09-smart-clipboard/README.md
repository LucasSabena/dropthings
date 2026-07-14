# Smart Clipboard

A local content-aware action layer for the current clipboard that complements Clipboard History instead of duplicating it.

## Read order

1. `PRODUCT.md`
2. `ARCHITECTURE.md`
3. `EXPERIENCE.md`
4. `IMPLEMENTATION.md`
5. `QUALITY.md`
6. `RESEARCH-AND-LICENSES.md`
7. `AGENT-RUNBOOK.md`

## Definition of done

- One hotkey opens contextual actions for text, URL, JSON, color, file URLs, images and rich text.
- Every transform previews locally; no LLM, hidden mutation or automatic network call.
- Clipboard History and Smart Clipboard together use one observer and create no duplicate/self-trigger loops.
- Users can copy a result, optionally paste it back to the prior app, create a file or invoke compatible registered file actions.
- Diagnostics never include clipboard payloads.

## Platform decision

macOS 14. First introduce one Core PasteboardHub and migrate Clipboard History to it, so both modules share one NSPasteboard observation stream.

## Proposed symbol

`clipboard.fill`
