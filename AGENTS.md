# DropThings Agent Rules

## Project Intent

DropThings is a native macOS utility hub: one app, many small system tools, built like a modular PowerToys for macOS. Every contribution must preserve that shape: a small core, isolated modules, shared design tokens, and clear permission boundaries.

## Non-Negotiables

- Never use `npm`. If JavaScript tooling appears, use `pnpm` only.
- Keep code componentized. Features belong in modules, shared behavior belongs in core, and UI primitives belong in the design system.
- Prefer Swift, SwiftUI, and AppKit for the app. Use lower-level macOS APIs only behind small adapters.
- Keep files and functions short. Split long functions when they mix concerns, branches, permissions, state, and UI.
- Do not create abstractions for imaginary future needs. Create them when two real modules need the same shape.
- Do not copy code from open-source projects unless the license is compatible and the copied code is explicitly tracked in `docs/research/open-source-references.md`.
- Do not store secrets, tokens, signing identities, provisioning profiles, or private certificates in git.

## Quality Loop

Before committing any implementation, each agent must pause and ask internally:

1. Is this code simpler than the problem deserves, or did I make it clever?
2. Is each type doing one job?
3. Can a future module reuse this without knowing private details?
4. Are permissions requested only when the user enables the module that needs them?
5. Is the UI using shared tokens instead of one-off colors, spacing, or typography?
6. Does this behave well when the permission is denied, revoked, or unavailable on this macOS version?
7. Is the code testable without real system hooks where possible?

If the answer is weak, improve the design before moving on.

## Architecture Rules

- `Core` owns module registration, app lifecycle, settings storage, permission state, logging, and shared services.
- `Modules` own feature behavior. A module must expose a small interface: metadata, lifecycle, settings view, permission needs, and health state.
- `DesignSystem` owns tokens, shared controls, icons, window styles, and common layout components.
- `Platform` owns wrappers for AppKit, CoreGraphics, Accessibility, IOKit, Launch Services, and system APIs.
- Modules may depend on `Core`, `DesignSystem`, and `Platform`; modules must not depend on each other directly.
- Cross-module workflows go through explicit core services or events.

## Design Rules

- Use the design tokens in `docs/design-system.md` before adding any visual constant.
- The app should feel native, compact, trustworthy, and calm.
- Do not make marketing screens inside the app. The first screen is the usable control center.
- Every module needs enabled, disabled, missing-permission, error, and unavailable states.
- Prefer clear labels, native controls, and short explanations at permission boundaries.
- Before designing or changing product UI, use Lazyweb first and record the result or workflow note in `docs/research/lazyweb.md`.

## Implementation Rules

- Build the smallest vertical slice that works end to end before expanding it.
- Hide fragile macOS APIs behind adapters with narrow interfaces.
- Avoid global mutable state. When unavoidable for macOS callbacks, isolate it and document why.
- Use dependency injection for services that touch permissions, event taps, file system state, or menu bar state.
- Use structured settings models with migrations; do not scatter `UserDefaults` keys.
- Prefer explicit errors over silent failure.
- Add tests for pure logic and adapters where feasible. Manual verification steps must be documented for privileged macOS behavior.

## Documentation Rules

- Update docs in the same change that changes architecture, module behavior, permissions, or design tokens.
- Keep docs actionable. Prefer checklists, decisions, and constraints over broad essays.
- If a tradeoff is important, record it in `docs/decisions.md`.

