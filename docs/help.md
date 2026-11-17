# Music Router help

Quick answers for the usual problems. For how it works, see
[How it works](how-it-works.md); for every setting, [Configuration](configuration.md).

## Media keys do nothing

Music Router needs **two** permissions to intercept the keys, and macOS can
half-grant them:

1. System Settings → Privacy & Security → **Input Monitoring** → Music Router on.
2. System Settings → Privacy & Security → **Accessibility** (called **Device
   Control and Data Access** on macOS 27) → Music Router on.

The menu and **Settings → Permissions** show each grant with a green check or a
red cross; click a row in the menu to open its pane. After an update, or if you
rebuilt the app yourself, a grant can look enabled but be tied to the old
signature. Use **Reset Permissions…** (Settings): it clears both grants
and relaunches the app so you can grant them again. By hand:

```bash
tccutil reset ListenEvent dev.drumandbytes.musicrouter
tccutil reset Accessibility dev.drumandbytes.musicrouter
```

## Music.app still opens sometimes

Pressing a media key is handled before Music can launch. Music launched by
**AirPlay speaker selection, Handoff from an iPhone or Siri** has no hook to
stop it, so Music Router closes it immediately after it starts (you may see it
flash). That's a limit of macOS, not a bug.

## The key goes to the wrong app

- By default **Now Playing decides**: whatever app or browser tab owns it gets
  the key; when nothing does, Music Router starts your **Replacement app**.
- With **Resume last player** on, "nothing is playing" first tries the app that
  played last, if it's still running and scriptable.
- To always send the keys to one player, pick it under **Media Key Target**
  (Spotify or VLC). Browser tabs can't be targeted.
- A paused player normally still owns Now Playing, so the key resumes it
  through macOS.

## "Now Playing detection" says Unavailable

Settings → **Now Playing detection** shows `Working`, `Starting…` or
`Unavailable: <reason>`. When unavailable (a macOS update broke MediaRemote
access, `/usr/bin/perl` is missing, or the build lacks the bundled adapter)
Music Router keeps blocking Music and routing keys, using a coarser check: "is
any audio playing?". A paused player then isn't detected, and unrelated audio,
such as a call, counts as playing. It retries the adapter automatically.

## The shortcut doesn't work

- **Settings → Media key target → Cycle with a shortcut** must be on.
- Combinations need ⌘, ⌥ or ⌃. If another app already uses yours, Settings says
  so; record a different one. **Reset** restores ⌃⌥⌘M.
- With only one player running, cycling just toggles between **Automatic** and
  that player; the on-screen message shows which.

## Command line and scripting

`musicrouter-media stream|get|toggle|play|pause|next|previous` reads and
controls Now Playing (installed with Homebrew, otherwise in
`MusicRouter.app/Contents/Resources`). Every setting is a `defaults` key; the
table is in [Configuration](configuration.md#defaults-keys).

## Report a bug

Turn on **Debug logging** in Settings (or `defaults write
dev.drumandbytes.musicrouter debugLogging -bool true`), reproduce the problem,
then **Reveal Log in Finder** and attach `~/Library/Logs/MusicRouter.log` to an
[issue](https://github.com/drumandbytes/music-router/issues).

The log records only: which of the three media keys was pressed (play/pause,
next, previous) and whether it was swallowed or passed through, the bundle ID of
whichever app owns Now Playing and when that changes, and adapter/event-tap
start and stop. Never other keys, track titles, artists, or window contents. It
rotates at 2 MB, keeping one older file (`MusicRouter.log.1`), and costs nothing
while off.

## Remove it

```bash
brew uninstall --zap music-router
```

removes the app and its preferences. Remove the privacy grants in System
Settings → Privacy & Security if they linger.
