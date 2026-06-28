# Lazyweb Notes

## 2026-06-28

Task: plan design work for DropThings, a new macOS productivity utility hub.

Result:

- Called `lazyweb_generate_report` with `objective=create`.
- Lazyweb returned a redirect because greenfield screens use the `lazyweb-design-create` workflow rather than the screenshot-based optimize/improve report pipeline.
- Fetched `lazyweb-design-create` workflow instructions through `lazyweb_get_workflows`.

Design implication:

- Before building concrete settings screens, run the greenfield Lazyweb workflow or use Lazyweb references for each screen archetype:
  - macOS utility settings.
  - module control center.
  - permission onboarding.
  - diagnostics screen.
  - file shelf surface.

Current Lazyweb version:

- Installed: `0.13.3`.
- Available according to the tool instructions: `0.13.7`.

Suggested update:

```bash
curl -fsSL https://www.lazyweb.com/install.sh | sh
```

## 2026-06-28 - New Module Audit Note

Task: audit and plan improvements for Keep Awake, Color Picker, Screenshot,
and permission diagnostics.

Result:

- No product UI was implemented in this pass.
- Created planning docs under `docs/modulos/`.
- Before implementing the advanced picker, screenshot editor, or revised
  permission screens, run the Lazyweb design workflow and record the concrete
  findings here.

## 2026-06-28 - Module Repair Pass

Task: repair confusing module UX for File Shelf, Scroll Control, Menu Bar
Cleaner, Color Picker, hotkeys, and remove Screenshot from the active app.

Workflow note:

- No Lazyweb MCP tool is available in this session, so this pass used the
  existing Lazyweb gate note plus targeted open-source/product research.
- Reviewed temporary local clones of:
  - LinearMouse: scroll event tap architecture and complete scroll delta writes.
  - Scroll Reverser: practical mouse vs trackpad heuristics using continuous
    events, phases, and gesture context.
  - Hidden Bar: divider-length overflow model, Command-drag setup, and
    widest-screen collapse length.
  - Ice: modern menu bar manager constraints, status item discovery, and
    menu-bar UX expectations.
- Checked Apple API direction for replacing the custom color picker overlay
  with `NSColorSampler` and for using an all-spaces utility `NSPanel`.

Design implication:

- Prefer honest, direct controls over technical lists. Menu Bar Cleaner should
  behave like a visible divider + chevron overflow, not a fragile per-process
  AX toggle list.
- Hotkeys must show the current shortcut as a first-class value and keep
  "change" separate from "clear".
- Color Picker should use the native macOS sampler before building a custom
  magnifier/capture flow.
- File Shelf should appear near the pointer when summoned by shake/hotkey and
  stay available across Spaces.
- Screenshot is removed from the active module set until it can be rebuilt as
  a useful region capture/editor.

## 2026-06-28 - Startup and Accessibility Repair

Task: add a global startup setting and make stuck Accessibility permissions
recoverable from the app.

Workflow note:

- No Lazyweb MCP tool is available in this session.
- Followed the existing macOS utility settings pattern already recorded above:
  app-wide controls live in a General settings pane, and permission repair
  belongs in Diagnostics where the user can see what macOS currently sees.

Design implication:

- The startup control should be a plain switch backed by macOS Login Items,
  with status text and a direct path to System Settings when approval is needed.
- Accessibility repair should explain the stale-permission state in human
  language and offer a single repair action instead of forcing Terminal use.
