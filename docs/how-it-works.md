# How it works

## Two blocking mechanisms

Music.app can be launched through paths that need different fixes:

- **`MediaKeyTap`**: intercepts play/pause/next/previous at the HID/session
  level with a `CGEventTap` (the technique Spotify open-sourced years ago as
  `SPMediaKeyTap`), before macOS's default handler can decide "nothing's
  listening" and launch Music. The event is consumed, so Music never launches
  for this trigger: no flash, no launch-then-kill.
- **`MusicLauncherGuard`**: for everything else (AirPlay speaker selection,
  Handoff from iPhone, Siri "play some music"), which don't route through a
  key event and have no public veto hook. This watches
  `NSWorkspace.didLaunchApplicationNotification` and force-terminates
  Music/iTunes immediately if it launches, same approach noTunes uses. It's
  reactive by design: Music.app is on the sealed, SIP-protected system volume,
  so there's nothing to remove, rename or lock down, and no public hook to veto
  another app's launch. Quitting it on launch is the approach that works for
  every trigger without disabling system protections, and the brief flash for
  non-key launches is the price. This is a real, permanent limitation, not a bug
  to eventually fix.

## Routing the keys

A media key press first checks whether something is *already* the system's
Now Playing session (a native app or a browser tab, anything using the Media
Session/MediaRemote machinery) via `NowPlayingObserver`. If so, the key is
let through untouched, so macOS's own native routing reaches it directly,
exactly as if this app didn't exist; no app-specific code needed on our side.
Only when *nothing* is currently playing does `MediaKeyTap` swallow the key
and launch the configured replacement: for a native app with an AppleScript
dictionary (Spotify, VLC, Music all share iTunes' old
`playpause`/`next track`/`previous track` verbs), `AppleScriptRemote` forces
it into a playing state rather than just opening a window; web replacements
and non-scriptable native apps (e.g. TIDAL) fall back to a plain open.

## The Now Playing adapter

`NowPlayingObserver` reads Now Playing through the private `MediaRemote`
framework, which since macOS 15.4 only answers Apple-signed processes. It
uses the [`mediaremote-adapter`](https://github.com/ungive/mediaremote-adapter)
technique: `/usr/bin/perl` (signed `com.apple.perl5`) runs the adapter's
script, which loads a small bundled framework and calls MediaRemote from
inside that entitled process. A pinned copy (v0.7.7, BSD-3) is vendored under
`third_party/mediaremote-adapter/`, built into the app by `scripts/build-app.sh`,
and bundled in the app (`Contents/Frameworks`, `Contents/Resources`), so
there's no separate install. It runs once as a long-lived background process
(`perl mediaremote-adapter.pl … stream`) at launch, caching the latest state
in memory, so a media key press only reads an already-current flag: no
subprocess spawned on the key-press path.

## Choosing the target app

By default Now Playing decides who gets the keys. With several players
running you can pin one: **Media Key Target** in the menu (or Settings) picks
Spotify or VLC (whichever are installed; TIDAL is launch-only). While one is
picked, Music Router swallows play/next/previous and sends them to that app
through AppleScript, whatever owns Now Playing, launching it first if it isn't
running.

An optional global shortcut (off by default, in Settings) cycles Automatic →
each running player → Automatic and shows a brief on-screen message with the
new target (switch that off in Settings; the menu bar icon also flashes the
name). It defaults to **⌃⌥⌘M**; in Settings, click the shortcut button and press
a new combination to remap it (it needs ⌘, ⌥ or ⌃; Esc cancels, **Reset**
restores the default). If another app already owns the combination, Settings
says so. It uses a plain global hotkey, so it needs no extra permission.

Limits: MediaRemote only reports and controls one Now Playing app, so this
works for scriptable native apps only, which is why the list is a short
allowlist. TIDAL has no AppleScript dictionary: it appears as "launch only"
and, if picked, is just opened (instead of the replacement) when nothing is
playing. Browser tabs can't be targeted. Any other bundle ID can be set with
`defaults write dev.drumandbytes.musicrouter targetApp <bundle-id>`. The first
key sent to an app triggers macOS's Automation prompt for it.

## Resuming the last player

The adapter's stream also says *which* app is playing. Music Router remembers
the last bundle ID that was actively playing. When nothing owns Now Playing
and you press a media key, it sends the key (AppleScript `playpause` / `next
track` / `previous track`) to that app if it is still running and
scriptable, instead of launching the fixed replacement. Otherwise (the app
quit, isn't scriptable, or nothing has played since launch) it falls back to
the replacement as before. On by default; **Resume last player** in Settings
turns it off (`defaults write dev.drumandbytes.musicrouter resumeLastPlayer
-bool false`).

Limits: the memory is per launch, not saved. A paused player usually keeps
Now Playing (the key reaches it through macOS), so this mostly applies after
an app stops or drops its session. Browser tabs report the browser or a
WebKit/Chromium helper process, which doesn't understand those AppleScript
verbs, so they fall back to the replacement. The first send to an app
triggers macOS's Automation permission prompt for it. Music/iTunes is never
a target.

## When detection fails

If the adapter can't start or stops answering (a macOS update broke
MediaRemote access, `/usr/bin/perl` is missing, the build lacks the bundled
framework), the app keeps working: Music is still blocked and media keys are
still routed. It falls back to a public CoreAudio check ("is any process
driving the default output device?") in place of Now Playing. That's coarser:
a paused player isn't detected (the key then goes to the replacement), and
unrelated audio such as a call counts as "playing" (the key passes through
to macOS). The adapter is relaunched with backoff and takes over again as
soon as it reports data. A stalled adapter is caught too: the stream only
prints on change, so if it claims nothing is playing while audio keeps running
for ~15 s, the app asks the adapter once (`get`); if that names a player, the
stream is restarted and the fallback is used meanwhile. **Settings → Now
Playing detection** shows Working / Starting / Unavailable with the reason. A
noTunes-style app with no Now Playing check at all has no equivalent.

## Known limits

- **Music launched by AirPlay, Handoff or Siri is killed after it starts**,
  not prevented; there's no public hook to veto those launches.
- **MediaRemote reports and controls one Now Playing app.** Targeting and
  last-player resume work for scriptable native apps only; browser tabs get
  the keys through macOS when they own Now Playing, but can't be targeted.
- **Now Playing detection uses a private framework** through the adapter
  technique and can break on a macOS update; the CoreAudio fallback then
  applies.
- **Ad-hoc signed**, so the one-time Gatekeeper prompt and signing-bound
  permissions apply (see [Development](development.md#signing)).
