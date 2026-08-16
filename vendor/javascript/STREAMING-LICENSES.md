# Streaming player dependencies

- Vidstack 0.6.15 — MIT License — https://github.com/vidstack/player
- hls.js 1.7.0 — Apache License 2.0 — https://github.com/video-dev/hls.js

The browser distributions are pinned and self-hosted. `vidstack.js` is a
prebuilt bundle of the framework-independent custom elements used by Bonfire;
`hls.js` is the upstream ESM distribution. Production deployment does not run
Node or fetch either dependency from a CDN.
