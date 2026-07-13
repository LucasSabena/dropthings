# Manual Verification Guide

Run after changes to the app shell, permissions, shortcuts, or a shipping
module. Automated tests cover pure logic; these checks cover real macOS APIs.

## 0. Build

```bash
swift test
xcodebuild -project App.xcodeproj -scheme DropThings \
  -configuration Debug -derivedDataPath .build/xcode build
```

- [ ] Both commands finish with zero failures.
- [ ] The app has a menu bar icon and no Dock icon.
- [ ] Quit removes the process, event taps, hotkeys, and power assertions.

## 1. Control center

- [ ] First launch opens the usable Control Center, not a welcome screen.
- [ ] Sidebar shows Control Center, Permissions, Settings, About, and exactly:
      File Shelf, Clipboard History, Color Picker, Scroll Control, Keep Awake,
      Markdown Viewer.
- [ ] Each row shows one clear state, one toggle, and one detail action.
- [ ] Retired modules never appear in the window or menu bar.
- [ ] Light/dark mode, Increase Contrast, and Reduce Transparency remain legible.
- [ ] Full Keyboard Access can reach navigation, toggles, and recovery actions.

## 2. Permissions

- [ ] Fresh launch triggers no TCC prompt.
- [ ] Enabling Scroll Control without Accessibility opens the in-app explanation
      before macOS asks anything.
- [ ] Choosing Not Now during first enable turns Scroll Control back off.
- [ ] Continue triggers the native request. If access remains missing, the sheet
      names `Privacy & Security → Accessibility` and opens that pane.
- [ ] Grant access and return → DropThings rechecks automatically and Scroll
      Control becomes Ready without another toggle cycle.
- [ ] Revoke access while running → the event tap stops and status changes to
      Permission.
- [ ] Disable/re-enable after denial → state remains Needs attention; it does not
      incorrectly become Not requested.
- [ ] Permissions lists no Screen Recording, Full Disk Access, or Automation
      requirement for the six shipping modules.

## 3. File Shelf

- [ ] `⌥⌘S` opens the shelf and a second press/click-away hides it.
- [ ] Drag files, folders, text, images, videos, and documents in and back out.
- [ ] Real thumbnails and Quick Look render; folder/file metadata is correct.
- [ ] ⌘-click and ⇧-click selection plus batch Reveal/Copy Paths/Remove work.
- [ ] Pin survives relaunch; unpinned content respects Clear on Quit.
- [ ] List/grid, collections, flick, and optional shake behave as configured.
- [ ] Shortcut conflict reports Limited and a valid rebind recovers immediately.

## 4. Clipboard History

- [ ] `⌥⌘V` opens the panel with search focused.
- [ ] Copy text, URL, Color Picker color, raw image, image file, video, document,
      and folder → correct visual row/filter/preview appears.
- [ ] Single click only previews; Return or Paste executes.
- [ ] Quick Look, Reveal, drag-out, pin, delete, and Copy work.
- [ ] Command-click and Shift-click select multiple shelf items in list and grid.
- [ ] Dragging one selected item into Finder carries every selected file/folder.
- [ ] **Delete** and **Remove Selected** remove the complete selection only.
- [ ] Text, colors, files, and raw images survive quit/relaunch and replacing
      `/Applications/DropThings.app`; current disk usage remains below the limit.
- [ ] Unpinned content older than the configured retention is removed; pinned
      and favorite content remains.
- [ ] With Accessibility absent, Return copies and never opens a permission prompt.
- [ ] Concealed/transient entries and configured password managers are ignored.

## 5. Color Picker

- [ ] `⌥⌘C` and Pick Color open the native sampler without freezing the cursor.
- [ ] Click copies native color plus configured string and shows feedback.
- [ ] Clipboard History renders the new item as a visual swatch.
- [ ] Format, history limit, favorites, and custom shortcut persist.
- [ ] Disable releases the shortcut.

## 6. Scroll Control

