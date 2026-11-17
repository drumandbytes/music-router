# Music Router

A menu-bar utility that stops Music.app/iTunes from launching when you don't
want it to, and routes your keyboard's media keys to whichever app should
actually get them.

[More Drumandbytes projects](https://drumandbytes.com/projects/?ref=music-router-readme)

<p align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/img/menu-dark.png">
  <img src="docs/img/menu-light.png" alt="Music Router menu: Enabled, Replacement App, Media Key Target, Settings, permission status, About, Help, Quit" width="330">
</picture>
</p>

A more functional, actively-maintained alternative to
[noTunes](https://github.com/tombonez/noTunes). It stops Music.app by quitting it
the instant it launches, the approach that works without weakening the system:
Music.app lives on macOS's sealed, SIP-protected system volume, so it can't be
removed, renamed or locked down, and there is no public API to veto another app's
launch. Reacting to the launch covers every trigger (a media key, AirPlay,
Handoff, Siri). On top of that, a lower-level fix means a media key never
launches Music in the first place, and the replacement app is actually *played*,
not just opened. See [How it works](docs/how-it-works.md#two-blocking-mechanisms).

I wrote it because noTunes hadn't been updated for about 15 months (last commit
August 2024, as of November 2026) and I wanted it to keep working on current
macOS, with the media keys behaving too. I use Music Router myself every day.

## What it does

- **Blocks Music.app/iTunes** from launching: media keys are intercepted
  before macOS can launch it (no flash), and anything else that launches it
  (AirPlay, Handoff, Siri) is terminated immediately.
- **Leaves alone what's already playing.** If any app or browser tab owns
  Now Playing, the key goes straight through to it, exactly as without this
  app.
- **Starts something useful when nothing is playing**: the last app that
  played (if still running and scriptable), otherwise your replacement app
  (Spotify, TIDAL, VLC, a web player, any app), actually playing, not just
  opened.
- **Pin a media-key target** among several players (Spotify, VLC) from the
  menu or with a remappable global shortcut (⌃⌥⌘M by default).
- **Keeps working when Now Playing detection breaks**: it falls back to a
  CoreAudio check, restarts the adapter and shows the state in Settings.
- **No extra install for Now Playing**: the MediaRemote adapter is bundled,
  and a small `musicrouter-media` command-line tool exposes it to scripts.
- Menu bar icon (hideable), Settings window, launch at login, permission
  reset and opt-in debug logging.

## Install

```bash
brew install drumandbytes/tap/music-router
```

No other dependencies: the MediaRemote adapter is bundled (earlier versions
needed `brew install media-control`, which you can remove if nothing else uses
it), and the cask also links the `musicrouter-media` command-line tool onto your
`PATH`.

It's ad-hoc signed (no Apple Developer Program enrollment, unnecessary for a
personally-distributed tool), so macOS shows the normal one-time "unidentified
developer" prompt on first launch: approve it in System Settings → Privacy &
Security → Open Anyway.

First launch asks for **Input Monitoring** and **Accessibility** (called
**Device Control and Data Access** on macOS 27). Both are needed to intercept
the media keys. The prompt only shows once; the menu and Settings show each
grant and its status afterwards.

## Use

Click the note icon: **Enabled**, **Replacement App** (a shortlist, any local
app, a web player, or block only), **Media Key Target**, **Settings…** (⌘,),
the two permission rows, **About** and **Help**. Everything else (resume last
player, the shortcut, launch at login, logging) is in Settings.

<p align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/img/settings-dark.png">
  <img src="docs/img/settings-light.png" alt="Music Router Settings: routing, media key target, general, permissions and Now Playing detection" width="400">
</picture>
</p>

With the optional shortcut on, ⌃⌥⌘M cycles which player gets the media keys and
shows a short message:

<p align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/img/toast-dark-spotify.png">
  <img src="docs/img/toast-light-spotify.png" alt="Toast: Media keys, Spotify" width="168">
</picture>
&nbsp;&nbsp;
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/img/toast-dark-automatic.png">
  <img src="docs/img/toast-light-automatic.png" alt="Toast: Media keys, Automatic" width="197">
</picture>
</p>

## Documentation

- **[Help](docs/help.md)**: keys do nothing, wrong app gets the key, detection
  status, the shortcut, reporting a bug, removal.
- **[Configuration](docs/configuration.md)**: the menu and Settings in full, every
  `defaults` key, the `musicrouter-media` command line.
- **[How it works](docs/how-it-works.md)**: the two blocking mechanisms, how keys
  are routed, the Now Playing adapter, the fallback, and the known limits.
- **[Development](docs/development.md)**: building, testing, signing, third-party
  code and how the project is maintained and released.

## How it compares

Quitting Music as it launches is an established technique. Music Router builds
on it and goes further:

- **Media keys never launch Music.** They're intercepted before macOS acts on
  them, so there's no launch-then-quit flash for the most common trigger.
- **Whatever is playing keeps the keys.** If an app or browser tab owns Now
  Playing, the key goes straight to it, untouched.
- **It starts the right thing.** With nothing playing, the last player resumes,
  or your replacement app begins *playing*, not just opening. Or pin the player
  that always gets the keys, with a remappable shortcut to switch.
- **It keeps working when macOS changes.** If Now Playing detection breaks, it
  falls back, recovers on its own and says so in Settings.
- **Scriptable and configurable.** A Settings window, every option as a
  `defaults` key, and a `musicrouter-media` command line for status bars and
  scripts.

The trade-off: intercepting keys needs **Input Monitoring** and
**Accessibility** permission, which a simpler quit-on-launch app doesn't. Music
Router doesn't control browser tabs itself; it leaves that to macOS and routes
the keys to whichever tab owns Now Playing.

## Limits

Music launched by AirPlay, Handoff or Siri is closed right after it starts, not
prevented. Targeting and resume work for scriptable native apps only. Now
Playing detection uses a private framework and can break on a macOS update (a
fallback keeps blocking and routing working). It's ad-hoc signed. Details in
[How it works](docs/how-it-works.md#known-limits).

## How it was made

Built with the help of an AI coding assistant (Claude). I review and test what gets published.

## License

MIT
