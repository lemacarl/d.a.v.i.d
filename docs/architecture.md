# Shepherd King: Architecture

Godot 4.7.2, GDScript only, Google TV (remote: D-pad, OK, Back). Fully offline: no INTERNET permission, no network nodes, no analytics, no remote assets. Story text is defined only in `docs/script-source.md` and is copied verbatim into data files; no code or modifier ever rewrites it.

## 1. Decisions (from the human)

| Topic | Decision |
|---|---|
| Lamb | Same stages as Normal with all enemies removed. No failure. |
| Shepherd | David cannot fall. At zero hearts he is "tired" and rests 3 s, then continues. |
| Normal | As written in the script. |
| Timeout (2.2, 3.9) | Normal restarts the stage. Shepherd and Lamb ignore the timer. |
| Goliath out of stones | Normal: restart at stage 2.5. Shepherd and Lamb: stones refill. |
| Blessings | Reset at the start of each chapter. Goliath's Sword is per run, available after Nob (3.4). |
| New stage type | `delivery` for 2.2. |
| 3.3 | Player watches the arrow land, then presses OK. No other input. |
| OK input | Tap = chapter main action. Hold 2 s = Song of Courage harp. |
| Balance numbers | Live in data files (see `docs/data-schema.md`), never in code. |

## 2. Naming rules

- No underscores in any file or folder name we create. Use hyphens (`stage-base.gd`) or spaces only where unavoidable. Godot-generated names (`.godot`, `project.godot`, `export_presets.cfg`) are exempt.
- GDScript identifiers inside files (variables, functions, signals) follow normal GDScript snake_case. This rule covers file system names only.
- One folder, one single thing. A folder holds one kind of item; no mixed bins.
- One reusable class per stage type; one script per class; `class_name` in PascalCase (`StageBase`).

## 3. Folder layout

```
res://
  project.godot
  autoload/                 the four singletons only
    run-state.gd
    save-data.gd
    settings.gd
    audio.gd
  screens/                  one scene + script per top-level screen
    title/                  title.tscn, title.gd
    chapter-select/         chapter-select.tscn, chapter-select.gd
    stage-host/             stage-host.tscn, stage-host.gd
    blessing-pick/          blessing-pick.tscn, blessing-pick.gd
    run-summary/            run-summary.tscn, run-summary.gd
    pause-menu/             pause-menu.tscn, pause-menu.gd
  stages/                   one script per stage type, plus base
    stage-base.gd
    stage-cutscene.gd
    stage-protect-flock.gd
    stage-boss.gd
    stage-rhythm.gd
    stage-stealth.gd
    stage-survival-camp.gd
    stage-maze.gd
    stage-patience.gd
    stage-search.gd
    stage-delivery.gd
  stage-scenes/             one .tscn per stage type (instanced by the host)
  actors/                   David, sheep, predators, followers (one scene each)
  model/                    pure data classes, no nodes
    run-model.gd
    save-model.gd
    stage-def.gd
    modifier-stack.gd
    modifier.gd
  modifiers/                one script per mode or Blessing modifier
    mode/                   mode-normal.gd, mode-shepherd.gd, mode-lamb.gd
    blessing/               blessing-modifier.gd: ONE data-driven modifier built from a card in data/blessings.json
  data/                     see docs/data-schema.md (one file per chapter, shared files for the rest)
    chapters/ch1.json       chapter facts (one file per chapter)
    stages/ch1.json         every stage of the chapter, in order (one file per chapter)
    cutscenes/ch1.json      cutscene beats (a cutscene is a stage type, `cutscene`)
    dialogue/ch1.json       every story line of the chapter, by line id
    blessings.json          all Blessing cards
    recurring-lines.json    pools, pause menu, title, mode list, summary template
    balance.json            hearts, modes, input, `feel` numbers (speeds, radii, margins)
    audio.json              audio cue id -> file path(s), bus, loop; bus levels; narration folder
  ui/                       reusable Control scenes (focus ring, card, caption)
  theme/                    one Theme resource, fonts, focus styles
  audio/                    music and narration (offline, bundled)
  tests/                    headless runner and test scripts
    runner.gd               (file name has no underscore)
  docs/                     (outside res:// content; design docs)
```

