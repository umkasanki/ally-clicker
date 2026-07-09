# Homebrew Cask for AllyClicker — template for your own tap.
#
# Setup (one time):
#   1. Create a GitHub repo named `homebrew-tap` under your account
#      (github.com/umkasanki/homebrew-tap) with a `Casks/` folder.
#   2. Copy this file to `Casks/allyclicker.rb` in that repo.
#   3. Build the DMG here:  ./App/make-dmg.sh  → note the printed SHA-256.
#   4. Create a GitHub Release `v<version>` on ally-clicker and upload the
#      `AllyClicker-<version>.dmg` as a release asset.
#   5. Fill in `version` and `sha256` below, commit the cask to the tap.
#
# Install (users):
#   brew tap umkasanki/tap
#   brew install --cask --no-quarantine allyclicker
#   (--no-quarantine because the app is self-signed, not notarized)
cask "allyclicker" do
  version "0.1.0"
  sha256 "REPLACE_WITH_DMG_SHA256"   # from `shasum -a 256` printed by make-dmg.sh

  url "https://github.com/umkasanki/ally-clicker/releases/download/v#{version}/AllyClicker-#{version}.dmg"
  name "AllyClicker"
  desc "Dwell-click accessibility tool for head-tracker and pointer-only users"
  homepage "https://github.com/umkasanki/ally-clicker"

  app "AllyClicker.app"

  caveats <<~EOS
    AllyClicker needs Accessibility permission to inject clicks:
      System Settings → Privacy & Security → Accessibility → enable AllyClicker

    It is not notarized. If macOS blocks it on first launch, either install with
      brew install --cask --no-quarantine allyclicker
    or clear the quarantine flag:
      xattr -dr com.apple.quarantine "/Applications/AllyClicker.app"
  EOS
end
