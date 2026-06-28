# Menu Bar Cleaner Manual Verification

Menu Bar Cleaner creates a Hidden-Bar-style overflow area with two
DropThings-owned menu bar controls: a divider and a chevron. Users choose
what belongs in the overflow by holding Command and dragging menu bar icons
to the left of the divider.

## Build + launch

1. `xcodebuild -project App.xcodeproj -scheme DropThings -configuration Debug -derivedDataPath .build/xcode build` -> `** BUILD SUCCEEDED **`.
2. `open .build/xcode/Build/Products/Debug/DropThings.app`.

## First run

1. Open Settings -> **Menu Bar Cleaner**.
2. Enable the module.
3. Status pill becomes `Running`.
4. No Accessibility or Screen Recording permission appears for this module.
5. The menu bar shows a DropThings divider and a DropThings chevron.

## Setup the overflow

1. Hold Command and drag the DropThings chevron to the right of the divider.
2. Hold Command and drag one or more low-priority menu bar icons to the left
   of the divider.
3. In Settings, the status copy should say the overflow is visible.

## Collapse / reveal

1. Click **Collapse icons** in Settings, or click the DropThings chevron.
2. The divider expands and pushes the left-of-divider zone off-screen.
3. Click the chevron again, or click **Reveal icons** in Settings.
4. The divider returns to its compact width and the overflow icons become
   visible again.

## Persistence

1. Enable **Collapse on launch**.
2. Quit DropThings.
3. Reopen DropThings.
4. Menu Bar Cleaner starts collapsed.
5. Disable **Collapse on launch**, reveal icons, quit, reopen -> starts
   revealed.

## Disable the module

1. Toggle Menu Bar Cleaner off from the module header or modules list.
2. The divider and chevron disappear.
3. The menu bar remains visible; no AX visibility writes are performed.

## Screen changes

1. Collapse the overflow.
2. Attach or detach an external display.
3. The collapsed spacer recalculates based on the widest screen and remains
   large enough to hide the overflow zone.

## Known constraints

- macOS owns actual status-item ordering. DropThings cannot reposition other
  apps' icons programmatically.
- The first setup requires Command-dragging icons in the menu bar.
- Very future macOS menu bar changes may affect the large-spacer hiding
  mechanism; verify this checklist on new major macOS releases.