Hyphen exceptions: the `tests/runner.gd` name is a single word on purpose. Test files are `test-<subject>.gd`.

## 4. Scene tree

`Main` is the only scene set in project settings. It owns screen swapping so no screen knows about another.

```
Main (Node)                         main.tscn, main.gd
  ScreenSlot (Control)              one active screen child at a time
  Overlay (CanvasLayer, layer 10)
    PauseMenu (instanced on demand)
  Fade (CanvasLayer, layer 20, ColorRect)   fade for defeat/transition
```

Screens (each is a `Control`, full rect, inside the 5% safe margin container):

- **Title**: `MarginContainer(SafeArea) > VBox > Label(title) + Label("Press OK to begin") + AnimatedSprite2D(sheep)`. Back here quits. Text matches script: "Shepherd King — Press OK to begin."
- **ChapterSelect**: `SafeArea > VBox > HBox of ChapterCard x4 + ModeRow (Lamb / Shepherd / Normal)`. Locked chapters are visible but unfocusable.
- **StageHost**: `Node > StageSlot (Node2D/Control) + Hud (CanvasLayer: hearts, stones, followers, timer, caption box, subtitle box)`. Loads a stage scene from `stage-scenes/`, calls `setup(stage_def, run)`, listens to its signals.
- **Cutscene**: not a screen of its own; it is the `delivery` of the `cutscene` stage type inside StageHost (`StageCutscene`). Backdrop + character sprites + subtitle label + caption label + gold-light overlay.
- **BlessingPick**: `SafeArea > VBox > Label(prompt) + HBox(3 x BlessingCard)`. Each card: name, one-line effect, verse reference. Left/right focus, OK picks.
- **RunSummary**: `SafeArea > VBox > Label(summary line) + Label(encouragement) + Button(Continue)`. Shows "Sheep saved: N · Stones thrown: N · Blessings: ...".
- **PauseMenu**: `CanvasLayer > ColorRect(dim) > CenterContainer > VBox of 4 Buttons`: Resume, Restart stage, Change mode (Lamb / Shepherd / Normal), Quit to title. Sets `get_tree().paused = true`; menu node uses `process_mode = ALWAYS`.

## 5. Autoloads (exactly four)

| Autoload | Responsibility | Never does |
|---|---|---|
| `RunState` | Holds the live `RunModel`, current stage pointer, and the `ModifierStack`. Emits run signals. | Disk I/O, UI, story text. |
| `SaveData` | Loads/saves `SaveModel` at `user://save.json`. | Gameplay decisions. |
| `Settings` | Volume, subtitle size, narration on/off; persists via `SaveData`. | Mode (mode belongs to the run and save). |
| `Audio` | Plays music, narration, harp; ducking; bus volumes. | Any game rule. |

Any other shared logic is a plain class (`model/`) held by one of these, not another autoload.

## 6. Run-state model (`model/run-model.gd`, RefCounted)

```
RunModel
  mode            : enum {NORMAL, SHEPHERD, LAMB}
  chapter         : int (1..4)
  stage_index     : int            # index into the chapter's stage list
  hearts, hearts_max : int         # hearts_max from data
  stones          : int            # carried stones (2.5 fills, 2.6 spends)
  followers       : int            # men / freed families / dancers
  blessings       : Array[StringName]   # active this chapter; cleared on chapter start
  sword_unlocked  : bool           # Goliath's Sword; per run, set at 3.4
  stats           : {sheep_saved, stones_thrown}   # for RunSummary
  rng_seed        : int
```

Rules: `start_chapter(n)` clears `blessings`, hearts, stones, followers and stats but keeps `mode`. `sword_unlocked` is set by the 3.4 cutscene and cleared when the run ends. Falling (Normal only) calls `restart_chapter()` and picks a random "David falls" line. Shepherd never reaches a fall: `hearts_depleted` triggers the 3 s rest (`rest_seconds` from data).