- [ ] With Accessibility allowed, physical wheel direction can differ from the
      trackpad and Magic Mouse.
- [ ] Horizontal toggle and multiplier affect only configured paths.
- [ ] Per-app override applies to the correct foreground bundle.
- [ ] Pause/resume shortcut works; temporary pause does not silently enable
      Start Paused for the next launch.
- [ ] Moving the speed slider applies continuously without disabling/recreating
      the scroll listener.
- [ ] Disable restores untouched system scrolling immediately.

## 7. Keep Awake

- [ ] Enable → `pmset -g assertions` shows the DropThings system assertion.
- [ ] "Also keep the display awake" adds/removes the display assertion live.
- [ ] A short timed session expires and releases every assertion.
- [ ] Relaunch during a timed session preserves its original end time; relaunch
      after expiration does not reactivate it.
- [ ] Disable or quit releases every active assertion.

## 8. Settings and updates

- [ ] Login Item toggle reflects enabled/requires-approval/error states.
- [ ] Export, change, import → relaunch restores the exported values.
- [ ] Copy Diagnostics contains version, path, and permission state but no
      clipboard contents or shelf paths.
- [ ] Check for Updates and automatic-check toggle report accurate state.

## 9. Markdown Viewer

- [ ] `⌥⌘M` and the menu-bar "Open Markdown Viewer" action bring the window
      to the front with the last document (or untitled if none).
- [ ] The window hosts one tab per open document; the `+` button, ⌘T, and
      "New Markdown Document" add an untitled tab; the `x` on each tab
      closes it (with a save/discard/cancel prompt when dirty).
- [ ] ⌘1…⌘9 switch to the corresponding tab; closing the last tab leaves an
      untitled tab so the window never goes empty.
- [ ] Open… runs `NSOpenPanel` with multi-selection enabled and opens every
      chosen `.md`/`.markdown`/`.mdown`/`.mkd` as a tab.
- [ ] Dragging several `.md` files onto the window opens each as a tab;
      dragging non-Markdown files is ignored; dragging a text selection
      opens it as an untitled tab.
- [ ] Reopening a file that is already in a tab focuses that tab instead of
      duplicating it.
- [ ] Editor: monospaced, curly-quote and em-dash substitution off, line
      numbers toggle reflects the setting, typing marks the active tab dirty.
- [ ] Preview renders tables, fenced code with syntax highlighting, task
      lists, images, strikethrough, nested lists, and autolinks for the
      active tab.
- [ ] Split / Editor / Preview segmented control switches layout and
      persists across opens.
- [ ] Theme (Match System / Light / Dark) and font size update the preview
      live; Match System follows Light/Dark mode changes without a relaunch.
- [ ] External links in the preview open in the default browser, not inside
      the webview.
- [ ] Save writes the active tab back to its file; untitled documents run
      Save As and then record the new path in recents.
- [ ] ⌘O, ⌘S, ⇧⌘S, ⌘W, and ⇧⌘W perform Open, Save, Save As, close tab,
      and close window; saving immediately after the last keystroke writes
      that keystroke rather than the previous buffer.
- [ ] Closing a dirty tab prompts to save / discard / cancel.
- [ ] Closing the window with several dirty tabs resolves each one; Cancel
      at any prompt keeps the window open.
- [ ] Recent files list shows up to 8 entries, opens on click, removes on
      `xmark`, and clears on "Clear". Stale entries (file deleted) show a
      clean inline error instead of crashing.
- [ ] With "Open the Finder selection with the shortcut" enabled: pressing
      ⌥⌘M while Finder is frontmost opens the selected `.md` file(s) as
      tabs; the first time macOS prompts for Automation permission to
      control Finder. Denying shows the reason in settings and the viewer;
      leaving it off opens the viewer with the last document.
- [ ] A hotkey conflict reports `degraded` and a rebind hint; the Open…
      button still works while the shortcut is unavailable.
- [ ] Disable releases the global shortcut and hides the window.
