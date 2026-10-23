# Milestone 1 independent review: Shepherd King, Chapter 1

Reviewer: independent (did not write or test the code). Branch `feature/milestone-1-core-chapter-1`, HEAD `f878653`, diff against `main` (884 files; 271 of them are committed Android build output, 50 are evidence PNGs, about 130 are audio).
Method: read every GDScript, scene and data file, `export_presets.cfg`, the Android manifests, `.gitignore`, `CREDITS.md`, and compared with `docs/spec.md`, `docs/architecture.md`, `docs/data-schema.md`, `docs/contracts.md`, `docs/script-source.md`. Re-ran the checks on a clean `git archive` copy (nothing in the working tree was changed): `python3 -I tests/check-data-fidelity.py` gives "OK: 36 lines, 8 stages, 2 cutscenes"; `Godot --headless -s res://tests/runner.gd` gives 410 passed, 0 failed. `git status` was clean.
Not verified: on-device behaviour, real TV frame rate, licences of third-party files against their web pages (no network used).

## Verdict

**CHANGES REQUESTED.** No Blocker. The story data is faithful and the architecture is mostly followed, but there are six Major findings to fix before merge (list at the end).

Counts: Blocker 0, Major 6, Minor 25, Nit 18.

---

## 1. Correctness vs spec, architecture, data schema, contracts

| ID | Sev | File:line | Issue | Suggested fix |
|---|---|---|---|---|
| C-1 | Major | `data/blessings.json:8,14,17`; `screens/stage-host/stage-host.gd:120-122`; `stages/stage-base.gd:45`; `stages/stage-play-base.gd:103,127` | Three of the seven Chapter 1 Blessings do nothing, yet they are offered to children as real choices. Shepherd's Staff (`followRadiusMult` -> key `follow-distance`) is never read by any stage (grep: the key appears only in `modifier-stack.gd` and `blessing-modifier.gd`). Song of Courage (hold OK 2 s frightens enemies): the host calls `on_action_hold()` but no stage overrides it, and `get_feature(&"harpFrightenEnabled")` is never called. Watchful Eyes (`enemyTelegraphSec`) is never read. The test suite only checks the stack, not that a stage honours the key, so 410 green tests do not cover this. | Implement the three effects in `StageProtectFlock`/`StageBoss`/`StagePlayBase` (sheep home radius from `follow-distance`; hold OK frightens live predators within `harpFrightenRadiusPx` for `harpFrightenSec`; spawn glow for `enemyTelegraphSec` before `activate`) and add one test per Blessing, or, if Andrew agrees, remove them from `ch1.json` `blessingPool` until built. Do not ship cards with no effect. |
| C-2 | Minor | `autoload/run-state.gd:222-224` | In Normal, if a stage has no `hearts-zero` lose entry, hearts floor at 1 (David cannot fall). Fine for Chapter 1 (every playable stage has the entry) but it is an undocumented behaviour in the contract (`contracts.md` says "Normal: zero hearts fails the stage"). | Document in `contracts.md`, or fail regardless and let `onLose` decide. |
| C-3 | Minor | `data/stages/ch1.json` (nights 1-3 `lose`), `docs/spec.md` Chapter 1 table | Nights also lose on `hearts-zero`; the spec lists only "<3 sheep alive". Mentioned as D12 in the test report. Harmless (same restart) but it is an addition to the written rules. | Add one line to `spec.md` stating nights also end the run at zero hearts in Normal. |
| C-4 | Minor | `data/stages/ch1.json` (`eventLimits.sheep-saved`: cooldown 8 s, max 3 per stage); `stages/stage-protect-flock.gd:255-262` | After the third rescue in a stage, or within 8 s of the last, David's scripted line "Got you! Back to the flock." is silently not shown. That is a scripted beat suppressed by an invented number. The numbers are not marked [A] in `spec.md`. | Mark as [A] in `spec.md` and get Andrew's approval, or drop the limit and rely on the line queue. |
| C-5 | Minor | `stages/stage-cutscene.gd:161-170`; `stages/stage-play-base.gd:115-130` | In Lamb mode the tutorial prompt "Press OK to throw a stone." is shown and OK throws a stone (cutscene `on_action_tap` calls `super()`), while in every other Lamb stage OK plays the harp. Inconsistent for the 2-year-old. | In the cutscene tutorial, honour `lamb_harp_mode()` (harp ring) or skip the throw tutorial beat in Lamb through a `modes.lamb.events` override. |
| C-6 | Nit | `docs/data-schema.md` section 3 vs `docs/architecture.md` section 3 | Architecture says data is one file per stage/Blessing/line pool; data-schema (and the code) use one file per chapter plus `blessings.json` and `recurring-lines.json`. The code follows data-schema, which says "architecture owns final locations". | Update `architecture.md` section 3 to the real layout. |
| C-7 | Nit | `data/dialogue/ch1.json` `c1-5-lord-heart` | Speaker is `caption`; schema section 1 says gold-light lines use speaker `lord`. `caption` is the more accurate choice (script says "Caption:"), so keep the data, fix the doc. | Update `data-schema.md`. |

