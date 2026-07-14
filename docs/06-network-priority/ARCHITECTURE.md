# Architecture

Last reviewed: 2026-07-14.

## Ownership

- `DropThingsPlatform/Network` wraps SystemConfiguration and Security.
- `DropThingsModules/NetworkPriority` owns settings, state, polling, commands,
  and the settings view.
- `DropThingsCore` owns the module ID and generic menu-bar visibility setting.
- The app target only registers the module and places it in product order.

## Read path

1. Create an unprivileged `SCPreferences` session.
2. Copy the current `SCNetworkSet` (the active network location).
3. Read its service order and service descriptors.
4. Classify services by `SCNetworkInterfaceGetInterfaceType` using Apple's
   Ethernet and IEEE 802.11 constants; never infer type from localized names.
5. Compare the first enabled Ethernet and Wi-Fi service positions.

The module refreshes periodically while enabled so changes made in System
Settings are reflected in the menu-bar symbol. Reads never request privileges.

## Write path

1. Create an `AuthorizationRef` only for an explicit user change.
2. Create `SCPreferences` with `SCPreferencesCreateWithAuthorization`.
3. Re-read the current set and service order inside that same session.
4. Build a stable order that changes only the slots occupied by enabled
   Ethernet/Wi-Fi services. Preferred services fill those slots first; all
   relative order inside each group is preserved.
5. Lock preferences, set the order, commit, apply, unlock, and re-read.
6. Verify the requested type is first before publishing success.

No shell command, private API, route-table mutation, or copied third-party code
is used.

## Authorization boundary

Changing system network configuration is an administrative operation. The app
is intentionally not sandboxed, and SystemConfiguration delegates authentication
to Authorization Services. The authorization reference lives for one operation
and is always freed. Cancellation leaves the previous order intact.

A persistent root helper is deliberately out of scope: it would broaden the
attack surface and background-item lifecycle solely to avoid a system-owned
authentication dialog. Apple's current authorization rule may expire cached
credentials quickly, so the UI never promises that later switches are silent.

## Failure and concurrency

- A serial adapter queue prevents concurrent preference writes.
- The module rejects a second click while a change is in flight.
- Missing current set/order or missing enabled Ethernet/Wi-Fi is unavailable,
  not silently guessed.
- A failed set/commit/apply reports the exact SystemConfiguration error and
  refreshes from the system instead of assuming success.
- Disabling the module cancels refresh work but does not undo the user's system
  preference.
