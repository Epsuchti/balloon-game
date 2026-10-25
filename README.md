# Balloon Crew

A 2D pixel-art couch co-op game: crew a hot-air balloon through an auto-generated cave and land it
softly on the platform at the end. Every station is always on board, so a small crew runs between
them while a big crew mans them all; the pressure scales with the crew. Built with Godot 4.5 (GDScript)
for Windows, macOS and Linux.

Art, sound effects and the 8-bit soundtrack are generated in code (`scripts/autoload/art.gd`,
`sfx.gd`, `music.gd`). The only binary assets are two OFL-licensed pixel fonts in `assets/fonts`
(Pixelify Sans and Press Start 2P, licences next to them).

## Running it

1. Install [Godot 4.5](https://godotengine.org/download) (standard build, not .NET).
2. Open `project.godot` in Godot and press **F5**, or from a terminal: `godot --path .`

## How to play

- **Win:** touch down on the landing platform slower than the allowed speed.
- **Lose:** the balloon is destroyed, you hit the platform too fast, or you run out of fuel for good.
- **Score:** the gold you collected. It only counts if you land; crashes are kept in the history with 0.

Players run and jump around inside the basket. Walk up to a station and press **A** to take it,
**B** to leave it free for someone else. Fuel cans and ammo crates sit in the hold at the bottom of the
basket; pick one up with **A**, carry it to the burner (fuel) or turret (ammo) and press **A** there to
refill it. When fuel or ammo runs low, a yellow arrow blinks over the supplies in the hold and another
points at the station while someone carries a matching item. Mind the open edges:
jump over a rail and you parachute down until the fisher reels you in or you respawn (and the crew
loses a little gold).

All eight stations (burner, shrinker, propeller, shooter turret, fishing rod, repair kit, lamp and a
second propeller) are on board at every crew size. Nobody can man everything, so the crew decides who
runs where. What changes with the crew size is the pressure, so two players are as busy as eight:

| | 2 players | 4 players | 8 players |
|---|---|---|---|
| A station breaks down every (Normal) | ~31 s | ~21 s | ~13 s |
| Stations broken at once, at most | 1 | 2 | 3 |
| Enemy spots that spawn an enemy | 20% | 55% | all |
| Boss hit points | 28 | 40 | 64 |

- **Breakdowns:** smoke and a red **!** mean a station broke. It does nothing until someone takes it
  and holds **A** for about 1.6 s. A broken burner gives no heat, a snagged shrinker rope pulls the
  envelope in, a broken repair kit means the envelope sprang a leak and the hull wears down.
- **The hull never heals by itself.** Patch it at the repair kit. Collisions hurt (twice as much as
  before), bats ram up to three times, bombers explode, harpies peck once they board.
- **Fuel is scarce:** one spare can at the start, each can holds a third of the tank, and only a
  few more turn up in the level and from enemies.
- **The Grumpus**, a big grumpy fuzzy blob, turns up a little past halfway in three out of four levels
  (decided by the level code). It spits grumble balls (the turret can shoot them down), winds up and
  rams the balloon, and stomps off after 45 s if nobody shoots it down. Beating it pays 40 gold plus fuel
  and ammo.
- **Night** sections only happen with 7 or more players. The first segment is always calm.

After everyone presses Ready in setup, a controls screen shows the buttons, every station and how
refilling, breakdowns and the boss work. Each player presses **A** to confirm they read it (B takes it back); the run starts once
all players have confirmed.

Players can join (press any button on a new controller) and leave at any time during a run.
An unplugged controller's character waves for 10 seconds; plug it back in to keep playing.

### Controls

| Action | Gamepad | Keyboard 1 | Keyboard 2 |
|---|---|---|---|
| Move / aim | Left stick, D-pad (right stick aims) | WASD | Arrow keys |
| Jump, take station, pick up, use station | A | Space | `.` or Numpad 0 |
| Leave station, drop item | B | Q | `/` or Numpad `.` |
| Shove a boarder overboard | X | E | `,` or Numpad 1 |
| Drop through the deck | Down + A | S + Space | Down + `.` |
| Setup: pick station | LB / RB | 1 / 3 | `[` / `]` |
| Setup: random stations | Y | R | `;` |
| Setup: change difficulty | Back | `` ` `` | Backspace |
| Ready / pause | Start | Tab | Enter |

At a station: **Burner** hold A (or up) to heat, **Shrinker** hold A (or down) to pull the envelope in
and drop faster, **Propeller** push left/right, **Turret** aim and hold A, **Fishing rod** aim and press A
to cast, **Repair kit** hold A, **Lamp** aim.

### Music and fullscreen

**M** mutes or unmutes the music (menu, flight and a faster "danger" track while the boss is around or
the balloon is in trouble).

The game starts fullscreen. Toggle with **F11**, **Alt+Enter** or **Cmd+Ctrl+F** (macOS); the choice is
remembered in `user://settings.cfg`. Launch with `--windowed` to force a window for one session
(`./BalloonCrew.x86_64 --windowed`, or `open "Balloon Crew.app" --args --windowed` on macOS).

## Levels, codes and the scoreboard

A level is fully determined by its **seed + difficulty**, written as a level code like `N-8F3K2Q`
(difficulty letter, then the seed in base 32). Enter a code from the main menu to fly the same level on
another machine, or pick any entry on the scoreboard to replay it. Scores are saved locally in Godot's
`user://scoreboard.json`.

Generation runs in six steps (`scripts/level/level_generator.gd`): a pacing curve over 8-12 segments,
a smoothed flight path, a carved and roughened tunnel, set pieces (narrow gaps, stalactites, wind shafts,
floating islands, enemy nests, supply caches), a flood-fill check that the balloon fits all the way with
every tile intact, and the landing platform. Terrain is destructible: turret shots chip tiles, ramming
dirt digs through it, and bombers blow craters. The outer walls are unbreakable bedrock.

## Project layout

```
scenes/main.tscn            entry scene; screens are swapped in by the Game autoload
scripts/autoload/           Game (flow, theme), Players (input, join/leave, hot-plug), Scores, Sfx, Music, Art
scripts/core/               constants: tiles, difficulty, roles, level codes, PlayerSlot
scripts/level/              LevelData, LevelGenerator, Terrain (TileMapLayer with tile hit points)
scripts/balloon/            Balloon physics, CrewMember, Station + stations/, SupplyItem, Boarder
scripts/run/                Run (one flight, pressure director), HUD, enemies, the Grumpus boss, drops, pickups, parachutes, bullets
scripts/ui/                 main menu, setup screen (pop-the-balloons mini game), controls screen, scoreboard, UiKit
assets/fonts/               Pixelify Sans and Press Start 2P (SIL Open Font License)
tests/                      headless test runner and a bot autopilot that flies and lands whole levels
tools/                      level-to-PNG renderer, screenshot tool, soundtrack-to-WAV renderer
```

## Tests

```
godot --headless --path . --import
godot --headless --fixed-fps 60 --path . res://tests/test_runner.tscn
```

The tests cover level codes, generator determinism and passability across seeds and difficulties,
destructible terrain, the scoreboard, a smoke run with 1 and 8 bots mashing buttons, the setup screen
flow, and an autopilot crew flying and landing a full Easy and Normal level. CI runs them on every pull
request (`.github/workflows/tests.yml`).

Handy tools:

```
godot --headless --path . -s tools/render_level.gd -- N-8F3K2Q level.png   # level map as an image
xvfb-run godot --path . res://tools/screenshot.tscn -- 8 5,20 shot          # screenshots of a bot run
```

## Builds

`export_presets.cfg` has Windows, macOS (universal) and Linux presets. With Godot's export templates
installed, export from the editor (Project > Export) or:

```
godot --headless --path . --export-release "Linux" builds/linux/BalloonCrew.x86_64
godot --headless --path . --export-release "Windows" builds/windows/BalloonCrew.exe
godot --headless --path . --export-release "macOS" builds/macos/BalloonCrew.zip
```

The **Build** workflow (`.github/workflows/build.yml`) does the same on GitHub: run it from the Actions
tab or push a `v*` tag, then download the builds from the run's artifacts. Steam Deck runs the Linux build.

The macOS build is ad-hoc signed only, so macOS will warn on first launch (right-click > Open, or
`xattr -dr com.apple.quarantine "Balloon Crew.app"`). A public macOS release needs signing and
notarization with an Apple Developer account.