## 2. Script fidelity

Result: no added, cut, reordered or reworded story text found. Dialogue, narrator lines, captions, references, the three falls lines, encouragement lines, stage-cleared lines, pause items, title text, summary template and the chapter-complete card all match `docs/script-source.md` (checker passes and I compared by hand). Stage order, win/lose rules, 90 s nights, 3+3 lion hits, 60 s harp and Lamb/Shepherd rules match the spec. Scripture appears only where the script has it. Gold light is used once (`c1-5-lord-heart`, "The LORD looketh on the heart.", 1 Samuel 16:7) and nothing is attributed to God beyond that. Blessing names, effects and references in `data/blessings.json` match the script table.

| ID | Sev | File:line | Issue | Suggested fix |
|---|---|---|---|---|
| F-1 | Minor | `data/stages/ch1.json` stage `1-6-harp` `events.win`; `stages/stage-rhythm.gd:105-107,172-175` | The end card "Chapter 1 complete - The Shepherd. Next: The Hero." is requested as a subtitle line at harp end and again by the run summary screen. Not a fidelity break (same text, script order kept), but the card text is shown twice. | Keep the run-summary copy and drop the `end-card` beat from the stage, or the reverse. |
| F-2 | Minor | `data/stages/ch1.json` `1-3-lion` / `1-4-bear` Lamb overrides | In Lamb the lion and bear are absent but their closing narrator lines ("David chased the lion...", "The lion and the bear could not beat...") and "Hey! That lamb belongs to my father!" still play. This is consistent with AC-ALL-3 (story lines identical in all modes) and the test report accepted it, but it is a content decision the script does not state. | Record the decision in `spec.md` Q1 so it is not reopened later. |
| F-3 | Nit | `ui/ui-text.gd:7`, see also T-1 | "Continue" is not in the script. | See area 8/T-1. |
| F-4 | Nit | `screens/title/title.gd:17-30` | The script's single title string "Shepherd King - Press OK to begin." is split into a heading and a button; the em dash is not shown. Reasonable layout, text still comes from data. | None required. |

## 3. Architecture adherence

Autoloads: exactly `RunState`, `SaveData`, `Settings`, `Audio` (`project.godot`); none holds story text; only `SaveData` does disk I/O; `Audio` has no game rules. Signals flow upward as in architecture section 9; stages never call `RunState` or change screens (verified in all stage scripts). File and folder names are hyphenated with no underscores (only Godot/Android template names such as `android/.build_version`, `icon_foreground.webp`, `export_presets.cfg`). Scenes are tiny and each stage type is one reusable class. `StageBase` matches `contracts.md`.

