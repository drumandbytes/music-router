# Changelog

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
