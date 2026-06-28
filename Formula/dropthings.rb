# DropThings — Homebrew formula template
#
# Drop this file into a homebrew tap repo at:
#   homebrew-tap/Formula/dropthings.rb
# then `brew install user/tap/dropthings`.
#
# Replace USER with the GitHub user/org that owns both the tap and the
# DropThings repo. The sha256 must match the published zip for each tag.

class Dropthings < Formula
  desc "Native macOS utility hub: file shelf, scroll control, menu bar cleaner, color picker, screenshot, keep awake"
  homepage "https://github.com/USER/dropthings"
  url "https://github.com/USER/dropthings/releases/download/v0.1.0/DropThings-0.1.0.zip"
  sha256 "REPLACE_WITH_SHA256_OF_RELEASE_ZIP"
  version "0.1.0"

  depends_on macos: ">= :sonoma"

  # DropThings is a regular app, not a CLI tool, but `brew install` is the
  # cleanest distribution path for now.
  app "DropThings.app"

  # Where DropThings keeps user data. Removing via `brew uninstall --zap`
  # should clean these up so the next install starts fresh.
  zap trash: [
    "~/Library/Application Support/app.dropthings",
    "~/Library/Logs/DropThings",
    "~/Library/Preferences/app.dropthings.plist",
    "~/Library/Saved Application State/app.dropthings.savedState",
  ]

  def install
    prefix.install "DropThings.app"
  end

  def caveats
    <<~EOS
      DropThings asks for Accessibility and Screen Recording only when a
      specific module needs them. Grant from
        System Settings → Privacy & Security → Accessibility
        System Settings → Privacy & Security → Screen Recording

      The Diagnostics panel inside DropThings (Settings → Diagnostics)
      shows which permissions are granted and the actual bundle path,
      so you can confirm the grant is going to the right binary.
    EOS
  end

  test do
    # `brew audit` runs this. We only check that the .app structure is
    # sane; we do not actually launch it (that would prompt for TCC).
    assert_predicate prefix/"DropThings.app/Contents/MacOS/DropThings",
                   :exist?
    assert_predicate prefix/"DropThings.app/Contents/Info.plist",
                   :exist?
  end
end
