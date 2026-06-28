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
  version "0.1.4"
  sha256 "bc310296713627ddc95fb12a155f7fec2403234db0961a33049cac5791a65ac7"

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
