# Research and licenses

Last researched: 2026-07-13.

## Primary technical sources

- Apple `NSMetadataQuery`: Spotlight metadata query, two-phase gathering/live
  updates, predicates, scopes, and notifications:
  <https://developer.apple.com/documentation/foundation/nsmetadataquery>
- Apple Spotlight overview:
  <https://developer.apple.com/documentation/foundation/spotlight>
- Apple `NSWorkspace`: launching apps, opening/revealing files, and workspace
  observation: <https://developer.apple.com/documentation/appkit/nsworkspace>
- Apple Quick Look Thumbnailing:
  <https://developer.apple.com/documentation/quicklookthumbnailing>
- Apple `canJoinAllSpaces` panel behavior:
  <https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallspaces>
- Raycast File Search behavior and its dependence on the OS index:
  <https://manual.raycast.com/file-search>

## Product and source-code boundary

Raycast's main application/search implementation is proprietary. The public
`raycast/extensions` repository is MIT but contains the extension ecosystem,
not reusable source for root search. Use it only if a future extension-specific
feature is approved and tracked.

- Repository: <https://github.com/raycast/extensions>
- License: MIT.
- Current reuse status: none.

## Lazyweb record

Lazyweb was consulted first. The relevant available flow is recorded in
`EXPERIENCE.md`. No assets or code were copied.

## Reuse ledger

No third-party source has been copied into this module as of 2026-07-13.

Before copying any source, append one row:

| DropThings file | Upstream repository/file | Commit | License | Modification |
| --- | --- | --- | --- | --- |
| _none_ | | | | |

Rules:

1. Record the upstream commit, exact path, and license before the code lands.
2. Preserve copyright/license notices required by upstream.
3. Add a concise source comment in copied or substantially adapted files.
4. Do not copy Raycast or Shottr binaries, resources, private APIs, or reverse-
   engineered code.
