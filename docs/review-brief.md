# Review brief: Stream-Only HUD 0.4.1

Please review this Trackmania (2020) plugin before it is submitted to openplanet.dev for signing.
The files to review are attached: `info.toml`, `overlay.html` and `src/*.as`.

## What it is

An Openplanet plugin, written in Openplanet's AngelScript dialect against the Openplanet API
(`Meta::`, `UI::`, `Net::Socket`, `Json::`, `Permissions::`, game classes such as
`CGameManiaAppPlayground` and `CGameManialinkFrame`). It lets a streamer hide HUD parts from their
own screen while viewers still see them in OBS:

- **Native HUD** (splits, timer, CP/lap counter, records panel): the module's root frame
  `frame-global` is moved off-screen, so the game keeps updating it, and the plugin reads its
  labels (`Element.as`, `Elements.as`).
- **Medals & PB panel**: drawn by the plugin itself (`Medals.as`).
- **Dashboard plugin parts** (inputs, gear, speed): another plugin's drawing can't be split between
  screen and stream, so the plugin switches that Dashboard part off through Dashboard's settings and
  restores it later. The original value is saved so it survives a crash (`Dashboard.as`).
- **Overlay**: a localhost-only HTTP server (`127.0.0.1:7878`) serves `overlay.html` to an OBS
  Browser Source, plus a Server-Sent Events stream at `/events` (state 10x/s, car inputs up to
  60x/s) and a `/state` polling fallback (`Server.as`, `overlay.html`).
- **Main loop**: `Main.as` runs the update loop with error handling. After 60 failing frames in a
  row it gives the HUD back and stops.

## Changed since 0.4.0 (focus here)

1. `Dashboard.as`: crash-safe takeover (`S_DashTakeover`, saved straight away with
   `Meta::SaveSettings()`), and a warning when a Dashboard setting is missing.
2. `Main.as`: try/catch around the loop, give-up path, `g_stopped` flag. `timeout = 0` removed
   from `info.toml`.
3. `Elements.as` / `Medals.as`: records rows and PB are skipped without `Permissions::ViewRecords()`.
4. `Elements.as`: attached HUD layers that left `cmap.UILayers` are detached, so a replaced layer
   is found again (on servers the playground lives on across maps).
5. `Server.as`: HTTP/SSE strings were broken across raw newlines; they now use `\r\n` / `\n` escapes.
6. `overlay.html`: the event stream reopens itself and falls back to polling after 3 failures.
7. `info.toml`: version 0.4.1, `optional_dependencies = [ "Dashboard" ]`.

## What I need from you

- **Correctness bugs**: give a concrete scenario, the file and line, and what goes wrong.
- **Code that may not compile** under Openplanet AngelScript, e.g. a handle vs value mistake,
  `const` misuse, a wrong API name or signature, or `is` comparisons on game objects. The code has
  **not** been compiled yet, because we can't load unsigned plugins without Club access.
- **Anything that would get the plugin rejected** under Openplanet's plugin rules: bypassing paid
  features, requesting leaderboards, unsafe networking, or modifying another plugin badly.
- **Cases where the player's HUD or Dashboard settings could end up permanently wrong**: a crash,
  disabling the plugin mid-run, a map change, Dashboard missing or disabled.

Please rank findings by severity. Say how sure you are about each one, and mark guesses about the
Openplanet API as guesses. Skip style nitpicks and rewrites that change behavior without fixing a bug.

## Known and accepted (no need to report)

- The checkpoint sound still plays.
- The `/state` polling fallback has no car data, so Dashboard parts don't animate in that mode.
- "On my screen but not on stream" is impossible by design, because OBS captures the screen.
- The server has no CORS headers. It only serves non-sensitive HUD data on 127.0.0.1.
