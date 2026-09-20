# CLAUDE.md

## Project Overview

MusicRouter is a macOS menu-bar utility (Swift, no Xcode project — SPM only) that stops Music.app/iTunes launching unwantedly and routes media keys to a configured replacement app. A maintained, more functional replacement for [noTunes](https://github.com/tombonez/noTunes). See [README.md](README.md) for the full mechanism writeup (`MediaKeyTap` CGEventTap vs. `MusicLauncherGuard` force-terminate, `NowPlayingObserver`'s `media-control` dependency) before touching any of those files — it's detailed and not worth duplicating here.

## Build & Test

```bash
swift build              # or scripts/build-app.sh [version] for a signed .app bundle
swift test
```

CI (`swift build` + `swift test` on `macos-latest`) gates PRs — nothing else to run locally first.

## Conventions

- **Commits**: Conventional Commits (`feat:`, `fix:`, `docs:`, `chore(deps):`), no particular scope requirement — release-please reads them for version bump + `CHANGELOG.md`.
- **Branches & PRs**: branch, PR, squash-merge. release-please's own bump PRs auto-merge on patch only; minor/major need a human.

## Non-obvious pitfalls

- **Signing is load-bearing, not incidental.** `CGEventTap` permissions (Input Monitoring + Accessibility, aka "Device Control and Data Access" on macOS 27) are tied to code-signing identity. Re-signing with a different identity can silently break the tap with no error — see README's "A note on signing" before changing anything in `scripts/build-app.sh` or the entitlements.
- **`MusicLauncherGuard`'s reliance on force-terminating Music.app after launch is a permanent limitation, not a bug** — there's no public veto hook for AirPlay/Handoff/Siri-triggered launches, so don't "fix" the flash-then-kill behavior for that path.
- **`NowPlayingObserver` shells out to the external `media-control` CLI** (Homebrew formula, declared as a cask dependency, not vendored). Tests around it can't cover the real `CGEventTap`/TCC permission flow — that needs a signed app and a live key press, impractical in CI (this is why `Tests/` only covers pure logic: `MediaKeyTap.decode`, `Config`, `MusicLauncherGuard` bundle-ID matching).
- **Release flow**: tag push → `release.yml` builds, ad-hoc signs, zips, attaches to the release release-please already created, then bumps the cask in `drumandbytes/homebrew-tap` (`Casks/music-router.rb`) via a `dnb-robot` app token — that last step is the only way the Homebrew tap install stays in sync, it isn't automatic from the GitHub release alone.
