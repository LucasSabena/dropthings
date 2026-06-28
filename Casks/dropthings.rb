# DropThings — Homebrew Cask template
#
# Publish a GitHub release asset named:
#   DropThings-0.1.0.dmg
#
# Then update the sha256 below with:
#   shasum -a 256 .build/dist/DropThings-0.1.0.dmg
#
# Install command once this repo is used as a tap:
#   brew tap LucasSabena/dropthings https://github.com/LucasSabena/dropthings
#   brew install --cask LucasSabena/dropthings/dropthings

cask "dropthings" do
  version "0.1.0"
  sha256 "fac8aee7abb8961941f6fc0c5bf1df9087581c54cce3237912ae49350f75042c"

  url "https://github.com/LucasSabena/dropthings/releases/download/v#{version}/DropThings-#{version}.dmg"
  name "DropThings"
  desc "Native macOS utility hub"
  homepage "https://github.com/LucasSabena/dropthings"

  depends_on macos: ">= :sonoma"

  app "DropThings.app"

  zap trash: [
    "~/Library/Application Support/app.dropthings",
    "~/Library/Preferences/app.dropthings.plist",
    "~/Library/Saved Application State/app.dropthings.savedState",
  ]
end