## 7. Save model (`model/save-model.gd`, `user://save.json`)

```
SaveModel
  version              : int
  chapters_unlocked    : int      # 1..4 (chapter n+1 unlocks when chapter n completes)
  mode                 : String   # "normal" | "shepherd" | "lamb"
  settings             : {music_volume, narration_volume, subtitle_scale}
```

Only these fields persist. No run progress is saved (a run is 10 to 15 minutes). Writes are atomic: write `save.json.tmp`, then rename. Unknown or corrupt file: fall back to defaults and keep the corrupt file as `save.json.bad`. Never written to `res://`; never sent anywhere.

## 8. Stage class model

`StageBase` (`class_name StageBase extends Node`) is the contract. Every stage type extends it and reads only its own `params` dictionary from its stage data file.

```
signal stage_started
signal stage_won
signal stage_failed(reason: StringName)        # Normal only; modifiers may veto
signal hit_taken(amount: int)
signal sheep_saved
signal stone_thrown
signal follower_added(count: int)
signal line_requested(speaker, text, reference, line_id)  # subtitles; line_id selects the narration file
signal gold_light_requested(text, reference, seconds)     # when God speaks
signal sfx_requested(cue)                                  # sound cue id from data/audio.json
func setup(def: StageDef, run: RunModel, mods: ModifierStack) -> void
func begin() -> void
func on_action_tap() -> void      # OK tap
func on_action_hold() -> void     # OK held 2 s (harp)
func get_modifier(key: StringName, base: float) -> float
```

Stage types and the data parameters each reads (names are keys inside `params`; values are in data, see schema doc):

| Stage type | Class | Params read |
|---|---|---|
| cutscene | `StageCutscene` | beats (ordered lines, captions, gold-light), tutorial_prompts, interactive (none or `arrow-watch`), unlocks, quiet_seconds, end_card |
| protect-flock | `StageProtectFlock` | night_seconds, sheep_total, sheep_min_alive, predator_spawns, drift_strength, wander |
| boss | `StageBoss` | boss_id, phases, hits_to_drop, hits_to_flee, glow_seconds, spear_lanes, stones_source, on_out_of_stones, rescue (families, time_limit, helper_per_family) |
| rhythm | `StageRhythm` | duration, note_pattern, hit_window, prompt_mode (`ok` or `arrows`), spear_dodge (dodges_to_escape, glow_time), reward_per_hit |
| stealth | `StageStealth` | patrol_paths, sight_time, hide_spots, goal, action (`collect`, `cut-robe`, `take-items`), reset_on_noticed, stones_to_collect |
| survival-camp | `StageSurvivalCamp` | days, men_goal, gather_yield, patrol_interval, scatter_amount, follower_arrival |
| maze | `StageMaze` | grid, tunnel_goal, rock_tiles, rock_interval, arrow_hints |
| patience | `StagePatience` | rustle_delay_range, rustle_window, early_press_line |
| search | `StageSearch` | villagers, hints, target_house |
| delivery | `StageDelivery` | route, time_limit, loaves_start, obstacle_types, halfway_line |

Stage lifecycle: Host creates the scene, calls `setup`, `begin`, waits for `stage_won` or `stage_failed`, then applies the outcome through `RunState`. A stage never changes screens itself.

## 9. Signals between components

```
Stage       --stage_won-->            StageHost  --> RunState.advance()
Stage       --stage_failed-->         StageHost  --> RunState.fail_stage()  (mode decides outcome)
Stage       --hit_taken-->            RunState.apply_hit()  --> hearts_changed
Stage       --line_requested-->       StageHost.LineQueue --> subtitle box; on a line's turn --> Audio.narrate(line_id)
Stage       --sfx_requested-->        StageHost --> Audio.play_sfx(cue)  (a stage never calls Audio)
RunState    --hearts_changed-->       Hud
RunState    --stones_changed-->       Hud
RunState    --followers_changed-->    Hud
RunState    --blessing_added-->       Hud, ModifierStack
RunState    --run_failed-->           Main  (fade + encouragement line, restart chapter)
RunState    --chapter_completed-->    SaveData.unlock(n+1), Main --> RunSummary
RunState    --stage_changed-->        Main (swaps in stage, or BlessingPick between stages)
BlessingPick --blessing_chosen-->     RunState.add_blessing()
PauseMenu   --resume / restart / mode_changed / quit-->  Main
Settings    --changed-->              Audio, Hud
```

