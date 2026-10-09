# openplanet.dev submission

Upload: `dist\StreamOnlyHUD.op` (build it with `pack.ps1`). Version 1.0.0, game: Trackmania (2020).

## Short description

Hide the splits, timer and other HUD parts from your own screen while your viewers still see them on stream.

## Description

Stream-Only HUD lets you choose, item by item, what you see in game and what your viewers see in OBS.
Hide the checkpoint splits (or every time) from yourself so you can focus on the run, and your stream
still shows them in the usual place.

**What it can hide from you**

- Checkpoint splits, race timer, checkpoint & lap counter, records panel (the game's own HUD)
- Medals & personal best (a built-in panel)
- Inputs, gear & RPM, and speed from the Dashboard plugin, if you use it

**How it works**

The plugin moves the hidden HUD parts off your screen, so the game keeps updating them, and serves a
local page at `http://127.0.0.1:7878/` that you add to OBS as a Browser source (1920 x 1080). That page
draws the hidden parts for viewers, at the position the game uses. The server only listens on your own
PC (127.0.0.1) and nothing is sent anywhere else.

**Setup**

1. Install it. A setup window opens.
2. In OBS add a Browser source, paste the link from the window and set 1920 x 1080.
3. Untick "On my screen" for what you want hidden. Press F7 to peek at the hidden items during a run.

**Notes**

- The checkpoint sound still plays. Turn it down in the game's audio settings if it gives the split away.
- Records rows and your PB only show for players whose game edition has record access.
- When a Dashboard part is hidden from you, the plugin turns that part off in Dashboard's settings and
  turns it back on when you tick it again. Disabling this plugin puts your own Dashboard settings back.

Source: https://github.com/jypy933/tm-stream-only-hud (MIT)

## Answers for the reviewer

- **Network:** a localhost-only HTTP server (`Net::Socket` listening on 127.0.0.1) for the OBS Browser
  source. No outgoing requests.
- **Records:** no leaderboard requests. The records panel copies the rows the game's own UI already
  shows; the PB comes from `ScoreMgr`. Both are skipped without `Permissions::ViewRecords()`.
- **Other plugins:** writes Dashboard's `Setting_General_Show<Part>` / `...Hidden` settings to hide a part
  from the player. It stores the original value and restores it on re-tick, unload, or the next start
  after a crash.
- **AI use:** _fill this in honestly. The site requires AI use to be disclosed during review and in the
  plugin's AI classification settings._

## Before uploading

- [ ] Load 1.0.0 in Developer mode once and check `Openplanet.log` has no compile errors.
- [ ] Test online on a server, across a map change: hidden items stay hidden and still show in OBS.
- [ ] Thumbnail: a real in-game or OBS screenshot (the site does not allow AI-generated thumbnails).
- [ ] Commit, tag `v1.0.0` and attach the `.op` to a GitHub release.
