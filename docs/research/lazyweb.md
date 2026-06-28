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
