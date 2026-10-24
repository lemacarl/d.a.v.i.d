# Milestone 4 review (Chapter 4, ending, polish, final whole-project pass)

Reviewer: independent (did not write the code). Branch `feature/milestone-4-chapter-4-polish`, HEAD `f8690f3`, diff `2ead3e4..HEAD` (3 commits, 66 files, +4240/-41), plus a whole-project pass because this is the last milestone.

Run in a temp copy of `git archive HEAD` under the scratchpad (not the shared project): `--import` clean; `tests/runner.gd` **6575 passed, 0 failed, 0 skipped** (only the usual shutdown ObjectDB/resource leak warning); `python3 -I tests/check-data-fidelity.py` prints `OK: 116 lines, 34 stages, 14 cutscenes, 4 chapters; all checks passed`. Also checked the built `builds/shepherd-king-0.4.0.apk` (listing and binary manifest) for the export questions. Source and git were only read.

## Summary of what I verified

- Chapter 4 data matches the script in text, speaker, order and beats, with **one omission**: the 4.3 narrator line lost its `(2 Sam 5:7)` reference (R4-1). The fidelity checker cannot see an omitted reference (R4-2).
- God speaks in gold light only in 4.4 (`c4-4-lord`, speaker `lord`). The 4.6 "Thy throne shall be established for ever." (`c4-6-lord`) and the 4.8 Luke 1:32-33 text (`c4-8-caption`) both have speaker `caption`. Nathan says "The LORD says: I will build a house for you." himself. No hint words exist for the Lo-debar villagers (a 3-dot bubble and arrows only; `actor-villager.gd` draws no text).
- No Blessing or mode can change a story outcome, and no stage requires one (details in area 4).
- Offline and child safety hold: no permissions in the shipped manifest, no network classes, no analytics, no gore, Back never quits mid-run.
- No secrets in the tree or in any ref's history. Version `0.4.0` / code `5` is consistent in `export_presets.cfg`, `README.md` and `builds/`.
- The audio export filter is correct: every path in `data/audio.json` exists and ships.

## Findings

Severity: Blocker (cannot ship), Major (must fix before merge), Minor (fix soon, not a gate), Nit.

### 1. Correctness and script fidelity

| ID | Sev | Where | Issue | Suggested fix |
|---|---|---|---|---|
| R4-1 | **Major** | `data/dialogue/ch4.json:44` (`c4-3-narr`) | Script 4.3 (`docs/script-source.md:310`) reads "Narrator: David took the stronghold of Zion. It became the city of David. (2 Sam 5:7)". The data line has **no `reference`**, so the verse is never shown. I scanned every scripted `Speaker: text (Ref)` line in all four chapters; this is the only one whose reference is missing in data. | Add `"reference": "2 Sam 5:7"` to `c4-3-narr`. |
| R4-2 | Minor | `tests/check-data-fidelity.py:48-52` | The checker only proves that references present in data occur in the script. It never proves that a scripted reference is present in data, which is why R4-1 passed with 116 lines "OK". | Add the reverse check: for each `Name: text (Ref)` line in the script that matches a data line, require `reference == Ref`. (My ad hoc version of this check flags only R4-1.) |
| R4-3 | Minor | `data/stages/ch4.json:54,161,162,207-208,215`, `data/stages/ch1.json`, `ch3.json`, `ch2.json` (`missEndsStage`, `attackEnabled`), `data/balance.json:5,10` | Dead keys: nothing in any `.gd` reads `guardsOnWalls`, `hintChain`, `villagerHintIds`, `hitAddsDancers`, `missEndsStage`, `enemies` (search), `goal` (maze, search param), `rockTiles.marked`, `attackEnabled` (2.5), `balance.json` `lossPerHit`, `tapIsMainAction`. `data-schema.md:128-130` documents `grid{w,h}` and `hints` while the data uses `gridCols/gridRows` and `hintChain`; `stage-search.gd` reads `hints` (not in data). `docs/architecture.md:181-183` still lists snake_case params (`tunnel_goal`, `rock_tiles`, `early_press_line`) that do not exist. Same class as R3b-2/R3-11 that were skipped in M3. | Delete the dead keys (or read them), pick one name per param, and bring `architecture.md` and `data-schema.md` rows 128-130 in line with the data. A param-key checker (listed as skipped R3-11) would keep this closed. |
| R4-4 | Minor | `data/audio.json` (no `wind`, no `marching`), `stages/stage-patience.gd:35,106,177` | The script's 4.4 cue is a sound ("the speaker plays wind", "a marching sound"). The stage requests `wind` and `marching`, but neither cue exists in `audio.json`, so `Audio.play_sfx` returns silently and the only cue is visual (trees light up and shake hard, which does work). `contracts.md` records `slow-harp-song` as "no file yet" but says nothing about these two. | Document both as known silent cues. Cheap placeholder that is already licensed: point `marching` at `footstep-grass-000..004` (CC0, remove those five from `exclude_filter`) and play it in the rustle window. `wind` has no matching CC0 file in the pack; leave it silent and note it. |
| R4-5 | Minor | `stages/stage-cutscene.gd` quiet moment, `data/audio.json:120-124` | 4.1's 20-second "slow song on the harp" is 20 seconds of silence (the main theme is deliberately stopped; `audio.gd:82-84`) with a drawn harp glow. Documented, and the stop is a deliberate choice, but the scripted moment has no sound at all. | Playtest this one specifically. Optional: play the existing `harp` bell cue every ~3 s during the moment (data-only: a `sfx` list on the beat) until a recording exists. |

