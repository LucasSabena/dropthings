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
  version "0.1.1"
  sha256 "9c718d89c5955240241d3cd0274e85eedcc8c93272d55d6bae140d4450a37838"

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
