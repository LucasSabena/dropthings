# Product Plan

## Vision

Build a single native macOS app that gathers small, high-impact utilities into one coherent place. The feel should be: PowerToys spirit, macOS-native execution, compact settings, clear permissions, and easy future expansion.

## Initial Problems

1. Separate scroll direction for mouse wheel and trackpad.
2. Temporary drag-and-drop shelf for files, links, images, and text.
3. Menu bar icon cleanup with hidden items, reveal control, and ordering.

## Product Principles

- One app, many modules.
- Modules can be enabled independently.
- Permissions are requested only when needed.
- Defaults are conservative and reversible.
- The UI is quiet, dense, and native.
- The design system is shared across every module.
- System-facing code is isolated and easy to audit.

## Target Users

- macOS users coming from Windows.
- Power users with many background apps.
- People who drag files across apps, desktops, Spaces, and upload forms.
- Users who want system tweaks without installing ten tiny utilities.

## Success Metrics

- A new user can enable one useful module in under 60 seconds.
- Permission prompts explain why they are needed before macOS asks.
- Each module can be disabled without quitting the app.
- Adding a new module does not require changing existing modules.
- The app remains responsive while event taps, shelves, and menu bar monitoring run.

## Non-Goals For MVP

- Replacing every macOS window manager.
- Building a full plugin marketplace.
- Shipping App Store-first. Some permissions and APIs may make direct distribution easier.
- Copying commercial apps feature-for-feature.