| ID | Sev | File:line | Issue | Suggested fix |
|---|---|---|---|---|
| A-1 | Minor | `stages/stage-play-base.gd:143` | A stage calls the `Audio` autoload directly (`Audio.play_harp()`), against "stages never reach autoloads; signals over hard references" (architecture 9: audio goes via `line_requested` / host). | Emit a signal (for example `sfx_requested(cue)`) and let `StageHost` call `Audio`. |
| A-2 | Minor | `screens/stage-host/stage-host.gd:156-161` | Architecture section 9 says `line_requested` reaches `Audio.narrate()`. The host never calls `Audio.narrate`, so recorded narration (`audio/narration/<line-id>.ogg`, see `docs/narration-sheet-ch1.md`) would never play even once the files are added. | Call `Audio.narrate(line_id)` from the host when a line starts (needs the line id passed through `LineQueue`), or note it as an M4 item. |
| A-3 | Minor | `screens/chapter-select/chapter-select.gd:37-38`; `ui/ui-text.gd:35-43`; `screens/pause-menu/pause-menu.gd:9,54-59` | The mode row, mode keys and mode names are derived by parsing the pause-menu string "Change mode (Lamb / Shepherd / Normal)" and lower-casing it into the save key. Reordering or rewording that script string would silently break mode selection. | Add an explicit `modes` list (id + label) to `recurring-lines.json` `screens` and read it; keep the pause item text as-is. |
| A-4 | Nit | `model/run-model.gd:66-112`; `model/stage-def.gd:63-70` | `RunModel.to_dict/from_dict` and `StageDef.load_chapter` are unused outside tests. Architecture says no run progress is saved. | Delete or mark test-only. |
| A-5 | Nit | `docs/architecture.md` section 3 | `screens/cutscene-player/` and `modifiers/blessing/` one-script-per-Blessing do not exist; the implementation (cutscene as a stage type, one data-driven `BlessingModifier`) is better. | Update the doc. |

## 4. Scope creep (not Milestone 1 / not in the script)

