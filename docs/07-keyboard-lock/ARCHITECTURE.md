# Architecture

`KeyboardLockModule` owns lifecycle, user state, and UI. `KeyboardEventTap` in
Platform owns the Core Graphics event tap and its lock-protected boolean state.
The callback does not access SwiftUI or actor-isolated state.

The module has no dependency on other feature modules. Core supplies the shared
Accessibility permission state and module registration.
