# Audio Control

This folder defines a FineTune-class per-application volume, routing, and EQ
module. It is the highest-risk product in this plan and must be delivered behind
strict safety gates.

## Read order

1. `PRODUCT.md`
2. `ARCHITECTURE.md`
3. `EXPERIENCE.md`
4. `IMPLEMENTATION.md`
5. `QUALITY.md`
6. `RESEARCH-AND-LICENSES.md`
7. `AGENT-RUNBOOK.md`

## Definition of done

- Active audio-producing applications appear with persistent per-app volume and
  mute controls.
- Audio routing, EQ, boost, device changes, sleep/wake, process exit, and module
  disable never leave an app silent, duplicated, or routed through an orphan tap.
- The engine avoids clipping and ramps discontinuous changes.
- The UI remains responsive even when Core Audio/device operations fail.
- Audio processing is isolated so a real-time/driver failure cannot terminate
  the DropThings host.
- The owner can remove FineTune only after the hardware/application matrix and a
  sustained daily-use gate pass.

## Platform decision

Keep the main app deployment target at macOS 14 for other modules. Audio Control
requires at least macOS 14.2 for Core Audio process taps; the first supported and
tested product target is macOS 15+ to align with the inspected FineTune baseline.
On older systems the module is visible as unavailable and requests no permission.

## Delivery order

1. A disposable technical spike on the owner's hardware.
2. Isolated safe per-app volume/mute engine.
3. Persistence, meters, lifecycle, and recovery.
4. Per-app device routing.
5. EQ/boost/limiter.
6. Advanced FineTune parity only after the core is dependable.
