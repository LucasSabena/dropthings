# Roadmap

## Phase 0: Foundation

- Create the native macOS project.
- Define app identity, bundle ID, signing approach, and supported macOS version.
- Implement app lifecycle and menu bar extra.
- Implement settings storage with typed keys and migrations.
- Implement the module registry.
- Implement design tokens and base controls.
- Add logging and diagnostics.

Exit criteria:

- The app launches as a menu bar utility.
- A settings window opens.
- Fake modules can register, render settings, and be enabled or disabled.

## Phase 1: File Shelf

- Build a floating `NSPanel` shelf.
- Accept dropped files, folders, text, URLs, and images.
- Show items with compact previews.
- Allow dragging items back out.
- Add pin, clear, remove item, reveal in Finder, and copy path actions.
- Persist pinned items only; temporary items clear on quit unless configured.

Exit criteria:

- User can drag files into the shelf, switch apps, and drag them out.
- Shelf works across Spaces as much as macOS allows.
- Denied file access and stale bookmarks fail gracefully.

## Phase 2: Scroll Control

- Implement a CoreGraphics event tap adapter.
- Detect trackpad, Magic Mouse, and physical wheel devices where possible.
- Allow separate natural/inverted scroll direction per device category.
- Add optional scroll speed and horizontal scroll controls.
- Handle event tap timeout and re-enable behavior.

Exit criteria:

- Trackpad natural scroll and mouse Windows-style wheel scroll can coexist.
- Disabling the module restores untouched system behavior.
- Accessibility permission denial shows a useful recovery state.

## Phase 3: Menu Bar Cleaner

- Study Ice and Hidden Bar behavior deeply.
- Implement a reveal/hide controller with a menu bar separator item.
- Support a visible divider and collapsible hidden side.
- Support temporary reveal by click or hover.
- Add reset and troubleshooting actions.
- Handle notch, small screens, Control Center, and macOS version differences.

Exit criteria:

- User can hide non-critical menu bar items and reveal them predictably.
- The module does not require high-trust permissions for the basic overflow.
- The module has a documented compatibility matrix.

## Phase 4: Polish And Reliability

- Add first-run onboarding focused on enabling one module.
- Add diagnostics screen for permissions and module health.
- Add import/export of settings.
- Add update mechanism if distributing outside the App Store.
- Add crash reporting only if privacy-respecting and opt-in.
- Add release checklist and signed builds.

## Phase 5: Future Modules

Candidate modules:

- Clipboard history.
- Color Picker Pro.
- Menu Bar Cleaner / Hide Bar Pro.
- Screenshot Studio.
- Window snapping.
- Quick launcher / command palette.
- Text tools.
- Recent downloads shelf.
- Focus / presentation mode.
- App/window switcher.

See `docs/modulos/backlog-modulos-futuros.md` for priority, module scope,
permissions, and integration notes.