Rule: components emit up, parents call down. Siblings never reference each other directly; they talk through `RunState` signals.

## 10. Modifier layer (modes and Blessings cannot change story outcomes)

Everything that tunes gameplay (the four modes, Lamb / Shepherd / Normal / Hard, and all Blessings) is a `Modifier` applied through `ModifierStack`, never by editing stage code or data in place.

```
Modifier
  id              : StringName
  func apply(key: StringName, value: float, ctx) -> float     # numeric tuning only
  func allows(event: StringName, ctx) -> bool                 # may veto a non-story event
```

Rules enforced in `ModifierStack`:

1. Whitelist of tunable keys: `walk-speed`, `stone-speed`, `enemy-speed`, `sheep-wander`, `follow-distance`, `heart-regen`, `stun-time`, `notice-time`, `enemy-spawn-enabled`, `rest-time`, `timer-enabled`, `stones-refill`, `food-start`. Any other key is ignored and logged as a test failure.
2. Story outcomes are in a separate, read-only set: `boss-defeat`, `goliath-falls`, `saul-spared`, `chapter-complete`, `line-played`. A modifier cannot be asked about these; `StageBase` never calls the stack for them. Goliath always falls on one forehead hit; Saul is always spared.
3. Mode behaviours (all via keys): Shepherd sets `enemy-speed` x data multiplier, `sheep-wander` lower, `rest-time` = 3 s (data), `stones-refill` true, `timer-enabled` false. Lamb sets `enemy-spawn-enabled` false, `timer-enabled` false, `stones-refill` true, and removes failure (`stage_failed` is converted to a retry or to a pass by `StageHost`, never to a story change).
4. Order of application: base data, mode modifier, Blessing modifiers in pick order. Percent Blessings are multiplicative (Quick Feet 1.2 on `walk-speed`).
5. Automated test (section 14) asserts that every story line, caption, and cutscene beat is identical across all 4 modes x all Blessing combos.

## 11. TV layout

- `display/window/size`: 1920 x 1080, stretch mode `canvas_items`, aspect `keep`, landscape (already set).
- **Safe area**: a `SafeArea` MarginContainer (theme-independent script) sets margins to 5% of viewport: 96 px left/right, 54 px top/bottom. All interactive and text content lives inside it. Full-bleed art may extend beyond.
- **Text sizes** (readable at 3 m on a 1080p TV): body and subtitles 40 px minimum, buttons and card text 44 px, titles 96 px, captions 40 px italic, reference lines 32 px minimum (never smaller). `subtitle_scale` setting multiplies, floor at 1.0.
- **Contrast**: light text on dark scrim at least 7:1; subtitle box has a 70% black panel.
- **Visible focus**: one shared focus StyleBox in `theme/` (4 px gold outline plus 1.05 scale tween). Every focusable control uses it. No control relies on hover. Focus must be set explicitly on every screen's first control in `_ready`.
- **Targets**: focusable items at least 96 px tall with 24 px spacing, since D-pad focus jumps are deliberate.
- Fonts: bundled, one family; no system font dependence.

## 12. Input mapping

Use the built-in actions only; no custom keys, no gamepad-only paths.

| Remote | Action | Use |
|---|---|---|
| D-pad | `ui_up`, `ui_down`, `ui_left`, `ui_right` | Move David, move focus, choose cards, rhythm arrows |
| OK | `ui_accept` | Main action (sling, hide, command, pick). Tap fires on release under 2 s |
| Hold OK 2 s | `ui_accept` held | Song of Courage harp (Lamb: harp is free play). Tracked by `HoldTracker` in the player input script |
| Back | `ui_cancel` and `NOTIFICATION_WM_GO_BACK_REQUEST` | Opens the pause menu in any stage or screen except Title |

