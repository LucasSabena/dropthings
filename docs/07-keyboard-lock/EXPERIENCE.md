# Experience contract

## Interaction

- Enabling the module never locks the keyboard automatically.
- The user explicitly locks and unlocks from the module view or its dedicated
  menu-bar surface.
- While locked, mouse and trackpad remain available and the menu-bar icon
  visibly names the locked state.
- The unlock control is reachable without a keyboard. There is no hidden
  keyboard shortcut that could be accidentally blocked.

## Permission boundary

- Accessibility permission is requested only when the module is enabled.
- The explanation states that keys are locally suppressed only while the user
  has deliberately enabled the lock; no keystrokes are stored or transmitted.

## States

- Missing Accessibility permission: module remains off and names the required
  System Settings page.
- Event-tap failure: keyboard input continues normally and the module reports
  a recoverable error.
- App/module stop: the event tap is removed and the keyboard is unlocked.
