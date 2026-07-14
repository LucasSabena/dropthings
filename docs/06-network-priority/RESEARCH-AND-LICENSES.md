# Research and licenses

Last researched: 2026-07-14.

## Apple sources

- Apple Support, “Change the order of the network services your Mac uses”:
  <https://support.apple.com/guide/mac-help/change-order-network-services-mac-mchlp2711/mac>
- `SCNetworkSetSetServiceOrder` stores the user-specified service identifiers:
  <https://developer.apple.com/documentation/systemconfiguration/scnetworksetsetserviceorder(_:_:)> 
- `SCPreferencesCreateWithAuthorization` creates a privileged preferences
  session:
  <https://developer.apple.com/documentation/systemconfiguration/scpreferencescreatewithauthorization(_:_:_:_:)>
- `SCPreferencesCommitChanges` persists changes and documents that apply is a
  separate step:
  <https://developer.apple.com/documentation/systemconfiguration/scpreferencescommitchanges(_:)>
- `SCPreferencesApplyChanges` applies committed preferences to the running
  system:
  <https://developer.apple.com/documentation/systemconfiguration/scpreferencesapplychanges(_:)>
- Authorization Services requires a non-sandboxed app and recommends keeping
  privileged code narrowly scoped:
  <https://developer.apple.com/library/archive/documentation/Security/Conceptual/authorization_concepts/02authconcepts/authconcepts.html>
- Apple DTS explains that SystemConfiguration network writes use an
  administrator authorization rule with a short credential timeout:
  <https://developer.apple.com/forums/thread/805149>

## Field reports reviewed

- Reports confirm service order is the normal macOS control for Ethernet/Wi-Fi
  preference and that existing connections may remain on their original path:
  <https://www.reddit.com/r/MacOS/comments/17x1a65/>
- Reports also reinforce why parsing localized `networksetup` output is not an
  acceptable implementation boundary:
  <https://www.reddit.com/r/MacOS/comments/de3o8q/>

Field reports inform failure wording only; Apple APIs and local SDK headers are
the implementation authority.

## Reuse ledger

No third-party source code or visual asset is copied. The implementation is
original and uses only public Apple frameworks already available on macOS.
