# Music Router

A menu-bar utility that stops Music.app/iTunes from launching when you don't
want it to, and routes your keyboard's media keys to whichever app should
actually get them.

Built as a more functional, actively-maintained replacement for
[noTunes](https://github.com/tombonez/noTunes), whose Music-blocking approach
this reuses (it's the correct one), extended with a lower-level fix for the
keyboard case and — eventually — the ability to pick which app responds when
more than one is playing.

## How it works

Two independent mechanisms, because Music.app can be launched through paths
that need different fixes:

- **`MediaKeyTap`** — intercepts play/pause/next/previous at the HID/session
  level with a `CGEventTap` (the technique Spotify open-sourced years ago as
  `SPMediaKeyTap`), before macOS's default handler can decide "nothing's
  listening" and launch Music. The event is consumed, so Music never launches
  for this trigger — no flash, no launch-then-kill.
- **`MusicLauncherGuard`** — for everything else (AirPlay speaker selection,
  Handoff from iPhone, Siri "play some music"), which don't route through a
  key event and have no public veto hook. This watches
  `NSWorkspace.didLaunchApplicationNotification` and force-terminates
  Music/iTunes immediately if it launches, same approach noTunes uses. This is
  a real, permanent limitation — not a bug to eventually fix.

## Status

**Phase 1 (this repo, current):** menu-bar toggle, the two interception
mechanisms above, and a configurable single replacement app/URL (via
`defaults write dev.drumandbytes.musicrouter replacement <path-or-url>`,
same convention as noTunes).

**Phase 2 (not yet built):** when multiple apps are playing media
simultaneously, choose which one responds to the media keys, using the
private `MediaRemote` framework (what Control Center's Now Playing widget
uses) via the [`mediaremote-adapter`](https://github.com/ungive/mediaremote-adapter)
technique — a system binary with the required entitlement (`com.apple.*`
bundle IDs are allow-listed) hosts the private framework calls, bypassing the
direct-linking restriction Apple added in macOS 15.4.

## Building

No Xcode required — just the Xcode Command Line Tools (`xcode-select --install`):

```bash
scripts/build-app.sh [version]   # swift build + bundle assembly + ad-hoc codesign
open build/MusicRouter.app
```

First launch prompts for **Input Monitoring** and **Accessibility**
permission (System Settings → Privacy & Security) — both are needed for the
media key tap; `CGEventTapCreate` silently fails with only one granted. The
prompt only shows once ever, even across relaunches while you haven't
granted it yet — check Settings at your own pace rather than getting
re-alerted every launch.

## Installing

```bash
brew install drumandbytes/tap/music-router
```

Since it's ad-hoc signed (no Apple Developer Program enrollment — unnecessary
for a personally-distributed tool), macOS will show the normal one-time
"unidentified developer" prompt on first launch. Approve it once in System
Settings → Privacy & Security → Open Anyway.

## Menu bar

Click the note icon for:

- **Enabled** — toggle both interception mechanisms on/off.
- **Replacement App** — a curated shortlist (Spotify, TIDAL, VLC, YouTube
  Music, Deezer, SoundCloud — native apps only show if actually installed),
  **Choose App…** for anything else, or **Block Only** for no redirect.
- **Launch at Login** — via `SMAppService`, no manual System Settings step.
- **Hide Menu Bar Icon** — since a hidden `NSStatusItem` has no menu of its
  own to undo this from, relaunching the app (even while it's already
  running — double-click it again in Finder) un-hides it.

Same configuration is also reachable from the terminal:

```bash
defaults write dev.drumandbytes.musicrouter replacement /Applications/Spotify.app
defaults write dev.drumandbytes.musicrouter replacement https://music.youtube.com/
defaults delete dev.drumandbytes.musicrouter replacement   # block-only, no redirect
```

## Testing

```bash
swift test
```

Covers the two genuinely fiddly, pure pieces: `MediaKeyTap.decode`'s
media-key bit-unpacking, and `Config`'s persistence/URL-vs-path logic. Not
attempting to test the `CGEventTap`/TCC machinery itself — that needs a real
signed app, a real permission grant, and a real key press, none of which are
practical in CI (see "A note on signing" below for how flaky that
combination already is even by hand).

## A note on signing

This app is ad-hoc signed, not notarized — a paid Apple Developer Program
membership ($99/year) is the only way to remove that entirely, and isn't
worth it yet for a personally-distributed tool. Since it's never downloaded
through a browser, no quarantine attribute gets attached; Homebrew casks
installing it go through the normal one-time Gatekeeper approval like any
non-Developer-ID-signed app.

If you build it yourself and re-sign with a different identity, note that
`CGEventTap` permissions (Input Monitoring **and** Accessibility — both
required) are tied to code-signing identity — either can silently stop
working after a re-sign with no error, independently of each other.
`MediaKeyTap` polls `CGEvent.tapIsEnabled()` every 5 seconds and reinstalls
itself if it finds the tap dead, which covers the common case, but the
underlying grant may still need re-approving in System Settings after a
signing-identity change. If toggling it in Settings doesn't seem to take
effect, `tccutil reset ListenEvent dev.drumandbytes.musicrouter` (and/or
`Accessibility` in place of `ListenEvent`) forces a clean re-registration —
System Settings can show a stale "enabled" toggle for a grant that's no
longer actually bound to the current build.

## License

MIT