Handling:
- Main handles `NOTIFICATION_WM_GO_BACK_REQUEST` and `ui_cancel` identically: if the Title is active it quits (`get_tree().quit()`); otherwise it opens or closes the PauseMenu. `application/config/auto_accept_quit` is already false, so quitting is our decision only.
- Nothing ever requires two buttons at once. A tap and a hold on OK are distinguished by duration only; the tap action fires on release when the press was under the hold threshold (`hold_seconds` in data = 2.0), so a hold never also slings.
- Every stage must be completable with D-pad, OK, and Back only (AC-ALL-1, AC-ALL-2).

## 13. Offline

No `INTERNET` permission (verified by aapt2 in the build log). No HTTPRequest, no multiplayer, no analytics, no ads, no remote fonts or streamed audio. All art, audio, and narration are bundled. Save data stays on device in `user://`.

## 14. Testing

Prefer a built-in headless runner over adding GUT. GUT is a new third-party addon and would need human approval; it is **not** required, so it is not proposed.

- `tests/runner.gd` extends `SceneTree`, run with `godot --headless --path . -s res://tests/runner.gd`. It discovers `tests/test-*.gd`, each a script with `func run(t)` using tiny assert helpers (`t.eq(a, b, msg)`, `t.truthy(x, msg)`), prints a summary, and exits non-zero on any failure.
- Layers:
  1. **Data tests**: every stage and blessing file validates against the schema; every script line, caption and reference matches `docs/script-source.md` exactly (AC-ALL-4).
  2. **Model tests**: RunModel, SaveModel round trip, chapter unlock, Blessing reset per chapter, sword per run.
  3. **Modifier tests**: whitelist enforced; every mode x Blessing combination leaves story outcomes and lines identical (AC-ALL-3).
  4. **Stage simulation tests**: instantiate each stage class headless with a fake clock and scripted inputs: night length 90 s plus or minus 1 s (AC-1.2a), lion drops after 3 hits and flees after 3 more (AC-1.3), Goliath falls on glow hit in every mode (AC-2.6), rhythm 60 s completes with all misses (AC-1.6), timeout restarts only in Normal, out-of-stones restarts at 2.5 only in Normal.
  5. **Input test**: synthesise `InputEventAction` for the five actions and `NOTIFICATION_WM_GO_BACK_REQUEST`; verify pause everywhere, quit only from Title.
- On-device checks (TV remote, Back behaviour) are manual and tracked in the build log.

## 15. Stage type, class, and stage mapping

| Stage type | Class file | Stages that use it |
|---|---|---|
| cutscene | `stages/stage-cutscene.gd` | 1.1, 1.5, 2.1, 2.3, 2.4, 2.7, 3.1, 3.3, 3.4, 3.7, 4.1, 4.2, 4.6, 4.8 |
| protect-flock | `stages/stage-protect-flock.gd` | 1.2 (Nights 1 to 3) |
| boss | `stages/stage-boss.gd` (lion, bear); `stages/stage-goliath.gd` (variant `weak-point`, chosen by `StageHost._scene_key`) | 1.3 Lion, 1.4 Bear, 2.6 Goliath, 3.9 Ziklag (rescue variant) |
| rhythm | `stages/stage-rhythm.gd` | 1.6, 3.2 (with spear dodge), 4.5 (arrow prompts) |
| stealth | `stages/stage-stealth.gd` | 2.5 brook, 3.6 En-gedi, 3.8 Saul's camp |
| survival-camp | `stages/stage-survival-camp.gd` | 3.5 (three days) |
| maze | `stages/stage-maze.gd` | 4.3 |
| patience | `stages/stage-patience.gd` | 4.4 |
| search | `stages/stage-search.gd` | 4.7 |
| delivery | `stages/stage-delivery.gd` | 2.2 |

Note: 2.7 is a cutscene in the script (spec.md lists it separately in chapter 2; the catalogue there omits it, so it is added here). 1.4 and 1.3 are two data files for the same `boss` class; 3.9 is the same class with the `rescue` params block.
