# Command Palette

This folder is the source of truth for the DropThings Spotlight replacement.
The product is a local universal launcher, not a clone of the full Raycast
platform.

## Read order

1. `PRODUCT.md` — promised behavior and explicit non-goals.
2. `ARCHITECTURE.md` — boundaries, data flow, and proposed types.
3. `EXPERIENCE.md` — interaction and visual contract.
4. `IMPLEMENTATION.md` — ordered vertical slices and completion gates.
5. `QUALITY.md` — automated and manual verification.
6. `RESEARCH-AND-LICENSES.md` — evidence, references, and reuse ledger.
7. `AGENT-RUNBOOK.md` — mandatory workflow for implementation agents.

## Product definition

One global shortcut opens a fast search surface on the display the user is
currently using. A single query can return installed applications, DropThings
module commands, files and folders indexed by Spotlight, calculations, and a
small curated set of system actions. An opt-in web result can send an explicit
search to the user's selected browser and search engine.

## Definition of done

The module replaces Spotlight/Raycast root search for the owner's daily use
when all of the following are true:

- It opens reliably over normal windows, Spaces, Stage Manager, and full-screen
  apps on every connected display.
- Apps and module commands appear immediately; file results stream in without
  blocking typing.
- Ranking learns from local usage and remains deterministic enough to test.
- Calculator results can be copied or executed without changing mode.
- Every result has appropriate keyboard actions and clear failure feedback.
- No network, account, extension store, AI feature, or telemetry is required;
  web search is optional and disabled by default.

## Implemented baseline — 2026-07-13

The prototype was replaced with a provider-based module containing application
cataloguing, module/system commands, a safe calculator, Spotlight-backed files,
deterministic fuzzy ranking, bounded local history, active-display placement,
result actions, application visibility/pinning, and opt-in web search.

## Delivery order

1. Make the existing target and tests build normally.
2. Apps + module commands + active-display placement.
3. Calculator + ranking/history.
4. Spotlight files/folders + actions/Quick Look.
5. Pinned/selected applications + configurable web search.
6. Reliability and latency pass across display/Space configurations.