Chapter 4 beat-by-beat table (all verified against `script-source.md:291-343`):

| Script beat | Data | Result |
|---|---|---|
| 4.1 narrator, David x2 (ref 1:19), 20 s quiet moment | `4-1-sad-news` beats, `quiet-moment` 20 s | matches |
| 4.2 narrator x2 (2:4, 5:1-3), Elders | `4-2-hebron` | matches (speaker `elders` is a cast name) |
| 4.3 Guards (5:6), maze, narrator (5:7) | `c4-3-guards` on `enter`, `c4-3-narr` on `win` | text and order match, **reference missing (R4-1)**; `references: ["2 Sam 5:8"]` is script text but not shown anywhere (no `.gd` reads `StageDef.references`, true for earlier chapters too) |
| 4.4 David, gold light, "Not yet!" | `enter`: `c4-4-david` then `gold-light c4-4-lord`; `c4-4-not-yet` speaker `david-men` | matches; the only God-speaker line |
| 4.5 narrator (6:14), arrows | `c4-5-narr` on `enter` | matches |
| 4.6 David, Nathan, gold-light caption (7:16), David (7:18) | beats in that order; `c4-6-lord` speaker `caption`, reference `2 Samuel 7:16` | matches; not attributed to God |
| 4.7 David (9:1), search, Meph., David (9:7), long table | `c4-7-david-ask` on `enter`; `win`: `c4-7-meph`, `c4-7-david-table`, visual `long-table-palace` | matches; no hint words |
| 4.8 narrator x3, Luke caption, final shot, end card | beats in order; `c4-8-caption` speaker `caption`; `c4-8-card-end` speaker `ui` | matches |

### Player-visible strings not in the script (all data, none invented story text)

