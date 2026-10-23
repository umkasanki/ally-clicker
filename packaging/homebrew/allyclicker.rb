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
#   brew trust umkasanki/tap        # third-party taps must be trusted once
#   brew install --cask allyclicker
#
# The live cask is Casks/allyclicker.rb in umkasanki/homebrew-tap; the release
# workflow bumps its version and sha256 only, so change anything else in both.
cask "allyclicker" do
  version "0.1.0"
  sha256 "REPLACE_WITH_DMG_SHA256"   # from `shasum -a 256` printed by make-dmg.sh

  url "https://github.com/umkasanki/ally-clicker/releases/download/v#{version}/AllyClicker-#{version}.dmg"
  name "AllyClicker"
  desc "Dwell-click accessibility tool for head-tracker and pointer-only users"
  homepage "https://github.com/umkasanki/ally-clicker"

  depends_on macos: :sonoma

  app "AllyClicker.app"

  # Self-signed, not notarized: without this Gatekeeper refuses the first launch,
  # and for a dwell-clicker that refusal is a trap — the tool you need in order to
  # click is the one you cannot start without clicking.
  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/AllyClicker.app"]
  end

  uninstall quit: "com.allyclicker.app"

  zap trash: [
    "~/Library/Application Support/AllyClicker",
    "~/Library/Preferences/com.allyclicker.app.plist",
  ]

  caveats <<~EOS
    AllyClicker needs Accessibility permission to inject clicks:
      System Settings → Privacy & Security → Accessibility → enable AllyClicker
  EOS
end
