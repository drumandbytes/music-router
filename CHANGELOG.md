# Changelog

## [1.1.1](https://github.com/drumandbytes/music-router/compare/v1.1.0...v1.1.1) (2026-11-17)


### Bug Fixes

* **ui:** keep menu icons visible on macOS 27 ([#48](https://github.com/drumandbytes/music-router/issues/48)) ([7dd6645](https://github.com/drumandbytes/music-router/commit/7dd6645612dab4652036029825efea2c3093dff5))

## [1.1.0](https://github.com/drumandbytes/music-router/compare/v1.0.0...v1.1.0) (2026-11-17)


### Features

* **target:** remappable cycle shortcut ([#45](https://github.com/drumandbytes/music-router/issues/45)) ([7512cf2](https://github.com/drumandbytes/music-router/commit/7512cf2185a8328ec3edd64ed4c3875ae46bb75a))
* **ui:** liquid-glass Settings, menu icons, dialogs, About and a Help page ([#47](https://github.com/drumandbytes/music-router/issues/47)) ([e2c4b39](https://github.com/drumandbytes/music-router/commit/e2c4b39b20d62fac029f9578e23ab847928e12cc))

## [1.0.0](https://github.com/drumandbytes/music-router/compare/v0.6.2...v1.0.0) (2026-11-17)


### Features

* **cli:** bundle musicrouter-media wrapper around the adapter ([#41](https://github.com/drumandbytes/music-router/issues/41)) ([d6828e4](https://github.com/drumandbytes/music-router/commit/d6828e4d6ca3e765adc21baa7efd993f1a83659d))
* **now-playing:** fall back to CoreAudio when the adapter fails ([#38](https://github.com/drumandbytes/music-router/issues/38)) ([b5f8927](https://github.com/drumandbytes/music-router/commit/b5f892773fa2cf40ed6648d4741b1d2f08f05798))
* **now-playing:** vendor mediaremote-adapter instead of media-control CLI ([#37](https://github.com/drumandbytes/music-router/issues/37)) ([5a64856](https://github.com/drumandbytes/music-router/commit/5a64856a8b1e025b92d6393c8a92e2d0652296dd))
* **resume:** resume the last playing app instead of launching the replacement ([#39](https://github.com/drumandbytes/music-router/issues/39)) ([85d959c](https://github.com/drumandbytes/music-router/commit/85d959c09f6325cde536a49d33175e418a33835f))
* **target:** pick which app gets the media keys ([#40](https://github.com/drumandbytes/music-router/issues/40)) ([2a479ff](https://github.com/drumandbytes/music-router/commit/2a479ff8efa834825c123e57092b1296c7699901))


### Documentation

* **readme:** cover bundled adapter, fallback, resume, target app and CLI ([#43](https://github.com/drumandbytes/music-router/issues/43)) ([7d09ee0](https://github.com/drumandbytes/music-router/commit/7d09ee0a154f2997bcbda0748f2cbce8534fad06))

## [0.6.2](https://github.com/drumandbytes/music-router/compare/v0.6.1...v0.6.2) (2026-10-25)


### Bug Fixes

* place settings window inside the visible screen area ([#34](https://github.com/drumandbytes/music-router/issues/34)) ([a3dd09b](https://github.com/drumandbytes/music-router/commit/a3dd09b6f6836a06d6812ba03cd07267d42e9af2))

## [0.6.1](https://github.com/drumandbytes/music-router/compare/v0.6.0...v0.6.1) (2026-10-25)


### Bug Fixes

* settings window placement and layout; open on launch when icon is hidden ([#32](https://github.com/drumandbytes/music-router/issues/32)) ([72d01d4](https://github.com/drumandbytes/music-router/commit/72d01d4456f0f3d017c3eb6e227a5019850fb8c0))

## [0.6.0](https://github.com/drumandbytes/music-router/compare/v0.5.0...v0.6.0) (2026-10-25)


### Features

* settings window, usable with the menu bar icon hidden ([#30](https://github.com/drumandbytes/music-router/issues/30)) ([16a7a3c](https://github.com/drumandbytes/music-router/commit/16a7a3c764e6f96c8cabc4bdca2257376d33300e))

## [0.5.0](https://github.com/drumandbytes/music-router/compare/v0.4.4...v0.5.0) (2026-10-21)


### Features

* opt-in debug logging to ~/Library/Logs/MusicRouter.log ([#28](https://github.com/drumandbytes/music-router/issues/28)) ([02bebfd](https://github.com/drumandbytes/music-router/commit/02bebfd233dd3a30531b9f97ce2780c0b1de2d68))

## [0.4.4](https://github.com/drumandbytes/music-router/compare/v0.4.3...v0.4.4) (2026-10-21)


### Bug Fixes

* restart media-control stream after it exits ([#26](https://github.com/drumandbytes/music-router/issues/26)) ([560da9d](https://github.com/drumandbytes/music-router/commit/560da9d89f86ec85a89368f65dfc4677985e63a9))

## [0.4.3](https://github.com/drumandbytes/music-router/compare/v0.4.2...v0.4.3) (2026-09-16)


### Bug Fixes

* persist enabled state, harden tap self-healing, surface silent failures ([4593fa7](https://github.com/drumandbytes/music-router/commit/4593fa740e0bdb8efb45385b9a73bd8b3cd99721))
* persist enabled state, harden tap self-healing, surface silent failures ([e20ae05](https://github.com/drumandbytes/music-router/commit/e20ae055c5a3ee617ddae0be884572bb22aa3499))

## [0.4.2](https://github.com/drumandbytes/music-router/compare/v0.4.1...v0.4.2) (2026-09-16)


### Bug Fixes

* detect media-control process death, close a threading loose end, test the swallow decision ([617658f](https://github.com/drumandbytes/music-router/commit/617658ff0897c84e4e73f2e5ba19d8d33dfea372))
* detect media-control process death, close a threading loose end, test the swallow decision ([32218d2](https://github.com/drumandbytes/music-router/commit/32218d2fdf80dd358472dc63c22c720dad1261d9))

## [0.4.1](https://github.com/drumandbytes/music-router/compare/v0.4.0...v0.4.1) (2026-09-16)


### Bug Fixes

* eliminate a data race in NowPlayingObserver's buffer ([f459f86](https://github.com/drumandbytes/music-router/commit/f459f86c2799fecb6d7b9ca3266cb6ae7e719e9b))
* eliminate a data race in NowPlayingObserver's buffer ([3f097ff](https://github.com/drumandbytes/music-router/commit/3f097ff7c043d632d749cae04e90bbea04ae832f))

## [0.4.0](https://github.com/drumandbytes/music-router/compare/v0.3.0...v0.4.0) (2026-09-16)


### Features

* add permissions diagnostics and reset to the menu ([161d344](https://github.com/drumandbytes/music-router/commit/161d34459b45ab28832833772d2b8b9d09e7054a))
* add permissions diagnostics and reset to the menu ([a355ab6](https://github.com/drumandbytes/music-router/commit/a355ab6da0e6aae21b95bc203c09e73c86a86205))
* real playback control instead of just opening the replacement ([d986e02](https://github.com/drumandbytes/music-router/commit/d986e020925570fef0eb400e3ddb510daed8164e))
* real playback control instead of just opening the replacement ([4cf2815](https://github.com/drumandbytes/music-router/commit/4cf2815e67dadf668e9897b5df3ddea1d11961aa))


### Bug Fixes

* force a new process on relaunch with open -n ([f7ec98d](https://github.com/drumandbytes/music-router/commit/f7ec98da00d30d2493ec17550f6ccc6903718177))
* relaunch automatically after resetting permissions ([f66a0c2](https://github.com/drumandbytes/music-router/commit/f66a0c25fde5b63543334703e75b2b68338f041c))
* sequence the two TCC permission prompts, show both distinctly ([51c895b](https://github.com/drumandbytes/music-router/commit/51c895b6835c3f32b41699ef201cb30961cf3296))
* stop the media-control child process on quit ([c8f76b2](https://github.com/drumandbytes/music-router/commit/c8f76b262a1aa74d09a380080169ad4cac07c801))

## [0.3.0](https://github.com/drumandbytes/music-router/compare/v0.2.0...v0.3.0) (2026-09-15)


### Features

* add About and Help menu items ([7d6d4f9](https://github.com/drumandbytes/music-router/commit/7d6d4f9cac6e5ec69b06d37b6f60952121157e54))

## [0.2.0](https://github.com/drumandbytes/music-router/compare/v0.1.0...v0.2.0) (2026-09-15)


### Features

* add Custom URL menu option ([8af7f89](https://github.com/drumandbytes/music-router/commit/8af7f892951585820a018240455eaaf1c037f94a))
* dim menu bar icon when disabled ([ae6581e](https://github.com/drumandbytes/music-router/commit/ae6581eadcceaedab9750be245477fc5fe79f46a))
* label web-player entries in the Replacement App menu ([ef99c0c](https://github.com/drumandbytes/music-router/commit/ef99c0c637ea894ad853e68b4d4e96bd6f5b6d4b))
