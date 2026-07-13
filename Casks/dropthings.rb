# DropThings — Homebrew Cask template
#
# Publish a GitHub release asset named:
#   DropThings-0.1.1.dmg
#
# Then update the sha256 below with:
#   shasum -a 256 .build/dist/DropThings-0.1.1.dmg
#
# Install command once this repo is used as a tap:
#   brew tap LucasSabena/dropthings https://github.com/LucasSabena/dropthings
#   brew install --cask LucasSabena/dropthings/dropthings

cask "dropthings" do
  version "0.4.1"
  sha256 "bd3c7ca499cfd123c36482d446d81997b03ddb506b9ec090ddda58847ffc115c"

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
