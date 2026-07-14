# DropThings — Homebrew Cask template
#
# Publish a GitHub release asset named:
#   DropThings-0.6.1.dmg
#
# Then update the sha256 below with:
#   shasum -a 256 .build/dist/DropThings-0.6.1.dmg
#
# Install command once this repo is used as a tap:
#   brew tap LucasSabena/dropthings https://github.com/LucasSabena/dropthings
#   brew install --cask LucasSabena/dropthings/dropthings

cask "dropthings" do
  version "0.6.1"
  sha256 "cc984f202083050e97dcbe2664a7f2b855c0f7617bec68f45aeb9ebba35d39c3"

  url "https://github.com/LucasSabena/dropthings/releases/download/v#{version}/DropThings-#{version}.dmg"
  name "DropThings"
  desc "Native macOS utility hub"
  homepage "https://github.com/LucasSabena/dropthings"

  depends_on macos: :sonoma

  app "DropThings.app"

  zap trash: [
    "~/Library/Application Support/app.dropthings",
    "~/Library/Preferences/app.dropthings.plist",
    "~/Library/Saved Application State/app.dropthings.savedState",
  ]
end
