# Distribution

DropThings should feel like a normal macOS app to install:

1. Download a `.dmg`.
2. Drag `DropThings.app` to `Applications`.
3. Open the app.
4. Grant Accessibility or Screen Recording only when a module asks.

## Build A DMG

```bash
scripts/build-dmg.sh
```

Output:

```text
.build/dist/DropThings-0.1.1.dmg
```

The DMG contains:

- `DropThings.app`
- `Applications` symlink

For real public distribution, sign and notarize first. See `docs/RELEASE.md`.

## Homebrew Cask

The app should be distributed through a Homebrew Cask, not a Formula.

Install command after publishing the GitHub release and updating the cask
SHA:

```bash
brew tap LucasSabena/dropthings https://github.com/LucasSabena/dropthings
brew install --cask LucasSabena/dropthings/dropthings
```

Release asset expected by `Casks/dropthings.rb`:

```text
https://github.com/LucasSabena/dropthings/releases/download/v0.1.1/DropThings-0.1.1.dmg
```

Update the cask checksum with:

```bash
shasum -a 256 .build/dist/DropThings-0.1.1.dmg
```

Then replace `REPLACE_WITH_SHA256_OF_DMG` in `Casks/dropthings.rb`.
