# DropThings

> One native macOS app. Many small system tools. Each one small, focused,
> and respectful of your privacy.

DropThings is a PowerToys-style utility hub for macOS. Every feature is a
small module you can enable or disable independently. No telemetry, no
accounts. Update checks contact GitHub Releases only when automatic checks
are enabled or when you click **Check for Updates**.

![hero](docs/hero.png)

---

## Features

| Module | What it does | Permission |
|---|---|---|
| **File Shelf** | Drop files here. Pick them up in any app. Pin items to keep them across restarts. | — |
| **Scroll Control** | Natural scroll on the trackpad, Windows-style wheel on the mouse. Independent direction per device. | Accessibility |
| **Menu Bar Cleaner** | Collapse low-priority menu bar icons behind one visible control. | — |
| **Keep Awake** | One toggle. Mac stays awake as if you were using it. | — |
| **Color Picker** | Pick any color with the native macOS sampler. Hex on the clipboard. Persistent history. | — |

Every module:

- **Asks for permission only when needed.** A permission prompt only
  appears when you enable a feature that uses it. Toggle the feature off
  and the permission can be revoked any time.
- **Is independently disable-able.** Turn one module off without
  affecting the others.
- **Surfaces failures in the UI.** A module that fails its job moves to a
  `degraded` state with an inline message — never silent.

---

## Install

Requires **macOS 14 Sonoma or later**.

### Homebrew (recommended)

```bash
brew tap LucasSabena/dropthings https://github.com/LucasSabena/dropthings
brew install --cask LucasSabena/dropthings/dropthings
```

DropThings is distributed as a Homebrew Cask because it installs a macOS
`.app` bundle.

### One-line installer

```bash
curl -fsSL https://raw.githubusercontent.com/LucasSabena/dropthings/main/scripts/install.sh | sh
```

Downloads the latest release `.dmg` or `.zip` from GitHub and installs to
`/Applications/DropThings.app`. Override the destination with
`DROPTHINGS_INSTALL_PATH=~/Apps sh ...`.

### Manual

1. Download the latest `DropThings-x.y.z.dmg` from
   [Releases](https://github.com/LucasSabena/dropthings/releases).
2. Open the DMG.
3. Drag `DropThings.app` into `/Applications`.
4. The first time you launch it, macOS asks you to right-click → Open →
   Open. Subsequent launches are normal.

### Build from source

```bash
git clone https://github.com/LucasSabena/dropthings.git
cd dropthings
xcodebuild -project App.xcodeproj -scheme DropThings \
           -configuration Release -derivedDataPath .build/release build
./.build/release/build/Products/Release/DropThings.app
```

---

## Permissions

DropThings does **not** request permissions on launch. Each module asks for
the permission it needs only when you enable that module.

| Module | Permission | Why it needs it |
|---|---|---|
| Scroll Control | Accessibility | Read and rewrite scroll events |
| Menu Bar Cleaner | — | Uses DropThings-owned menu bar controls |
| Color Picker | — | Uses the native macOS color sampler |

If a module says it needs a permission but the system does not seem to know
about DropThings:

```bash
tccutil reset Accessibility app.dropthings
```

Then quit DropThings and reopen it. The Settings → **Diagnostics** panel
shows the bundle path DropThings is running from, so you can compare it
against the path System Settings has on file.

---

## Usage

Once installed, DropThings lives in the menu bar. Click the icon to open
the menu:

- **Open Settings…** — the main configuration window
- **Show File Shelf** (when the File Shelf module is enabled) — opens the shelf
- **Quit DropThings**

Inside **Settings**, the sidebar lists each module. Click one to see its
state, its settings, and its required permissions. Enable or disable with
the toggle in the row.

Settings → **About** shows the current version and update state. Use
**Check for Updates** to fetch the latest GitHub Release, read its changelog,
and open the download. Automatic checks run at most once a day and can be
disabled from the same About screen. Homebrew users can update with:

```bash
brew upgrade --cask LucasSabena/dropthings/dropthings
```

Quick walkthroughs per module:

- [File Shelf](docs/file-shelf-manual-checks.md)
- [Scroll Control](docs/scroll-control-manual-checks.md)
- [Menu Bar Cleaner](docs/menu-bar-cleaner-manual-checks.md)
- [Color Picker](docs/color-picker-manual-checks.md)

---

## Architecture

DropThings is structured so each module is self-contained and the
infrastructure is shared.

```
DropThings/
  App/                       # macOS app target (Info.plist, entitlements)
  Sources/
    DropThingsCore/          # registry, settings, permissions, diagnostics
    DropThingsDesignSystem/  # tokens + shared components
    DropThingsPlatform/      # fragile macOS adapters (CGEventTap, AX, IOPower, ...)
    DropThingsModules/       # one folder per feature
  Tests/                     # swift test, runs via `swift test`
```

The dependency graph is one-way: `Core` is the base, `DesignSystem` and
`Platform` build on it, and `Modules` consumes all three. Modules never
import each other.

See [`docs/decisions.md`](docs/decisions.md) for the durable design
decisions and [`docs/architecture.md`](docs/architecture.md) for the
detailed contract.

---

## Development

```bash
swift test                                            # 65+ unit tests
xcodebuild -project App.xcodeproj -scheme DropThings \
           -configuration Debug -derivedDataPath .build/xcode build
open .build/xcode/Build/Products/Debug/DropThings.app
```

Before opening a pull request, run `swift test` and confirm everything
passes. New modules need to:

- Live under `Sources/DropThingsModules/<Name>/`
- Implement `DropThingsModule` (see `Sources/DropThingsCore/DropThingsModule.swift`)
- Have at least one unit test under `Tests/DropThingsModulesTests/<Name>/`
- Document manual checks in `docs/<name>-manual-checks.md`
- Mark each completion in [`docs/implementation-checklist.md`](docs/implementation-checklist.md)

See [`docs/modulos/`](docs/modulos/) for the per-module audits and the
forward-looking backlog.

---

## Roadmap

Next on the queue (in priority order):

1. **Clipboard History** — global hotkey, persistent history, exclusion list for sensitive apps.
2. **Command Palette** — single hotkey to invoke any module's actions.
3. **Color Picker Pro** — magnifier, formats (HEX/RGB/HSL), similar colors.
4. **Window Snapper** — Rectangle-style halves, quarters, maximize.
5. **Focus / Presentation Mode** — workflow that orchestrates existing modules.
6. **Screenshot Studio** — deferred until region capture and annotation UX are worth shipping.

Full backlog with rationale: [`docs/modulos/backlog-modulos-futuros.md`](docs/modulos/backlog-modulos-futuros.md).

---

## License

MIT. See [`LICENSE`](LICENSE).

## Contributing

PRs welcome. Open an issue first if you want to discuss before you build.
Big changes (new module, new permission model) should come with an
`auditoria.md` describing the proposal before code lands.
