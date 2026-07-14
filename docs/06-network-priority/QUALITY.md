# Quality plan

## Automated

- Stable reordering for Ethernet-first and Wi-Fi-first.
- Multiple Ethernet adapters preserve their relative order.
- VPN/virtual/bridge/disabled services stay in their original slots.
- Already-correct order is a no-op.
- Missing service types produce an unavailable snapshot.
- Module start, refresh, successful toggle, cancellation, failure, and rapid
  repeated clicks use a fake adapter and never touch real network settings.
- SwiftPM test suite plus Debug and Release app builds pass.

## Safe local verification

- Read the live current service order through the adapter and compare it with
  `/usr/sbin/networksetup -listnetworkserviceorder`.
- Do not create, delete, enable, disable, or reorder the developer machine's
  services merely to manufacture an Ethernet fixture.

## Manual verification on a Mac with Ethernet and Wi-Fi

1. Connect both services and note the existing order in System Settings.
2. Enable Network Priority and opt into its menu-bar icon.
3. Choose Wi-Fi First, approve macOS authentication, and verify both DropThings
   and System Settings show Wi-Fi above Ethernet.
4. Click the `wifi` icon and verify it becomes `network` only after confirmation.
5. Confirm VPN and all unrelated services retained their exact relative slots.
6. Cancel an authentication prompt and verify the icon/order do not change.
7. Change order in System Settings and verify DropThings updates within one
   refresh interval.
8. Disable the module and verify polling/icon stop without reverting the order.

## Evidence — 2026-07-14

- All 378 SwiftPM tests passed, including 15 Network Priority tests.
- The live read-only adapter matched a valid current SystemConfiguration order.
- Debug and Release app builds succeeded for macOS 14 deployment.
- The healthy settings state was rendered and visually inspected in the built
  app; the initial generic network glyph was replaced with Apple's cable
  connector symbol to communicate Ethernet unambiguously.
- This machine exposes Ethernet hardware ports but no enabled Ethernet network
  service in the current location. The privileged write path was therefore not
  invoked or fabricated; the exact dual-service manual matrix above remains the
  release-device gate.
