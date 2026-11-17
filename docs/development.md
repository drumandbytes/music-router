# Development

## Building

No Xcode required, just the Xcode Command Line Tools (`xcode-select --install`),
which provide `swift` and `clang` (the vendored adapter framework is compiled
with `clang` by `scripts/build-adapter.sh`, no CMake):

```bash
scripts/build-app.sh [version]   # swift build + bundle assembly + ad-hoc codesign
open build/MusicRouter.app
```

First launch prompts for **Input Monitoring** and **Accessibility** (System
Settings → Privacy & Security; renamed to **Device Control and Data Access** in
macOS 27, same underlying permission and the same `AXIsProcessTrustedWithOptions`
API). Both are needed for the media key tap: `CGEventTapCreate` silently fails
with only one granted. The prompt only shows once ever, even across relaunches
while you haven't granted it yet, so check Settings at your own pace.

A local `swift build` stamps the binary with an old SDK, while CI links against
the newest one, and AppKit behaves differently by linked SDK (macOS 27 hides menu
images unless asked not to). Try a release build on a real Mac before trusting a
change that touches AppKit.

## Testing

```bash
swift test
```

Covers the pure and process-level pieces: `MediaKeyTap.decode`'s media-key
bit-unpacking, `Config`'s persistence and defaults, `MusicLauncherGuard`'s
bundle-ID matching, `DebugLog`'s gating and rotation, and `NowPlayingObserver`
against a fake adapter process (healthy, silent, exiting, missing, stalled,
recovering), plus target cycling, last-player selection, the shortcut model and
the `musicrouter-media` command mapping. CI also builds the adapter framework and
prints a coverage summary (no external service); the untestable AppKit/event-tap
code keeps the total low by design. Not attempting to test the `CGEventTap`/TCC
machinery or the real MediaRemote adapter itself: that needs a real signed app, a
real permission grant and a real key press or playing app, none of which are
practical in CI.

## Signing

This app is ad-hoc signed, not notarized. A paid Apple Developer Program
membership ($99/year) is the only way to remove that entirely, and isn't worth
it yet for a personally-distributed tool. Since it's never downloaded through a
browser, no quarantine attribute gets attached; Homebrew casks installing it go
through the normal one-time Gatekeeper approval like any non-Developer-ID-signed
app.

If you build it yourself and re-sign with a different identity, note that
`CGEventTap` permissions (Input Monitoring **and** Accessibility, aka **Device
Control and Data Access** on macOS 27; both required) are tied to code-signing
identity, and either can silently stop working after a re-sign with no error,
independently of each other. `MediaKeyTap` checks every 5 seconds and
reinstalls itself if the tap is dead or never managed to install, which covers
the common case, but the underlying grant may still need re-approving in System
Settings after a signing-identity change. If toggling it in Settings doesn't
seem to take effect, **Reset Permissions…** in Settings (or manually,
`tccutil reset ListenEvent dev.drumandbytes.musicrouter` and/or `Accessibility`
in place of `ListenEvent`) forces a clean re-registration. System Settings can
show a stale "enabled" toggle for a grant that's no longer actually bound to the
current build.

When moving to Developer ID signing + notarization: notarization requires
hardened runtime (`codesign --options runtime`), and under it AppleEvents to
other apps are denied unless the `com.apple.security.automation.apple-events`
entitlement is present. `scripts/build-app.sh` already applies
`Resources/MusicRouter.entitlements`, so only the identity and `--options
runtime` need adding.

## Third-party code

`third_party/mediaremote-adapter/` is an unmodified copy of
[ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter)
v0.7.7 (BSD 3-Clause, © 2025 Jonas van den Berg and contributors; license in
`third_party/mediaremote-adapter/LICENSE`, also shipped inside the app). Only
the test client source is omitted. To update by hand, run
`scripts/update-adapter.sh <tag>`.

## Releases and maintenance

Commits follow Conventional Commits; release-please turns them into a release PR
and `CHANGELOG.md`. Merging that PR tags the release, and `release.yml` builds,
ad-hoc signs and zips the app, attaches it to the release and bumps the cask in
`drumandbytes/homebrew-tap`. A `refactor:`, `docs:` or `chore:` commit doesn't
release by itself.

What keeps itself current:

- **GitHub Actions**: Dependabot, weekly.
- **The vendored adapter**: a weekly workflow
  (`.github/workflows/adapter-update.yml`) checks upstream for a newer release
  and opens a **draft** PR that runs `scripts/update-adapter.sh <tag>`. It stays
  a draft until the adapter has been tried on a Mac, because CI only proves it
  compiles.
- **CI**: `swift build`, `swift test` and the adapter framework build on
  `macos-latest`, plus a workflow security check.

What needs a person, once per major macOS (beta included) and before trusting
an adapter update:

- Build a release (`scripts/build-app.sh`) and open it.
- **Settings → Now Playing detection** says Working.
- A native app and a browser tab show up as the Now Playing owner (the debug
  log shows it), and a media key passes through while something plays and starts
  the replacement when nothing does.
- `musicrouter-media get` returns the current track.
- The menu, Settings and dialogs render (icons, glass backgrounds, permissions).
