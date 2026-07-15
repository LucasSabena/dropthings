# DropThings — Homebrew Cask template
#
# Publish a GitHub release asset named:
#   DropThings-0.7.1.dmg
#
# Then update the sha256 below with:
#   shasum -a 256 .build/dist/DropThings-0.7.1.dmg
#
# Install command once this repo is used as a tap:
#   brew tap LucasSabena/dropthings https://github.com/LucasSabena/dropthings
#   brew install --cask LucasSabena/dropthings/dropthings

cask "dropthings" do
  version "0.7.1"
  sha256 "c00386228d91e51439816275fa0e024fbd9b44bbd4307a2832ab25a5d67ec633"

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