| ID | Sev | File:line | Issue | Suggested fix |
|---|---|---|---|---|
| S-1 | Minor | `data/blessings.json:25-47`; `modifiers/blessing/blessing-modifier.gd` REGISTRY; `autoload/run-state.gd:133,308-312`; `model/run-model.gd:7-10,52` | Chapter 2-4 content is already in M1: six Blessings for Chapters 2-4 (Hidden in the Rock, Faithful Friend, Goliath's Sword, Mighty Men, Gift of Abigail, Mercy), `availableAfterStage` logic, the Goliath's Sword unlock hard-wired by id in `RunState`, and `SWORD_CARRIES_INTO_CHAPTER = 4` in `RunModel`. The milestone plan says M1 delivers "7 Chapter-1 Blessings". Untested in play and the story-specific id is in code. | Move the six later cards to M3/M4, or keep the data but drive the sword rule from the card's `unlock` block only and remove the constant. |
| S-2 | Nit | `stages/stage-cutscene.gd:136-137`, `ui/hud.gd` stones/followers counters, `stage-base.gd` `follower_added` | Quiet-moment beat type and stone/follower HUD are Chapter 2-4 features. They are in `contracts.md`, so acceptable, and the HUD hides the counters at 0. | None. |
| S-3 | Nit | `docs/concept/*`, `docs/evidence/m1/*` | Art-direction concept and 50 evidence PNGs are part of this branch (commit `8838526`). Fine as docs; see licensing L-5 and hygiene H-4. | None. |

## 5. TV performance

No per-frame allocation of heap objects found in hot paths: stones, predators, notes and sheep are pooled (`stage-play-base.gd:56-60`, `stage-protect-flock.gd:61-66`, `stage-rhythm.gd:66-77`); predator cap is `DEFAULT_MAX_PREDATORS` 6; `_process` loops are O(small N) (about 60 distance checks per frame). No textures at all (all `_draw` shapes), so no oversized textures. Signal connections are to nodes that are freed with their screen (Godot drops them). The tester measured 77 nodes steady across three nights.

| ID | Sev | File:line | Issue | Suggested fix |
|---|---|---|---|---|
| P-1 | Minor | `stages/stage-play-base.gd:63-66,88-90`; `stages/stage-boss.gd:138-145` | After a stage finishes, `_process` keeps running every frame until the host frees the stage; the boss `_idle` keeps moving the fled boss forever (no despawn). Harmless because the host frees the stage on `advance`, but the work does not stop by itself. | `set_process(false)` in `win()`/`fail()` after the cosmetic flee finishes, or free the boss when it leaves the field. |
| P-2 | Minor | `stages/stage-play-base.gd:139-159` | Each Lamb OK tap creates a `Polygon2D` with a 24-point polygon and a tween. Bounded by the 0.35 s throw cooldown and 0.6 s life (about 2 alive), so not a leak, but it is allocation per tap on a low-end TV. | Pool one or two ring nodes and reuse them. |
| P-3 | Nit | `ui/icon-shape.gd:29-32` | Title sheep calls `queue_redraw()` every frame (only on the title). Fine. | None. |
| P-4 | Nit | `stages/stage-play-base.gd:77` | `david.set_flash(false)` runs every frame when not flashing (cheap, `modulate` unchanged). | Call only on the transition. |
| P-5 | Nit | `export_presets.cfg:11` | Both `armeabi-v7a` and `arm64-v8a` are exported; Google TV devices are mostly arm64. Larger APK only. | Decide at M4. |

## 6. Maintainability of data files

Schema is consistent: every file has `schemaVersion: 1`, ids are kebab-case, camelCase keys, `next` chain matches the chapter `stages` list (checker enforces), line ids unique. The mode multipliers, hearts, invulnerability, Shepherd rest and harp hold are in `data/balance.json` and used from there.

| ID | Sev | File:line | Issue | Suggested fix |
|---|---|---|---|---|
| D-1 | Major | `stages/stage-play-base.gd:8-13`; `stage-protect-flock.gd:7-15`; `stage-boss.gd:11-14,31-50,63-78`; `stage-rhythm.gd:6-14,45-46`; `stage-cutscene.gd:10-14`; `data/stages/ch1.json` | Balance and feel numbers are in code as defaults and the data files never override them: walk speed 320, stone speed 900, throw cooldown 0.35, stone hit radius 40, rescue radius 80, catch radius 40, sheep drift range 520 and flee mult 1.3, lion circle radius 300 / speed 280, bear windup 0.9 / rest 1.2 / charge speed 900 / slip 2.0 / rock every 2 / lanes 4, boss flee speed 700, rhythm note speed 420 and hit window 0.25 s, default line time 4.0 s. `grep` for `circleSpeed`, `chargeSpeed`, `walkSpeed`, `stoneSpeed`, `windupSec`, `hitWindowSec`, `noteSpeed` in `data/` returns nothing. Architecture decision: "Balance numbers live in data files, never in code." The test report's R11 ("lion 168 vs 280, bear 540 vs 900 matches balance.json") is only true for the multiplier; the 280 and 900 are code defaults. | Move these into `params` of the relevant stage entries in `data/stages/ch1.json` (or a `defaults` block in `balance.json`) and keep code defaults only as a safety net with the same value read from `balance.json`. Add them to `data-schema.md` section 3.2. |
| D-2 | Minor | `data/stages/ch1.json` nights: `params.durationSec`, `win.seconds`, `params.sheepMinAlive`, `win.minAlive`, `lose[0].min` | The same numbers (90, 3) are written 2-3 times per stage; code reads `durationSec` and `win.minAlive`/`lose.min`, so `win.seconds` and `sheepMinAlive` are dead duplicates that can drift. | Pick one source per number and delete the others, or add a data test asserting equality. |
| D-3 | Minor | `data/stages/ch1.json` events `hit-3`, `hit-6`; `params.hitsToDrop/hitsToFlee`, `win.count` (lion and bear) | Trigger names encode the hit numbers, and `hitsToFlee` (3 lion, 6 bear) is not used by code (`stage-boss.gd:63` uses `win.count`). Changing a number needs three edits. | Name triggers `drop` and `flee`, or add a test that ties them together. |
| D-4 | Minor | `ui/gold-light-overlay.gd:5` vs `data/cutscenes/ch1.json` gold-light `seconds: 4` | The overlay hold is a constant 4.0 s; the cutscene waits for the data `seconds`. Two sources of the same duration. | Pass `seconds` through `gold_light_requested` or read it in the overlay. |
| D-5 | Nit | `data/cutscenes/ch1.json` `skippable: true`; `stages/stage-cutscene.gd:49` | `skippable` is never read and `skip_to_end()` is never called (dead code). Schema says skippable only after first viewing. | Remove the method or implement skip; do not offer skipping the Scripture caption before first viewing. |

## 7. Licensing of every non-code asset

Non-code assets in the repo (excluding generated Godot `.import` files):

| Asset | Where | Licence claimed | Reviewer note |
|---|---|---|---|
| `icon.svg`, Android launcher icons, banner, splash (`android/build/res/**`, 15 files) | repo root, `android/build/res` | none stated; `CREDITS.md` says "Art: original work" | `icon.svg` is the stock Godot head icon (same path data as the engine default), and the Android launcher/banner/splash files were generated from it. The Godot logo/icon is CC BY 4.0 (attribution required). |
| `audio/music/a-new-town.mp3` | 766 KB | CC0, cynicmusic, OpenGameArt | Provenance plausible; I could not verify the OGA page offline. Unused (see L-2). |
| `audio/effects/*.ogg` (130 files) + `license-kenney-impact-sounds.txt` | Kenney Impact Sounds 1.0 | CC0 | The licence file is present and says CC0. All 130 are unused. |
| `audio/effects/sheep-baa.ogg` | | CC0 (mikewest via AntumDeluge) | Unused; path and format not matched by `Audio` (L-2). |
| `docs/concept/storybook-night-1*.png/svg` | docs | original (generated) | docs only, not exported. |
| `docs/evidence/m1/*.png` (50) | docs | screenshots of the game | docs only. |
| `android/build/gradle/wrapper/gradle-wrapper.jar` | 59 KB | Apache-2.0 (Gradle) | Standard for the Godot Android template; fine. |
| Fonts | none bundled | engine default font (Open Sans, OFL/Apache via Godot) | `architecture.md` section 11 says "fonts: bundled, one family"; none are, so the engine default is used. Acceptable, but say so. |
| Narration | none | "to be added" | n/a |

| ID | Sev | File:line | Issue | Suggested fix |
|---|---|---|---|---|
| L-1 | Major | `CREDITS.md:3,21`; `icon.svg`; `android/build/res/**` | `CREDITS.md` states "All assets are original work or CC0 / permissive. Nothing here requires attribution" and "Art: original work". The app icon, launcher icons, TV banner and splash are the Godot default icon (CC BY 4.0), so attribution is required if they ship. | Either replace `icon.svg` and the generated launcher/banner/splash with original art, or add a credit line ("Godot Engine icon, CC BY 4.0, Andrea Calabro") and correct the two sentences. Also add the Godot Engine MIT notice (Godot's export bundles licences in-engine; a line in CREDITS is conventional). |
| L-2 | Major | `autoload/audio.gd:8-10,104-108`; `CREDITS.md`; `audio/**`; grep for `Audio.` callers | The 132 audio files (about 2.5 MB) are never played. `Audio` only loads `.ogg` from `res://audio/music/`, `res://audio/sfx/` and `res://audio/narration/`; the music is an `.mp3` in `audio/music/`, the effects are in `audio/effects/` (no `audio/sfx/`), and the only call site is `Audio.play_harp()` for a cue `harp` that has no file. `Audio.play_music`, `play_sfx`, `narrate` are never called. The commits "CC0 music" and "CC0 sheep bleat" therefore ship unused files and a licence surface with no benefit, and the test report (R48) says "no `res://audio/` folder". | Either wire audio (music on title/stages, sfx for stone hit, sheep baa on rescue, directory and extension matching) and re-test, or remove all unused audio and its CREDITS rows from this branch and add them when used. Keep only licence-verified files. |
| L-3 | Minor | `CREDITS.md:14-16` | The sheep-baa row is separated from its table by a blank line, so it renders as plain text; the Kenney row says "130 files; file names renamed from underscores to hyphens" but the licence text file is the only record. | Fix the table; keep the Kenney licence file next to the assets. |
| L-4 | Minor | `export_presets.cfg:11` | `exclude_filter="docs/*, builds/*"` does not exclude `tests/*` or `CREDITS.md`, so the headless test scripts and (currently) all unused audio are packed into the APK (`android/build/src/main/assets/tests/*.gdc` proves it). | Add `tests/*` (and `*.md`) to `exclude_filter`. |
| L-5 | Nit | `docs/concept`, `docs/evidence` | Original/generated; no third-party content seen. | None. |

## 8. Leftover debug code, test hooks, TODOs

Clean: no `print`, `push_warning`, `TODO`, `FIXME`, `breakpoint` or commented-out code in production GDScript (`print` appears only in `tests/runner.gd`). The only `push_error` calls (`stage-host.gd:74,79`) are legitimate missing-scene errors.

| ID | Sev | File:line | Issue | Suggested fix |
|---|---|---|---|---|
| T-1 | Minor | `ui/ui-text.gd:6-7`; `screens/run-summary/run-summary.gd:23` | `CONTINUE_LABEL = "Continue"` is hard-coded. It is not in the script, so it is not a script-fidelity breach, and `architecture.md` section 4 names the button "Continue". But it is the one player-visible string that is in code while all the others are in `data/recurring-lines.json`, and the code comment ("no data file names") admits the gap. | Add `"continueLabel": "Continue"` to `recurring-lines.json` `screens.run-summary` and read it through `UiText`; mark it in `data-schema.md` as a non-script UI string needing approval. Low effort; keeps the rule "no player text in code" true. (Also `"%d\n%s"` card format and the `"\n"` + mode name join are layout only.) |
| T-2 | Minor | `stages/stage-play-base.gd:65-69`; `stages/stage-rhythm.gd:84-90` | `tick(delta)` is public and exists so tests can drive stages without a tree. It is also what `_process` calls, so it is a legitimate seam rather than dead test code. | Rename `_tick`/keep, but document it as the simulation entry point (already documented). No change needed beyond that. |
| T-3 | Minor | `stages/stage-protect-flock.gd:89-98` `remove_sheep`; `stages/stage-rhythm.gd:148-161` `active_notes`, `note_in_window`; `stages/stage-boss.gd:287-288` `register_hits` ("Public so tests can drive it"); `autoload/run-state.gd:38-47` `set_chapter_data`, `set_seed` | Test-only methods are public in production classes, and `remove_sheep` can delete sheep from outside the stage. | Prefix with `_` and have tests call them (GDScript allows it), or move to a `tests/` helper subclass. |
| T-4 | Nit | `stages/stage-cutscene.gd:48-53` | `skip_to_end()` unused (see D-5). | Remove. |

## 9. Child safety and offline

Verified: no `INTERNET` or any `uses-permission` in `android/build/src/main/AndroidManifest.xml` or `src/debug/AndroidManifest.xml`; `permissions/custom_permissions` empty; `user_data_backup/allow=false`, `allowBackup="false"`. Grep over all GDScript, scenes, resources, JSON and `project.godot` finds no `HTTPRequest`, `HTTPClient`, `http://`, `https://`, `shell_open`, `OS.execute`, WebSocket or ENet. No ads, analytics, external links or user text input. Save data is `user://save.json` only. No gore (flat shapes; defeat is a fade).

| ID | Sev | File:line | Issue | Suggested fix |
|---|---|---|---|---|
| K-1 | Nit | `android/build/src/main/AndroidManifest.xml` (`<profileable android:shell="true">`) | Godot template default lets `adb shell` profile a release build. Not a network or data risk. | Remove from the committed template for release builds. |
| K-2 | Minor | n/a | Only the debug manifest and debug APK were checked by the tester (R42). The release APK is not yet built. | Re-run `aapt2 dump permissions` on the signed release APK before release (milestone plan already says so). |

## 10. Story outcomes unchanged by Blessings and modes; Back never quits mid-run

Checked `ModifierStack` and every stage:
- `ModifierStack.apply` accepts only the 13 `TUNABLE_KEYS`; unknown keys are returned unchanged and recorded in `rejected_keys`; `allows` returns true for the five `STORY_KEYS`. `BlessingModifier` refuses a card with any key outside its `REGISTRY` (`modifier-stack.gd:51-58`).
- Win is never routed through modifiers: `StageBase.win()` takes no modifier input (`stage-base.gd:80-84`). Lion/bear win on `win.count` hits regardless of Blessings; the only Blessing touching bosses is `stun-time` (adds seconds, does not change hit counts or the flee). Night win requires `alive >= minAlive` and no Blessing touches sheep counts. The harp stage cannot fail. Lines are emitted from data by `play_event` with no modifier in the path.
- Mode effects are limited to enemy speed, sheep wander, enemy spawning, time limits, fall/lose veto, refill and rest time (data-driven in `balance.json`). The Lamb overrides in `ch1.json` replace the lion/bear win rule with gather-sheep, which is the spec'd "no enemies" behaviour; story lines are identical across modes (test `test-modifiers.gd` `_story_data`).
- Back: `Main._handle_back` quits only in `Screen.TITLE`; stage host and Blessing pick open or close the pause menu; chapter select goes to the title; summary goes to chapter select; ignored during the failure fade. `config/quit_on_go_back=false`, `auto_accept_quit=false`. The 250 ms dedupe prevents the double ui_cancel plus Android back request. `NOTIFICATION_WM_CLOSE_REQUEST` quits, which Android Back does not send.

| ID | Sev | File:line | Issue | Suggested fix |
|---|---|---|---|---|
| O-1 | Minor | `tests/test-modifiers.gd:97-123,129-148` | The "AC-ALL-3" tests check stack keys and story-line data across modes x Blessings, not the actual win/fail outcome of each stage with each Blessing (for example: lion still flees after exactly 6 hits with every Blessing; night still ends at 90 s). The stage tests run a few Blessings only. | Add a parameterised stage test: for each mode x each Blessing, simulate each Chapter 1 stage and assert the same terminal outcome (won / same story events) for a scripted winning bot. |
| O-2 | Minor | `screens/blessing-pick` + `main.gd:207-210`; test report D5 | "Restart stage" or "Change mode" from the pause menu over the Blessing pick replays the stage just cleared and drops the pending pick (a re-roll of the three cards is possible). No story effect, but unintended. | When `awaiting_blessing`, hide "Restart stage" or make it re-show the same options. |
| O-3 | Nit | `main.gd:59-61` | The 250 ms dedupe also swallows a deliberate fast second Back press. | Acceptable. |

## 11. Android and export hygiene

| ID | Sev | File:line | Issue | Suggested fix |
|---|---|---|---|---|
| H-1 | Major | `android/build/src/main/assets/**` (271 tracked files: `assets.sparsepck`, `project.binary`, 100+ `.gdc`/`.remap`, copies of `data/*.json`, `icon.svg`, compiled `tests/*.gdc`); `.gitignore` | Godot's gradle export output is committed. These files are regenerated on every export, go stale at once (they already differ from `data/` after each change), duplicate every JSON data file (so searches and diffs hit two copies), and include the compiled test scripts. The `.gitignore` change in this branch ignores `android/build/build/` and `libs/` but not `src/main/assets/`. | `git rm -r --cached android/build/src/main/assets` and add `/android/build/src/main/assets/` to `.gitignore`. Keep the template files (gradle files, manifests, `res/`, `GodotApp.java`) which are the baseline commit. |
| H-2 | Minor | `docs/` has no `.gdignore`; 50 evidence PNGs and 50 `.png.import` files tracked; `docs/concept/*.import` | Godot imports the docs folder (builds `.godot` cache, adds `.import` noise). The PNGs total 1.5 MB, fine in size. | Add `docs/.gdignore` and `git rm` the `docs/**/*.import` files. |
| H-3 | Minor | `.gitignore` | `*.keystore` and `/builds/` are ignored. Not ignored: `*.jks`, `*.p12`, `*.pem`, `.env`, password files. The build log says the release keystore and password file live in `~/.shepherd-king-signing`, outside the repo (good). No keystore, password or token is committed (grepped the full tree; only Godot's gradle template references keystores generically). | Add `*.jks`, `*.p12`, `*.password`, `.env` as a safety net. |
| H-4 | Major | `docs/test-report-m1.md` header (commit `116e616`, 358 passed, 6 FAIL) vs HEAD `f878653` (410 passed) | The test report was produced against an older commit and still lists D1, D2, D3, D4, D6 as open FAILs. The fix commit `f878653` claims to fix them, with unit tests (`test-line-queue.gd`, `test-fixes.gd`) but no device re-test is recorded. Rows R8, R16, R18, R20, R27, R30 are therefore unverified on device for the current code, and merge evidence must match the code being merged. | Have the tester re-run the failing rows (and R49 Resume from Blessing pick pause) on the current build and add an addendum with the commit hash. |
| H-6 | Nit | `export_presets.cfg:47-49` | `launcher_icons/*` are empty, so the default Godot icon is used (see L-1). `version/name="0.0.1"` vs plan "0.1.x" for M1. | Set version 0.1.0 and real icons before the M1 APK. |
| H-7 | Nit | `android/build/gradle/wrapper/gradle-wrapper.jar` | 59 KB binary, standard template, Apache-2.0. | None. |

## docs/test-report-m1.md: claims checked against code (cheap checks)

- 36 lines / 8 stages / 2 cutscenes: matches (re-run).
- R42 no permissions and R43 no network: confirmed by my own grep and manifest read.
- R39 corrupt save kept as `save.json.bad`: matches `save-data.gd:34`.
- R33/R34 safe area and 40/32 px text: match `ui/safe-area.gd`, `ui/subtitle-box.gd`.
- R45 node count: pools confirmed in code.
- R11 "matches balance.json": only the 0.6 multiplier is in data; base speeds are in code (D-1).
- R48/D6 "no audio folder": no longer true (audio added later), but the audio is still never played (L-2).
- Sections D1, D2, D3, D4, D6, D8, D10, D11, D13: the current code does contain fixes (focus restore in `main.gd:174-189`, `LineQueue` plus `when_drained` in `stage-host.gd:142-145`, locked empty chapters in `chapter-select.gd:73`, Lamb fill-to-three in `run-state.gd:139-154`, Lamb harp in `stage-play-base.gd:139`, hold counts as tap on release in `stage-host.gd:136-139`, per-attempt seed in `run-state.gd:50-53`). D5, D7, D9, D12 remain as described in area 10, C-3.

## Summary table of Major findings

| ID | Area | One line |
|---|---|---|
| C-1 | Correctness | Shepherd's Staff, Song of Courage and Watchful Eyes have no effect |
| D-1 | Data | Balance and feel numbers live in code, none in data |
| L-1 | Licensing | Godot default icon (CC BY 4.0) used for icon/launcher/banner; CREDITS says original and no attribution needed |
| L-2 | Licensing / scope | 132 audio files never played; Audio paths and extensions do not match the files |
| H-1 | Export hygiene | 271 generated Android export files committed (stale duplicates of data and compiled tests) |
| H-4 | Process | Test report is for an older commit and lists the now-fixed defects as FAIL; no device re-test of the fixes |

## Final verdict

**CHANGES REQUESTED.** Must be fixed before merge:

1. C-1: implement Shepherd's Staff, Song of Courage and Watchful Eyes (with a stage-level test each), or remove them from the Chapter 1 pool with Andrew's agreement.
2. D-1: move the balance and feel numbers listed in D-1 into the data files and read them from there; update `data-schema.md`.
3. L-1: replace the Godot default icon and derived launcher/banner/splash art, or add the required CC BY 4.0 attribution and correct `CREDITS.md`.
4. L-2: either wire the audio (matching directories, formats and call sites, plus re-test) or remove the unused audio files and their CREDITS rows from this branch; add `tests/*` to the export `exclude_filter` (L-4).
5. H-1: remove `android/build/src/main/assets/` from version control and ignore it.
6. H-4: tester addendum on the current HEAD (rows R8, R16, R18, R20, R27, R30, R49 re-run on device) and update the counts and commit in `docs/test-report-m1.md`.

Strongly recommended in the same pass (Minor): T-1 move "Continue" to data, A-3 explicit mode list instead of parsing the pause string, C-4 approve or drop the sheep-saved line cap, O-1 stage-outcome test across all Blessings, D-2/D-3/D-4 duplicate numbers, H-2/H-3 hygiene.
