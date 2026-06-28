# Design System

## Design Direction

DropThings should feel like a focused macOS control center: native, compact, calm, and trustworthy. It should not feel like a marketing dashboard or a web SaaS admin panel.

## Token Strategy

Create tokens in Swift first, using `docs/design-tokens.json` as the canonical seed. Mirror them in design files or prototypes if needed.

```swift
enum DTColor {
    static let accent = Color("Accent")
    static let background = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let surfaceRaised = Color(nsColor: .textBackgroundColor)
    static let border = Color(nsColor: .separatorColor)
    static let textPrimary = Color(nsColor: .labelColor)
    static let textSecondary = Color(nsColor: .secondaryLabelColor)
    static let success = Color("Success")
    static let warning = Color("Warning")
    static let danger = Color("Danger")
}

enum DTSpace {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum DTRadius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 6
    static let lg: CGFloat = 8
}
```

## Core Tokens

Spacing:

- `xxs`: 2
- `xs`: 4
- `sm`: 8
- `md`: 12
- `lg`: 16
- `xl`: 24
- `xxl`: 32

Radius:

- `sm`: 4
- `md`: 6
- `lg`: 8

Typography:

- Use system fonts.
- Settings title: `.title2` or equivalent.
- Section title: `.headline`.
- Body: `.body`.
- Help text: `.callout` or `.footnote`.
- Do not scale font size with viewport width.

Color:

- Prefer semantic macOS colors.
- Use accent sparingly for active module states and primary actions.
- Use warning/danger only for permission or destructive actions.
- Support light, dark, increased contrast, and reduce transparency.

## Layout Rules

- Main settings window uses a sidebar plus detail pane.
- Module list uses compact rows or shallow cards, not nested card stacks.
- Each module detail page starts with status, primary enable toggle, and permission state.
- Advanced settings sit below core controls.
- Permission explanations appear next to the action that needs them.

## Component Inventory

- `ModuleRow`: module icon, name, short summary, status, enable toggle.
- `ModuleStatusPill`: running, off, needs permission, failed, unavailable.
- `PermissionRow`: permission name, reason, state, action.
- `SettingsSection`: title, optional caption, grouped controls.
- `TokenizedButton`: native button variants with consistent spacing.
- `InlineAlert`: compact warning/error/success messaging.
- `DiagnosticsPanel`: module health and logs.

## Icon Rules

- Prefer SF Symbols in SwiftUI.
- Each module gets one clear symbol:
  - Scroll Control: `scroll`.
  - File Shelf: `tray.and.arrow.down`.
  - Menu Bar Cleaner: `menubar.rectangle`.
- Avoid decorative icons where a standard symbol communicates the action.

## Lazyweb Gate

Before designing or changing product UI:

1. Use Lazyweb.
2. For greenfield screens, route through `lazyweb-design` with `objective=create` or fetch `lazyweb-design-create`.
3. Record the workflow/result in `docs/research/lazyweb.md`.
4. Translate findings into tokens/components here.
