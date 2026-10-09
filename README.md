# Stream-Only HUD

Lets a Trackmania streamer choose, element by element, what they see on their own screen
and what viewers see on stream.

| Element | Source |
|---|---|
| Checkpoint splits | game (`UIModule_Race_Checkpoint`) |
| Race timer | game (`UIModule_Race_Chrono`) |
| Checkpoint & lap counter | game (`UIModule_Race_LapsCounter`) |
| Records panel | game (`UIModule_Race_Record`) |
| Medals & personal best | drawn by this plugin |
| Inputs (Dashboard) | the Dashboard plugin's pad (gamepad or keyboard) |
| Gear & RPM (Dashboard) | the Dashboard plugin's gearbox |
| Speed (Dashboard) | the Dashboard plugin's speedometer |

Each element has two ticks, **On my screen** and **On stream**:

| On my screen | On stream | Result |
|---|---|---|
| yes | (forced yes) | Everyone sees it. OBS captures the game as usual. |
| no | yes | Only viewers see it. Hidden in game, redrawn by the OBS overlay. |
| no | no | Hidden for everyone. |

"On my screen but not on stream" can't exist: OBS records the screen, so anything the
player sees is on stream. The window explains this when hovering the greyed-out tick.

**Show/hide key** (default F7, changeable or removable in the window): temporarily puts the
stream-only elements back on the player's screen, then hides them again. Saved choices
don't change.

## How it works

- **Hiding:** every native module has a root frame `frame-global` whose position the game
  never touches. The plugin moves it off-screen. The game keeps running the module, so the
  plugin reads exactly what it would have shown (PB diff, colours, ranks).
- **Dashboard parts:** another plugin's drawing is part of the game picture, so it can't
  be split between screen and stream. When "On my screen" is unticked, the plugin switches
  that Dashboard part off through Openplanet's settings API (and switches it back on when
  re-ticked or when this plugin unloads). The overlay redraws it from live car data
  (`VehicleState`) using Dashboard's own position, size, colours and pad type.
- **Showing on stream:** a localhost-only HTTP server (`127.0.0.1:7878`) serves a
  full-screen overlay page and a live event stream (`/events`): HUD state 10x per second,
  car inputs up to 60x per second so the pad moves smoothly. In OBS it's a 1920x1080 Browser
  Source; each element is drawn at the position the game uses, so nothing needs placing.
- **Feedback:** the plugin sees when OBS polls, so the in-game window shows
  "OBS is connected" and warns if hidden elements aren't reaching viewers. "Show a test
  picture in OBS" displays a green banner and sample elements on stream for 30 seconds.

## Getting it to the streamer (the easy way)

Unsigned plugins only load in Openplanet's Developer mode, which turns on School Mode
(no online play, no leaderboard records). For a streamer that's a non-starter, so the
plugin needs to be published and signed:

1. Run `pack.ps1` to build `dist\StreamOnlyHUD.op` (or download it from the latest
   GitHub release).
2. On openplanet.dev, sign in, create a new plugin, upload the `.op` and ask for it to be
   signed. The Openplanet team reviews it.
3. Once approved, the streamer installs it in game: **F3 > Plugin Manager > Open manager >
   search "Stream-Only HUD" > Install**. Updates arrive the same way.

Then send them [STREAMER_GUIDE.md](STREAMER_GUIDE.md) (or just the in-game window: it opens
on its own the first time and walks through OBS).

## Testing it yourself before publishing

Copy the `StreamOnlyHUD` folder into `C:\Users\<you>\OpenplanetNext\Plugins\`, switch
Openplanet to **Developer > Signature Mode > Developer** (needs Club access, offline maps
only), then **Developer > Load plugin**. Check `Openplanet.log` for compile errors.

## Limits

- The checkpoint **sound** still plays (higher when ahead, lower when behind). It can be
  turned off in the game's audio settings.
- If Nadeo renames a module or its control IDs, that element simply shows normally again
  in game until the IDs are updated in `src/Elements.as`.
- Other Openplanet plugin windows can't be hidden from the player but shown on stream:
  they are drawn into the game picture. That's why the medals panel is built in and the
  Dashboard parts are redrawn. Dashboard's gradient fills aren't copied (solid colours only).

## License

MIT. See [LICENSE](LICENSE).
