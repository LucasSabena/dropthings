# Experience contract

## Menu bar

- `cable.connector.horizontal` means enabled Ethernet services precede enabled Wi-Fi services.
- `wifi` means enabled Wi-Fi services precede enabled Ethernet services.
- Clicking the icon requests the opposite order immediately.
- While a change is pending, additional clicks are ignored and the last
  confirmed icon remains visible.
- The accessibility label states the confirmed preference and the click action.
- Unknown/unavailable state uses a warning symbol and opens no false promise.

## Settings

- A compact two-option picker exposes Ethernet First and Wi-Fi First.
- The confirmed preference, participating service names, and administrative
  authorization boundary are visible without marketing copy.
- A refresh action re-reads macOS without asking for permission.
- Success is quiet. Cancellation is informational. Set/commit/apply failures are
  actionable and preserve the last confirmed state.

## States

- Disabled: no polling and no independent menu-bar icon.
- Starting: reading the current location and service order.
- Enabled: both service types exist and the confirmed preference is shown.
- Unavailable: the current location lacks an enabled Ethernet or Wi-Fi service,
  or has no explicit service order.
- Error: the last write failed; refresh remains available.

## Accessibility

- Labels never rely on icons or color alone.
- Native buttons and picker semantics support keyboard and VoiceOver.
- Error and authorization explanations use shared typography and semantic color
  tokens.
