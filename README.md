# Music Router

A menu-bar utility that stops Music.app/iTunes from launching when you don't
want it to, and routes your keyboard's media keys to whichever app should
actually get them.

[More Drumandbytes projects](https://drumandbytes.com/projects/)

Built as a more functional, actively-maintained replacement for
[noTunes](https://github.com/tombonez/noTunes), whose Music-blocking approach
this reuses (it's the correct one), extended with a lower-level fix for the
keyboard case and real playback control of the replacement app, not just
launching it.

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

Menu-bar toggle, the two interception mechanisms above, and a configurable
single replacement app/URL (via `defaults write dev.drumandbytes.musicrouter
replacement <path-or-url>`, same convention as noTunes).

A media key press first checks whether something is *already* the system's
Now Playing session — native app or a browser tab, anything using the Media
Session/MediaRemote machinery — via `NowPlayingObserver`. If so, the key is
let through untouched, so macOS's own native routing reaches it directly,
exactly as if this app didn't exist; no app-specific code needed on our side.
Only when *nothing* is currently playing does `MediaKeyTap` swallow the key
and launch the configured replacement — for a native app with an AppleScript
dictionary (Spotify, VLC, Music all share iTunes' old
`playpause`/`next track`/`previous track` verbs), `AppleScriptRemote` forces
it into a playing state rather than just opening a window; web replacements
and non-scriptable native apps (e.g. TIDAL) fall back to a plain open.

`NowPlayingObserver` shells out to the
[`media-control`](https://formulae.brew.sh/formula/media-control) CLI
(a Homebrew core formula, declared as a cask dependency), which wraps the
private `MediaRemote` framework via the
[`mediaremote-adapter`](https://github.com/ungive/mediaremote-adapter)
`com.apple.perl5`-entitlement technique — reused rather than vendored, so
there's no framework bundling or build-system dependency on our side. It
runs once as a long-lived background process (`media-control stream`) at
launch, caching the latest state in memory, so a media key press only reads
an already-current flag — no subprocess spawned on the key-press path.

## Building

No Xcode required — just the Xcode Command Line Tools (`xcode-select --install`)
and [`media-control`](https://formulae.brew.sh/formula/media-control)
(`brew install media-control`) for the Now Playing detection:

```bash
scripts/build-app.sh [version]   # swift build + bundle assembly + ad-hoc codesign
open build/MusicRouter.app
```

First launch prompts for **Input Monitoring** and **Accessibility**
permission (System Settings → Privacy & Security — renamed to **Device
Control and Data Access** in macOS 27; same underlying permission, same
`AXIsProcessTrustedWithOptions` API, just a new label) — both are needed for
the media key tap; `CGEventTapCreate` silently fails with only one granted. The
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

- **Enabled** — toggle both interception mechanisms on/off. Remembered
  across relaunches.
- **Replacement App** — a curated shortlist (Spotify, TIDAL, VLC, YouTube
  Music, Deezer, SoundCloud — native apps only show if actually installed),
  **Choose App…** for any other local app, **Custom URL…** for any other web
  player, or **Block Only** for no redirect.
- **Launch at Login** — via `SMAppService`, no manual System Settings step.
- **Hide Menu Bar Icon** — since a hidden `NSStatusItem` has no menu of its
  own to undo this from, relaunching the app (even while it's already
  running — double-click it again in Finder) un-hides it.
- **Reset Permissions** — shows Input Monitoring/Accessibility grant status
  inline, and (after confirming) clears both via `tccutil reset` and
  relaunches the app so you can re-grant them. See "A note on signing" below
  for why a grant can go stale in the first place.

The menu covers everything; `defaults write dev.drumandbytes.musicrouter
replacement <path-or-url>` (and `defaults delete … replacement` for
block-only) works too if you'd rather script it — e.g. from your own
dotfiles setup.

## Testing

```bash
swift test
```

Covers the pure, directly-testable pieces: `MediaKeyTap.decode`'s media-key
bit-unpacking, `Config`'s persistence/URL-vs-path logic, and
`MusicLauncherGuard`'s bundle-ID matching. Not attempting to test the
`CGEventTap`/TCC machinery itself — that needs a real
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
`CGEventTap` permissions (Input Monitoring **and** Accessibility, aka
**Device Control and Data Access** on macOS 27 — both required) are tied to
code-signing identity — either can silently stop
working after a re-sign with no error, independently of each other.
`MediaKeyTap` checks every 5 seconds and reinstalls itself if the tap is dead
or never managed to install, which covers the common case, but the
underlying grant may still need re-approving in System Settings after a
signing-identity change. If toggling it in Settings doesn't seem to take
effect, the menu's **Reset Permissions** action (or manually,
`tccutil reset ListenEvent dev.drumandbytes.musicrouter` and/or
`Accessibility` in place of `ListenEvent`) forces a clean re-registration —
System Settings can show a stale "enabled" toggle for a grant that's no
longer actually bound to the current build.

When moving to Developer ID signing + notarization: notarization requires
hardened runtime (`codesign --options runtime`), and under it AppleEvents to
other apps are denied unless the `com.apple.security.automation.apple-events`
entitlement is present — `scripts/build-app.sh` already applies
`Resources/MusicRouter.entitlements`, so only the identity and `--options
runtime` need adding.

## License

MIT