| String | Where | Judgement |
|---|---|---|
| "Continue" | `recurring-lines.json` `screens.run-summary.continue` | UI chrome, in data. Expected. |
| "Hard" (mode name; pause item reads "Change mode (Lamb / Shepherd / Normal / Hard)") | `recurring-lines.json` `screens.modes.items[3]` | Approved deviation (issue #41, `docs/hard-mode.md`); the pause item is built from data, and the checker allows exactly this deviation. |
| Blessing names, effects, references | `data/blessings.json` | Verbatim from the script table (checker verifies). |
| Chapter-select card "N / title" | `chapter-select.gd:80` with `chapters/chN.json` `title` | Titles are script titles. The number is chrome. |
| HUD numerals (`m:ss`, stone/sheep/men/loaf/food counts) | `ui/hud.gd` | Numbers only, no words. |
| Stage `title`s ("The ending", "Sad news", "Night 4: the Lion", ...) | `data/stages/ch*.json` | Not displayed anywhere (`StageDef.title` has no UI reader), so not player-visible. |
| `CueLabel` in `StageUtil.make_backdrop` | `stages/stage-util.gd:19` | Created empty and hidden by `set_backdrop`; never shows a cue id. |
| `pool:david-falls`, `line:c2-6-go-back` | `onLose.message` | Resolve to recurring and script lines. |

I found no other player-visible string in `.gd` code. No hint text was invented for the villagers.

### 2. Architecture adherence

| ID | Sev | Where | Issue | Suggested fix |
|---|---|---|---|---|
| R4-6 | Minor | `stages/stage-cutscene.gd:30` (`LOCAL_CUE_SCENES`), `:627-640` | A second visual-cue registry now lives in `StageCutscene` next to the shared `StageUtil.CUE_SCENES` (contract owner: `stage-util.gd`). Two places must be consulted to learn what a cue draws. | Add `bethlehem-night-star -> [night-hills, show]` to `StageUtil.CUE_SCENES` and let `_play_scene` instantiate by kind; drop the local map. |
| R4-7 | Nit | `stages/stage-cutscene.gd:42-45`, `screens/stage-host/stage-host.gd:108` | `music_requested` exists only on `StageCutscene`; the host duck-types it with `has_signal`. Documented in `contracts.md`, but it is a shared signal in everything but the declaration. | Declare it on `StageBase` (no-op elsewhere) and connect unconditionally. |
| R4-8 | Nit | `stages/stage-cutscene.gd:134,137-152` | `_build_quiet()` creates 8 nodes in every cutscene stage, including the 11 that have no quiet moment. | Build lazily in `_start_quiet`. |

Verified clean: no `Audio`, `RunState`, `SaveData` or `Settings` call anywhere in `stages/` or `actors/` (git grep). New stages talk to the host only through `StageBase` signals (`request_sfx`, `report_spared`, `win`, `take_hit`, `emit_story_line`). All new files and folders use hyphens (the only underscore in tracked paths outside `android/` and `docs/evidence` is `export_presets.cfg`, exempt). Every new actor is a pure drawing node with no reach into the stage. Game-complete handling (`main.gd:_leave_summary`) keeps Back and Continue both returning to the title and ends the run.

### 3. Blessings, modes, and story outcomes (area 4)

Result: **PASS, no finding.**

- Keys read by the new stages: maze reads `walk-speed` (Quick Feet) and `enemyTelegraphSec` (Watchful Eyes lengthens the tile flash, nothing else) and `report_spared()` (Mercy); patience reads nothing; search reads nothing (it only spawns the optional companion); rhythm arrow mode reads nothing. Mighty Men is cosmetic in Chapter 4.
- No stage requires a Blessing. 4.1, 4.2, 4.6, 4.8 are cutscenes. 4.3 is solvable by construction (`generate` makes a perfect maze, goal is the farthest cell, rocks telegraph 1.2 s then fall 1 s, a tile is crossed in 0.3 s at 280 px/s); a hit costs a heart and `hearts-zero` replays 4.3 only (`restart-stage`), which Shepherd and Lamb veto/disable. 4.4 loops the rustle forever, so it cannot stall. 4.5 ends on `durationSec` (60 s) with `lose: []` and no miss penalty. 4.7 has `lose: []` and the chain is walkable with no help. `tests/test-chapter4-{maze,patience,search,rhythm}.gd` each have an `_outcome_matrix` / `_all_modes_and_blessings` test; the flow test checks the chapter pool and the unlock rules.
- Mercy heals once per guard: `_guard_done[k]` is set the first time progress passes a guard's last marked tile, and `report_spared()` fires only if no rock of that guard hit David (`stage-maze.gd:414-420`). It cannot be farmed.
- Hard changes hearts (2) and invulnerability (1.0 s), not any story event.

| ID | Sev | Where | Issue | Suggested fix |
|---|---|---|---|---|
| R4-9 | Minor | `data/chapters/ch4.json:23-32`, `data/blessings.json` (`smooth-stones`, `song-of-courage`, `goliaths-sword`, `mighty-men`) | Chapter 4 has no stones, thorns or ropes and no enemy that a harp can frighten, so three of the eight offered cards (Smooth Stones, Song of Courage, Goliath's Sword) do nothing in 4.3/4.4/4.5, and Mighty Men's stone-throwing is invisible. The script lists these cards for Chapter 4 (`script-source.md:345-405`), so the pool is spec-correct; but a child can pick a card that has no effect. | Either accept and say so in `build-log.md`, or give each a harmless Chapter 4 meaning (for example Song of Courage: a guard skips one drop; Smooth Stones: no use). Never an outcome change. |

### 4. TV performance (32-bit low-end SoC)

| ID | Sev | Where | Issue | Suggested fix |
|---|---|---|---|---|
| R4-10 | Minor (becomes Major only if the real TV drops below ~30 fps) | `actors/actor-parade.gd:99-228`, `stages/stage-rhythm.gd:244-250` | The 4.5 parade is one full-screen `_draw` redrawn every frame. At the 24 dancer + 8 musician cap it issues about 290 draw commands and allocates about 55 `PackedVector2Array`s per frame (`_person` builds a body polygon per figure, plus bunting, D-pad, ark). Allocation per frame is bounded and small, node count is fixed, and nothing is created per hit, so this is not a leak or growth problem; it is steady CPU cost on a slow core, highest at the end of the stage when it is fullest. | Split the static layer (ground, bunting, ark, priests) into a node that redraws only when `shown` changes by a step; precompute the 4-point body polygon (it only scales) and reuse it. Measure on the EcoTV first. |
| R4-11 | Minor | `actors/actor-ark-night-hills.gd:25-28,66-75`, `stages/stage-cutscene.gd:284` | The 4.8 final shot redraws every frame for as long as it is on screen, and the end card holds it until OK, so a parked child leaves the TV animating at 60 fps indefinitely. `_hill()` rebuilds two constant 27-point arrays every frame. | Precompute the hill arrays in `_init`; redraw at about 10 fps (stars and breath are slow) or only when a twinkle value changes. |
| R4-12 | Minor | build-log open item #9, `docs/build-log.md:37,50,61` | There is still **no measurement on the real TV** (EcoTV1 Plus, 32-bit, Android 14): fps, hitches, input mapping, loudness. The M3 and M4 test reports used a software emulator, which says nothing about speed. The project renders natively at 1080p (`canvas_items` stretch on a 1920x1080 base). | Before calling the game done, run `adb shell dumpsys gfxinfo com.lemacarl.shepherdking` during 3.2, 3.9 (many men), 4.3 and the end of 4.5. If frames are slow, the single biggest lever is a 1280x720 base viewport with `viewport` stretch (2.25x less fill rate); the second is R4-10. |
| R4-13 | Nit | `project.godot:34,38,43-46` | The new settings (`vsync_mode=1`, `physics_ticks_per_second=60`, `msaa_2d/3d=0`, `screen_space_aa=0`, `scaling_3d/mode=0`) are all Godot defaults and `3d/physics_engine="Jolt"` is unused in a 2D game. Harmless; they only document intent. | Keep or drop; note they are no-ops. |

Verified clean in the new stages: `_process` is switched off when a stage finishes (`stage-play-base.gd:84-87`, `stage-rhythm.gd:201-203`), and `ActorStone` now sets `set_process` only while in flight. Nodes are bounded: maze tiles are one `_draw` (no node per tile), marked tiles <= 16, hint arrows <= 24, guards <= 6 with one rock each; patience has 7 trees, 4 men, 5 foes; search <= 6 villagers and 8 chairs; rhythm 16 pooled notes; the parade caps at `FIGURE_HARD_CAP` 48 and the data uses 24 + 8. The new stages create no tweens and no per-frame signal connections (`stage-host` connects once per stage and frees with it). `Hud._pulse` now kills the previous tween (R3b-1 resolved). `ActorVillager`, `ActorTree`, `ActorGuard`, `ActorVillagerHouse` redraw only on change.

#### The 151 MB APK and arm64

`builds/shepherd-king-0.4.0.apk` is 151.8 MB, and **146 MB of it is the two engine libraries** (`libgodot_android.so` 74.9 MB armeabi-v7a and 71.1 MB arm64-v8a, plus about 2.3 MB of `libc++_shared.so`), stored uncompressed (`compress_native_libraries=false`). Game content is about 3 MB (26 audio streams, 0.77 MB music, scripts, data). Dropping arm64 removes about 73 MB and gives an APK of roughly 78 MB; the install size drops the same amount because the libraries are mapped from the APK.

| ID | Sev | Where | Issue | Suggested fix |
|---|---|---|---|---|
| R4-14 | Minor (recommendation) | `export_presets.cfg:32-33`, `docs/build-log.md:61` | The only target device is 32-bit only, so `arm64-v8a` can never run on it; it doubles the download for no gain. The earlier note "both ABIs must stay" is really "armeabi-v7a must stay". | **Recommended:** make the TV release armeabi-v7a only (arm64 off). If someone later sideloads to a 64-bit-only box, add a second preset ("Google TV arm64") and ship two APKs with different version codes rather than one fat APK. Document this in README (which currently says arm64 "too"). Do not change `compress_native_libraries` (it would trade APK size for a bigger on-disk install). A custom engine template with unused modules stripped (3D, physics, navigation) could later cut each library by half; not needed for this release. |

### 5. Data maintainability

| ID | Sev | Where | Issue | Suggested fix |
|---|---|---|---|---|
| R4-15 | Minor | `stages/stage-maze.gd:32-39` (`DEFAULT_TELEGRAPH_SEC` 1.2, `DEFAULT_FALL_PX` 260, `LAND_SEC`, `GOAL_REACH`), `stage-patience.gd:26-31` (`CHARGE_SEC`, `CHARGE_SPEED`, `FLEE_SPEED`, `WIND_PERIOD_SEC`), `stage-search.gd:16-21` (`TALK_REACH`, `POINT_SEC`, `GUIDE_IDLE_SEC`) | Several tuning numbers that decide fairness for a 4-year-old live only in code: the rock telegraph (1.2 s) and fall height are not in `ch4.json` (the stage reads `rockTelegraphSec` and `rockFallPx` but the data never sets them), so a designer changing difficulty edits GDScript. This was fixed for the camp in M3 and not applied here. | Put `rockTelegraphSec`, `rockFallPx`, `talkReachPx`, `pointSec` and the charge timing into the stage `params` (and Shepherd overrides where wanted); keep the `DEFAULT_*` only as fallbacks. |

Positive: the numbers that matter most (`rustleDelaySecRange`, `rustleWindowSec`, `rockSpeed`, `rockDropIntervalSec`, `rockHitHearts`, `notesPerMinute`, `noteSpeed`, `hitWindowSec`, `maxDancers`) are in data with per-mode overrides, and `spearLaneHalfWidthPx` (R3b-2) was removed.

### 6. Licensing and export

Verified: `data/audio.json` references 26 files (25 Kenney effects plus `sheep-baa.ogg`) and one mp3; all exist; none is in the `exclude_filter`. 131 `.ogg` files exist under `audio/effects/`; `exclude_filter` lists 105 of them and 105 + 26 = 131 (no unreferenced file ships, no referenced file is excluded). The APK holds exactly 26 `oggvorbisstr` streams plus the mp3. `CREDITS.md` matches the audio files (cynicmusic A New Town CC0, Kenney Impact Sounds CC0, sheep baa CC0). The Kenney licence text sits in `audio/effects/license-kenney-impact-sounds.txt` (CC0 needs no notice, so it not shipping in the APK is fine). `icon.svg`, `icons/*.png`, the TV banner and the splash are original flat shapes (a crook and a star; I viewed `banner.png` and `splash_icon.webp`); the APK's `assets/icon.svg` is the project's 626-byte icon, not the Godot logo. `docs/concept/*` are original and excluded from the APK (`docs/*`).

| ID | Sev | Where | Issue | Suggested fix |
|---|---|---|---|---|
| R4-16 | Minor | `CREDITS.md:7` (also `docs/milestone-plan.md:51`) | "Painterly 2D art is planned for Milestone 4." M4 is this milestone and it did not happen: all art is still code-drawn placeholder. Same for the other M4 polish items (audio direction, narration, texture sizing, release signing, banner polish). Nothing records the deferral. | Reword to "planned after Milestone 4" and add a build-log entry listing what M4 polish did (audio trim, perf audit, README, version) and what is deferred (painterly art, narration recording, real-TV measurement, release signing). |
| R4-17 | Minor | `export_presets.cfg:11` | The 105 unused files are excluded by one 6 KB hand-written line of exact file names. Nothing tests it: adding a cue to `audio.json` whose file is in that list silently plays nothing (`Audio` returns null with no error). | Add a test: every path in `audio.json` exists and does not match `exclude_filter`. Alternative: move the unused Kenney files to a `.gdignore`d folder (for example `third-party/`) so the filter is a one-line glob. |
| R4-18 | Nit | `android/build/src/instrumented/assets/icon.svg` | The Godot default icon (the Godot logo, CC BY 4.0) is tracked inside the Gradle template. It is an instrumented-test asset and is not in the APK, so this is not shipped. | Delete `android/build/src/instrumented/` (not used by the export) or list it in `CREDITS.md`. |

### 7. Child safety, offline

Result: **PASS.** `git grep` over `*.gd`, `*.tscn`, `project.godot`, `export_presets.cfg` (excluding the Godot template) finds no `HTTPRequest`, `HTTPClient`, `http://`, `https://`, `WebSocket`, `StreamPeer`, `PacketPeer`, `ENet`, `JavaScriptBridge`, `OS.shell_open`, `OS.execute`, analytics or ad code; the only `get_tree().quit()` calls are the title Back (`main.gd:66`) and the OS close request (`main.gd:48`). In-run Back opens or closes the pause menu; the summary and game-complete card route to the chapter select or the title. `export_presets.cfg` has `permissions/custom_permissions` empty and no `permissions/internet`; the APK's binary manifest has no `uses-permission`, only the library's own `android.permission.DUMP` receiver protection (not a requested permission); `allowBackup=false`. Save data is `user://save.json` only. No gore: rocks cost a heart, Philistines run away, the 4.3 maze defeat is a fade and restart.

### 8. Leftover code

Result: **clean.** No `print`, `push_warning`, TODO, FIXME, XXX or commented-out code in `.gd` outside the Godot Gradle template (`android/build/src/instrumented/...` prints are the engine's own test files). The two `push_error` calls in `stage-host.gd:81,86` are legitimate load failures.

| ID | Sev | Where | Issue | Suggested fix |
|---|---|---|---|---|
| R4-19 | Nit | `stages/stage-maze.gd:483-498`, `stage-cutscene.gd:463`, `stage-rhythm.gd:305,354,537,546`, `stage-search.gd:121`, `stage-stealth.gd:483` | Test-only accessors are public (`guard_state`, `guard_tile`, `guard_tile_count`, `quiet_active`, `arrows_enabled`, `arrow_in_window`, `active_notes`, `note_in_window`, `current_target`, `prompt_visible`, ...). Same as R3b-4. | Keep them one-liners and mark each "(tests)" in its doc comment (several already are). |

### 9. Release hygiene

| ID | Sev | Where | Issue | Suggested fix |
|---|---|---|---|---|
| R4-20 | Minor | `README.md:5` | States "three modes: Normal, Shepherd and Lamb". The game ships four (Hard was added in 0.2.1, `docs/hard-mode.md`). | "Four modes: Normal, Shepherd, Lamb and Hard (Normal with more pressure)". |
| R4-21 | Minor | `README.md:63`, `docs/playtest-template.md:7,15` | The `stages/` row lists "play, boss, stealth, rhythm, maze, camp, cutscene" and leaves out patience, search, delivery, protect-flock. The template asks for "Build version (Settings or APK name)" but no screen shows a version, and its mode line omits Hard. | List all stage types; say "APK file name" only; add Hard to the mode choices. |
| R4-22 | Minor | `docs/build-log.md` (last entry is the M3 fix round) | No M4 entry, no `docs/test-report-m4.md`, and the M3 deferred list (R3-6, R3-8, R3-17, R3-19, R3-21, R3-22, D-8..D-10, R3-11) is not carried forward. "Trim unused audio in M4" (line 49) is done but not marked done. | Add an M4 entry: what shipped, 6575 tests, deferred items, APK size and ABI decision, the owed real-TV test. A tester pass on the 0.4.0 APK is still owed. |
| R4-23 | Nit | `docs/evidence/m1-final/*`, `m1-retest/*` (10 files such as `a_down.png`, `t_after_quit.png`) | Underscore names, against `architecture.md:22` (applies to files "we create"). | Rename to hyphens, or accept as tester output. |
| R4-24 | Nit | local branch `feature/baseline-hello-tv` | It holds two Godot library blobs (`godot-lib.template_*.aar`, 112 MB and 103 MB) that GitHub would reject (100 MB limit). They are on no remote branch (`origin/main` and the `-clean` branch have none) and `.gitignore` excludes `android/build/libs/`. `.git` is 223 MB because of them. | Never push that branch; delete it locally and `git gc` once the stack is merged. Add `*.apk`, `*.aab`, `*.aar` to `.gitignore` as a belt-and-braces. |

Verified: `.gitignore` covers `.godot/`, `/builds/`, `*.keystore`, `*.jks`, `*.p12`, `*.pem`, `.env`, `*password*`. No keystore, password, token or key file appears in any ref's history (`git log --all --diff-filter=A --name-only` and `-S` checks; the only hits are the Gradle template's property names and the README's placeholder `<password>`). Signing is by environment variables as documented. Version `0.4.0`, code `5`.

### PR stack and merge order

Open PRs (all by the same author): **#28** M1 (base `main`), **#29** M2 (base `feature/milestone-1-core-chapter-1`), **#42** playtest round 1 fixes (base `feature/milestone-2-chapter-2`), **#43** M3 (base `feature/playtest-1-fixes`, not M2). **There is no PR yet for this M4 branch**; it is cut from the M3 head, which already contains the playtest fixes through merge `2ead3e4`.

What a reader needs to merge them:
1. Use **merge commits** (not squash or rebase) at every step. Each branch contains its parent's commits, so a squash would make the next PR conflict.
2. Merge strictly bottom-up: **#28 -> #29 -> #42 -> #43 -> M4**. After each merge, retarget the next PR's base to `main` (or let GitHub do it by deleting the merged head branch) before merging it, so each PR shows only its own diff.
3. #43's base is `feature/playtest-1-fixes`, so its diff will show M3 only after #42 is merged; if #43 is merged first it lands on the playtest branch, not `main`.
4. Open the M4 PR last, against `main`, after #43. Its diff against M3 is what this review covers.
5. Do not merge the stack before the owed items below are decided (the 0.4.0 APK reflects this branch, not `main`).

## Verdict: CHANGES REQUESTED

The code is in good shape: 6575 tests pass, the fidelity check is green, outcomes are independent of Blessings and modes, no stage needs a Blessing, the app is offline and permission-free, no secrets, the audio export filter is exact, and no new per-frame growth or leaks were found. The only item I consider a gate is a script-fidelity miss that is a one-line fix. Everything else is Minor or Nit and can follow in the polish commit or after.

### Must-fix before merge (exact list)

1. **R4-1**: add `"reference": "2 Sam 5:7"` to `c4-3-narr` in `data/dialogue/ch4.json:44`, then re-run `python3 -I tests/check-data-fidelity.py` and the headless suite.

### Should-do in the same commit (cheap, not gates)

- R4-2 (checker: require the scripted reference), R4-20 and R4-21 (README and template accuracy: four modes, stage list, no in-game version), R4-16 and R4-22 (CREDITS wording and an M4 build-log entry with the deferrals), R4-14 (decide armeabi-v7a-only for the TV release and note it in README).

### Release decisions I recommend (owner: Andrew)

- Measure fps on the real TV (R4-12) before the final release APK; apply R4-10 and R4-11 only if the numbers need them.
- Ship the TV build as armeabi-v7a only (about 78 MB).
- Run a tester pass on the 0.4.0 APK (none exists for M4) and a family playtest with `docs/playtest-template.md`, specifically on 4.1 silence, 4.4 with no sound (R4-4, R4-5), and the three inert Blessing cards (R4-9).

Counts: Blocker 0, Major 1, Minor 16, Nit 7 (24 findings, R4-1..R4-24).
