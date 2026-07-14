# Product contract

## Problem

macOS can keep an Ethernet service first while its link remains up even when
that network no longer reaches the Internet. A connected Wi-Fi hotspot is then
lower in the service order and new connections may continue choosing Ethernet.

## User outcome

- The settings surface shows whether Ethernet or Wi-Fi is currently first.
- Choosing either preference updates the current macOS network location.
- The optional menu-bar item uses `cable.connector.horizontal` for
  Ethernet-first and `wifi` for Wi-Fi-first. Clicking it switches directly to
  the other preference.
- Other services, including VPNs, bridges, and virtual interfaces, never move
  relative to one another.
- The preference remains after DropThings quits because it is a macOS network
  setting, not a temporary route override.

## Boundaries

- The module changes service order; it does not enable/disable interfaces,
  connect to a Wi-Fi network, test Internet quality, or flush existing sockets.
- Only enabled Ethernet and IEEE 802.11 services participate in the switch.
- Both service types must exist and be enabled in the current network location.
- macOS may request an administrator credential when applying a change.
- Existing TCP/QUIC sessions may continue on their original path; reopening or
  retrying an affected connection is outside the module's scope.
