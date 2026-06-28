# Project-Local Skills

Skills installed into this project only:

```text
.codex/skills/security-best-practices
.codex/skills/security-threat-model
.codex/skills/figma-create-design-system-rules
.codex/skills/playwright
```

## Why These Skills

`security-best-practices`:

- Use before implementing permission-heavy modules.
- Helps review local data handling, dependency risk, and secure defaults.

`security-threat-model`:

- Use before implementing Scroll Control and Menu Bar Cleaner.
- These modules touch input events and high-trust macOS permissions.

`figma-create-design-system-rules`:

- Use if design work moves into Figma.
- Helps keep tokens and component rules consistent.

`playwright`:

- Use for web prototypes, docs previews, or future landing/demo surfaces.
- Not the primary test tool for native macOS behavior.

## Skill Rule

Use project-local skills first when a task matches them. Do not install global skills for this project unless explicitly requested.

