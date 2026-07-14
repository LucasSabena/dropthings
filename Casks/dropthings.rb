# DropThings — Homebrew Cask template
#
# Publish a GitHub release asset named:
#   DropThings-0.6.4.dmg
#
# Then update the sha256 below with:
#   shasum -a 256 .build/dist/DropThings-0.6.4.dmg
#
# Install command once this repo is used as a tap:
#   brew tap LucasSabena/dropthings https://github.com/LucasSabena/dropthings
#   brew install --cask LucasSabena/dropthings/dropthings

cask "dropthings" do
  version "0.6.4"
  sha256 "7f2eae8078e09a119e319a93b3537bdca5e81aed0eb31695b9566037efbb2440"

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
