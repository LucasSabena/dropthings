# DropThings — Homebrew Cask template
#
# Publish a GitHub release asset named:
#   DropThings-0.7.0.dmg
#
# Then update the sha256 below with:
#   shasum -a 256 .build/dist/DropThings-0.7.0.dmg
#
# Install command once this repo is used as a tap:
#   brew tap LucasSabena/dropthings https://github.com/LucasSabena/dropthings
#   brew install --cask LucasSabena/dropthings/dropthings

cask "dropthings" do
  version "0.7.0"
  sha256 "a8d8fce294dbb160fce16f525b3d042089852d1280d1cec6f1f9440e1ab145c8"

  url "https://github.com/LucasSabena/dropthings/releases/download/v#{version}/DropThings-#{version}.dmg"
  name "DropThings"
  desc "Native utility hub for small system tools"
  homepage "https://github.com/LucasSabena/dropthings"

  depends_on macos: :sonoma

  app "DropThings.app"

  zap trash: [
    "~/Library/Application Support/app.dropthings",
    "~/Library/Preferences/app.dropthings.plist",
    "~/Library/Saved Application State/app.dropthings.savedState",
  ]
end
