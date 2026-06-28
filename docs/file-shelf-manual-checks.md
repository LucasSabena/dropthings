# File Shelf Manual Verification

The File Shelf is the first real module in DropThings and depends on a lot of
macOS-only behavior that unit tests cannot cover. Run through these checks
after every change to the `FileShelf/`, `DropThingsPlatform/Adapters/`, or the
shelf wiring in `App/`.

## Build + launch

1. `xcodebuild -project App.xcodeproj -scheme DropThings -configuration Debug -derivedDataPath .build/xcode build` → `** BUILD SUCCEEDED **`.
2. `open .build/xcode/Build/Products/Debug/DropThings.app`.
3. The DropThings icon appears in the menu bar (square stack symbol). No dock icon (`LSUIElement = true`).

## Settings shell

1. Click the menu bar icon → "Open Settings…" → Settings window opens.
2. Sidebar shows `Modules`, `Diagnostics`, `About`, and `File Shelf` under "Modules".
3. Click "File Shelf" in the sidebar → detail pane shows the module header, a `File Shelf` settings section, and a status pill.
4. Toggle the module off and on → status pill cycles between "Off" and "Running".

## Drop zone (AppKit `NSDraggingDestination`)

1. From the module detail pane, click **Show Shelf** → the floating panel appears.
2. Drag a single file from Finder onto the panel → the panel highlights and the file appears as a row.
3. Drag a folder → appears with a folder icon.
4. Drag multiple files at once → all appear, ordered by drop time.
5. Drag plain text from a browser address bar → appears as a text item with the URL truncated to 60 chars.
6. Drag an image → appears as a text item (image preview is not implemented yet; the URL or path is what we surface).
7. Drag a non-supported item (e.g. from Mail) → the panel does not highlight, and no row is added.

## Drag-out

1. With a file on the shelf, drag the row out into a Finder window → Finder accepts the file at the drop target.
2. Drag into a text editor (TextEdit, VS Code) → for text items, the text content is inserted. For file items, the path is inserted.
3. Drag into an upload form in a browser → file uploads.

## Row actions (context menu, right-click)

1. Right-click a file row → menu shows `Reveal in Finder`, `Copy Path`, divider, `Remove from Shelf`.
2. Click `Reveal in Finder` → Finder opens with the file selected.
3. Click `Copy Path` → paste anywhere, the absolute path comes out.
4. Right-click a text row → only `Remove from Shelf` is shown (no file actions).
5. Click `Remove from Shelf` → row disappears, no other rows reflow in unexpected ways.

## Settings

1. Change the "Maximum items" stepper → close and reopen Settings → value is remembered.
2. Drop more items than the cap → the oldest items drop off, the newest remain.
3. Toggle "Clear shelf when disabled" off, drop a few items, disable the module from the registry, re-enable → items are still on the shelf.
4. Toggle it back on, drop items, disable the module → items are cleared.

## Failure / edge cases

1. Drop a file whose path no longer exists (unplug a network volume first) → shelf still shows the row, but `Reveal in Finder` opens the parent directory; `Copy Path` still works.
2. Drop a 10,000-item batch → the shelf caps at `maxItems`; older entries fall off.
3. Drag a file into the shelf panel from a sandboxed app (e.g. Mail attachment) → behavior depends on the source app's permission grant; if the path is unusable, the row appears with a non-functional URL (Reveal in Finder opens the parent).
4. Open the shelf, click into another fullscreen app → the shelf stays visible (`collectionBehavior = .fullScreenAuxiliary`).

## Shake-to-show

1. With the module enabled (default), shake the mouse side to side 4–5 times in under half a second → the shelf appears.
2. Shake again with the shelf visible → the shelf hides.
3. Disable `Show shelf when I shake the mouse` in settings → shake no longer triggers the shelf.
4. Toggle off, then on, while the module is running → shake starts triggering again.
5. Quit DropThings, reopen → the toggle preference is preserved.

## Pin + persistence

1. Drop two files onto the shelf.
2. Right-click one row → `Pin` → the row gets a `📌` badge next to the title and the icon shifts to the top of the list.
3. Click `Clear all` in the File Shelf settings → only the pinned item remains; the unpinned one is gone.
4. Drag a third file onto the shelf, drop a fourth on top of the pinned one (dedup) → no duplicate row.
5. Right-click the pinned item → `Unpin` → it loses the badge and becomes transient.
6. Drop the unpinned file again, quit DropThings (`Quit` from menu bar), reopen → pinned file is back, the other one is gone.
7. The on-disk state lives at `~/Library/Application Support/app.dropthings/file-shelf-pinned.json`. Delete it manually to wipe the shelf.
8. Open the file with TextEdit → it is a JSON array of `FileShelfItem` entries with `kind`, `addedAt`, and `isPinned` keys.

## Logs

1. Open `Console.app`, filter on subsystem `app.dropthings`.
2. Drag in items, clear, reveal, copy path → you should see one info line per action, prefixed with the module category (`file-shelf`).
3. No warning or error lines under normal use.

## What is NOT covered by these checks

- Drag-out into browser uploads in different browsers (test the ones the user actually uses).
- Persistence (deliberately deferred — see `docs/decisions.md`).
- Hotkey to show the shelf (also deferred).
