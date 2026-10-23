# Milestone 1 test report: Shepherd King, Chapter 1

Tester: independent (did not write the code). Branch `feature/milestone-1-core-chapter-1`, commit 116e616 (git not run by the tester; commit as stated in the brief).
Build under test: `builds/shepherd-king-debug.apk` (re-installed with `adb install -r` before testing; APK is newer than every source and data file). Version name inside the APK is 0.0.1.
Device: Android TV emulator `emulator-5554`, 1280x720, software rendered (frame rate not measurable). All "1920x1080" numbers below are screenshot pixels times 1.5.
Evidence: `docs/evidence/m1/*.png` (640x360, or 1280x720 for 2x2 contact sheets of four 640x360 frames).
Throwaway drivers (not in repo): `/private/tmp/claude-501/-Users-lema-d-a-v-i-d/f711f223-fcaa-4a32-a1a9-d7b7ec7ecf84/scratchpad/drv/` (`flow.gd` drives the real `main.tscn` with synthetic key events at accelerated time, `acs.gd` and `bear2.gd` are fake-clock stage checks) and `shep_tired.py`, `normal_fail.py`, `watch_harp.py`, `watch_gen.py` (device drivers and frame-capture watchers).

## Summary

| Result | Count |
|---|---|
| PASS | 39 |
| FAIL | 6 |
| NOT-TESTABLE | 4 |

Top defects: D1 softlock on the Blessing pick after Back, Back (no focus, D-pad and OK dead). D2 six scripted lines (sunrise x3, lion and bear closing narration, Saul line, narrator "When David played...", plus the 1.6 opening narrator line) are never visible on screen, so AC-1.6 "ends with the Saul line" and AC-ALL-4 fail. D3 chapter 2 card is enabled after clearing chapter 1 but does nothing. D4/D6 Lamb mode offers fewer than three Blessings and has no harp free-play and no audio.

Existing automated checks, re-run: `Godot --headless -s res://tests/runner.gd` gives 358 passed, 0 failed, 0 skipped. `python3 -I tests/check-data-fidelity.py` gives "OK: 36 lines, 8 stages, 2 cutscenes; all checks passed". These pass even though D2 exists, because they test data and stage signals, not what is rendered.

## Criteria table

IDs are for this report only. "Dev" = tested on the emulator with real D-pad/OK/Back key events. "Sim" = fake-clock or accelerated-time driver against the real code (stage classes, or the real `main.tscn`).

| ID | Criterion | Result | Evidence |
|---|---|---|---|
| R1 | AC-1.2a Nights 1 to 3 last 90 s | PASS | Sim: `acs.gd` Shepherd and Lamb nights end at elapsed 90.05 s for all three nights. `flow.gd` through Main in Normal: `flock el=89.9 / 90.0 / 90.0` at the end of nights 1, 2, 3. Dev: Lamb Night 3 and Normal Night 1 each ended about 86 to 92 s after OK (wall clock, manual timing, not precise; software renderer did not slow the game). |
| R2 | AC-1.2b Normal: night won iff at least 3 of 10 sheep alive at sunrise | PASS | Sim: 3 nights x 12 seeds, idle David, Normal: 36/36 failed with reason `sheep-below-min` as soon as alive < 3 and always before 90 s; 0 inconsistent outcomes (a win with <3 alive, or a fail with >=3 alive). Bot that rescues sheep and slings: won all 3 nights with 10 alive (`out_normal.txt`). Dev: Normal Night 1 won with 10 of 10 alive; Normal idle Night 1 failed at about 83 s (`normal-fall-fade-restart.png`). Boundary 3 alive wins / 2 alive fails is also in the repo tests. |
| R3 | AC-1.2b Shepherd and Lamb cannot fail a night | PASS | Sim: Shepherd nights won with 0 sheep alive and 1 to 5 hits taken (`acs.gd`: alive=0, won=1, failed=0). Lamb nights won with 10 alive, peak predators 0. Dev: Lamb and Shepherd nights completed (`line-1-2-night1-lamb.png`, `nsh1.png`, `nsh5.png`). |
| R4 | AC-1.3 lion drops the lamb after 3 hits, flees after 3 more | PASS | Sim: `acs.gd` sequence hit1..hit6: `dropped` becomes true exactly at hit3, `fled` and stage win exactly at hit6, in Normal and Shepherd. Dev: Normal and Shepherd lion fights completed by OK taps (`normal-lion-bear-harp-visuals.png`). |
| R5 | AC-1.4 bear runs away (6 hits [A]); a hit while slipped counts double | PASS | Sim: `bear2.gd`, 8 seeds, only throwing while `SLIPPED`: hit weights `[2,1,2,1]` (total 6, win). Always throwing: `[1,1,1,1,1,1]`, won in 6.4 to 7.4 s. Dev: bear stage completed in Normal and Shepherd. See note N2 (hitting a charging bear stops the charge, so the slip rarely happens when the player just spams OK). |
| R6 | AC-1.6 harp stage lasts 60 s | PASS | Sim: `acs.gd` idle harp in all 3 modes: win at 60.05 s. Dev: `harp-end-no-saul-line.png` and the timeline in the Lamb, Shepherd and Normal runs. |
| R7 | AC-1.6 misses never end the stage | PASS | Sim: idle harp, 38 misses, `failed=0`, won=1 in Normal, Shepherd and Lamb. |
| R8 | AC-1.6 stage ends with the Saul line ("I feel better. Stay, young David. Stay and play.") | FAIL | Dev: captured 16 consecutive frames across the harp end (about 90 ms apart). The last harp frame is followed directly by the run-summary screen; no frame shows the Saul line or the narrator "When David played, Saul was refreshed." (`harp-end-no-saul-line.png`). Sim: the lines are requested (`acs.gd` shows them in order) but the stage host swaps screens in the same call stack. See D2. |
| R9 | Lamb: no predators, no failure | PASS | Sim: peak predators 0 in all 3 nights; idle Lamb run never fails. Dev: Lamb nights show only sheep (`line-1-2-night1-lamb.png`); lion and bear stages are replaced by lamb gathering (`line-1-4-bear-lamb-gather.png`). Hearts HUD is still shown (cosmetic). |
| R10 | Shepherd cannot end a run; tired rest is 3 s then play continues | PASS | Sim (`out_sh_idle.txt`, Main flow, idle David): repeated `TIRED 3.0` then `RESTED` exactly 3.0 s later, no `RUN_FAILED`, hearts refilled, stage continues. Dev: `shepherd-tired-rest.png` (dim overlay, empty hearts, line "You can do it. Stay close to the flock.", stage frozen, hearts full again about 3 s later, lion still circling). |
| R11 | Shepherd: enemies slower | PASS | Sim: jackal/wolf speed 54/60 vs 90/100 in Normal (0.6x); lion circle speed 168 vs 280; bear charge 540 vs 900. Matches `data/balance.json` and spec [A 60%]. Sheep wander multiplier 0.5 is in data and used by the stage. |
| R12 | Normal: falling restarts the chapter at 1-2-night-1 with a random "David falls" line | PASS | Sim: idle Normal, 8 falls: every fall goes back to `1-2-night-1`, Blessings cleared, lines drawn from the three-line pool with no immediate repeat (`out_idle.txt`). Idle at the lion (`idleboss`): 3 contact hits at 1.5 s spacing then fall back to Night 1 at about 15 s. Dev: `normal-fall-fade-restart.png` (fade to black, "Be strong and of good courage. One more time!", restart of Night 1 with 10 sheep and 3 hearts). Note the data restarts at 1-2-night-1, not at 1.1 (matches `restartStage` in `data/chapters/ch1.json`). |
| R13 | Script fidelity: data checker | PASS | `check-data-fidelity.py` OK (36 lines). My own comparison of `data/dialogue/ch1.json`, `data/cutscenes/ch1.json` and `data/recurring-lines.json` against `docs/script-source.md` found no text differences (see differences list below for format and display notes). |
| R14 | On-screen: 1.1 opening lines, caption and tutorial prompts exact | PASS | Dev: `line-1-1-narrator.png`, `line-1-1-david-caption.png` ("I will, Father. The LORD is my shepherd too!" with caption "The LORD is my shepherd; I shall not want." / Psalm 23:1), tutorial prompts "Use the arrows to walk." then "Walk near a lost sheep to bring it back." then "Press OK to throw a stone." (`tut-n3.png`). Order matches the script. |
| R15 | On-screen: 1.2 night start and "Got you!" lines | PASS | Dev: Night 1 "The sun goes down. Something moves in the grass." (`line-1-2-night1-lamb.png`), Night 2 "Stay close, little ones. I'm here." (`line-1-2-night2-david.png`). Sim (Main flow): Night 3 line and "Got you! Back to the flock." shown. |
| R16 | On-screen: 1.2 sunrise line "Morning comes. The sheep are safe." | FAIL | Dev: frames around the Normal Night 1 end show the night, then the Blessing pick, never the line (`night-end-no-sunrise-line.png`). Sim: no `SHOW` of this text in any Main-flow log. See D2. |
| R17 | On-screen: lion and bear opening lines | PASS | Dev: "Hey! That lamb belongs to my father!" (`normal-lion-bear-harp-visuals.png`), "LORD, help me again!" (`line-1-4-bear-lamb-gather.png`). |
| R18 | On-screen: lion and bear closing narrator lines, lion caption reference 1 Samuel 17:35 | FAIL | Sim (Main flow, three runs): "David chased the lion and saved the lamb from its mouth." (+ "1 Samuel 17:35") and "The lion and the bear could not beat the LORD's shepherd." are requested at win but never rendered, because the Blessing pick replaces the stage in the same frame. Same cause as R8 and R16; not separately captured on device (device capture was done for night end and harp end only). See D2. |
| R19 | On-screen: 1.5 Samuel cutscene with caption "The LORD looketh on the heart." / 1 Samuel 16:7 | PASS | Dev: gold-light overlay with the caption and reference (`line-1-5-gold-caption.png`), all other lines in script order (`line-1-5-narrator-eliab.png`, `line-1-5-samuel-all-sons.png`, `line-1-5-narrator-spirit.png`). Order: Samuel, Narrator (Eliab), gold caption, Samuel, Jesse, Samuel "This is the one.", Narrator (Spirit, ref 1 Sam 16:13). Identical to the script. |
| R20 | On-screen: 1.6 narrator opening, servant line, Saul line, narrator closing, end card | FAIL | Dev and Sim: "King Saul was troubled, and his heart was dark." and the servant line are emitted in the same frame, so only the servant line is ever shown (`line-1-6-harp-start.png`). Saul line and closing narrator never shown (R8). The end card text "Chapter 1 complete — The Shepherd. Next: The Hero." is visible, but only on the run-summary screen (`line-1-6-summary-endcard-lamb.png`, `run-summary-shepherd.png`), not as the in-stage end card. See D2. |
| R21 | Recurring lines (falls, tired, stage cleared, pause, title, summary) on screen and exact | PASS | Dev: falls line, tired line, "Well done! Pick a blessing." and "Safe for now. What will help you next?" (`sh-bless1.png`), pause items, title (`t01-title.png`), summary template. All match the script text; see differences list for punctuation. |
| R22 | Remote-only (D-pad, OK, Back): Lamb start to finish | PASS | Dev: title, chapter select, 1.1 with tutorial by D-pad and OK, three nights, lion, bear (walked to the lambs with D-pad), Samuel cutscene, harp, summary. Chapter 2 unlocked afterwards (`ch2-click.png`). |
| R23 | Remote-only: Shepherd start to finish | PASS | Dev: full chapter including Blessing picks and summary (`run-summary-shepherd.png`). Input was D-pad for the tutorial and OK taps afterwards. |
| R24 | Remote-only: Normal start to finish | PASS (partial caveat) | Dev: one full Normal run completed with D-pad for the tutorial and then OK taps only; all 3 nights won with 10 sheep alive, lion and bear won, summary reached (`normal-lion-bear-harp-visuals.png`; summary screen seen on the device). I did not play Normal skillfully; one fall-and-restart was also exercised (R12). It is easier than expected: plain OK mashing cleared Normal (see N1). |
| R25 | Blessing pick after stages with `blessingAfter`; left/right + OK; three cards | PASS | Dev: Normal and Shepherd: three cards (`sh-bless1.png`), LEFT/RIGHT move the gold focus, OK picks (`b1.png`, `b2.png` show the focus move). Offered after Nights 1, 2, 3, lion and bear (data `blessingAfter: true`), never after cutscenes or the harp. Sim: 5 picks per Normal run, no duplicates. |
| R26 | Run summary appears at the end | PASS | Dev: Lamb, Shepherd and Normal runs end on the summary with "Sheep saved: N · Stones thrown: N · Blessings: ..." and the completion line; Continue is focused. |
| R27 | Lamb mode offers three Blessing cards per stage | FAIL | Dev and Sim: Lamb offers 2 cards after Night 1, 1 card after Night 2, and none after Night 3, lion or bear (the offer is silently skipped). Card count is cut by `modeRelevance`. `docs/data-schema.md` documents the filter, but the script and spec say three cards. See D4. |
| R28 | Back pauses mid-stage (night, cutscene) and freezes the stage | PASS | Dev: pause in Night 1 froze the stage (pixel diff of two frames 4 s apart was empty, `pz1.png`), Back again resumed (`pz3.png`); pause in the 1.1 cutscene (`pause-cut.png`). |
| R29 | Pause menu items match the script | PASS | Dev: Resume, Restart stage, Change mode (Lamb / Shepherd / Normal) with the current mode on a second line, Quit to title (`pause-cut.png`, `pause-mode-focus.png`). "Change mode" is one button that cycles Lamb to Shepherd to Normal; verified Normal to Lamb to Shepherd to Normal, each restarting the stage and saving the mode (`mode-after1.png`). |
| R30 | Back closes menus | FAIL | Dev: Back opens the pause menu over the Blessing pick, Back closes it, and then no card has focus and the D-pad and OK do nothing: softlock (`bk-bless-pause.png`, `bk-bless-closed.png`, `bk-bless-stuck.png`). Back in the pause menu over a stage works. See D1. |
| R31 | Back exits the app only from the title screen | PASS | Dev: Back at the run summary goes to chapter select (`bk-sum-to-cs.png`), Back at chapter select goes to title (`bk-cs-to-title.png`), Back at title exits to the launcher; process gone (`pidof` empty, top activity is launcher; `bk-title-exit.png` is the launcher). Back during a stage, a cutscene, a Blessing pick and the Fade never exits. Back during the death fade is ignored by design. |
| R32 | Back behaviour: cutscene, Blessing pick, chapter select, run summary | PASS (with D1) | Cutscene: pause menu. Blessing pick: pause menu (but see D1 after closing). Chapter select: to title. Run summary: to chapter select. |
| R33 | TV safe margin: content inside 5% (96 px / 54 px at 1920x1080) | PASS | Dev, measured on raw 1280x720 screenshots (title, chapter select, Blessing pick, pause, summary, HUD, subtitle bar, harp, nights, cutscenes): all UI bounding boxes sit at x 96 to 1824 and y 54 to 1026 at 1920x1080 scale (HUD top 58, subtitle bottom exactly 1026). Gameplay field is the same rectangle. |
| R34 | Subtitle readable | PASS | 40 px text (32 px reference) on a 70% black panel, white text. On the 1280x720 screenshots it is clearly readable. Gold-light text is dark brown on gold at about 5.9:1 contrast (estimate from colors). Judged on a monitor, not at 3 m on a TV. |
| R35 | Focus always visible on menus | PASS (with D1) | Gold outline plus slight scale on title button, chapter cards, mode row, pause items, Blessing cards, Continue (`t01-title.png`, `t02-chapter-select.png`, `t03-chapselect-mode-focus.png`, `sh-bless1.png`, `pause-mode-focus.png`). The one miss is the Blessing pick after pause (D1). The selected mode is shown by a gold fill and is distinguishable from focus. |
| R36 | No obvious overdraw or off-screen elements | PASS (with notes) | Wolves and jackals can draw over the hearts HUD at the top-left (`nsh5.png`, see D9); predators and dragged sheep leave the safe area on purpose. Subtitles disappear about 0.6 s before the next beat. |
| R37 | Persistence: chosen mode survives a restart | PASS | Dev: Lamb saved and restored (`persist1.png`), Shepherd saved and restored (`persist-shepherd.png`), Normal saved by the pause menu (`save.json` read via `run-as`: `"mode":"normal"`). Changing mode from the pause menu also changes the saved mode. |
| R38 | Persistence: chapter 2 unlock survives a restart | PASS | Dev: `save.json` has `chapters_unlocked: 2` after clearing chapter 1 in Lamb and in Shepherd; after `force-stop` and relaunch card 2 is enabled (`persist1.png`). Lamb and Shepherd completions unlock (balance flag `lambCompletionUnlocksNextChapter`). |
| R39 | Corrupt save handled | PASS | Dev: garbage JSON in `files/save.json`: app starts, defaults used (Normal, chapter 2 locked), corrupt file kept as `save.json.bad` (`corrupt1.png`). `chapters_unlocked: 99` is clamped to 4 (`corrupt2.png`). No crash, no log errors. |
| R40 | HOME then relaunch | PASS | Dev: HOME from the 1.1 cutscene, relaunch via the launcher intent: game continued from the same stage, input worked (`life-relaunch2.png`, `life-relaunch3.png`), no crash. |
| R41 | Sleep and wake | PASS | Dev: `KEYCODE_SLEEP` then `KEYCODE_WAKEUP`: `mWakefulness` Asleep then Awake, top activity still the game, OK input responsive (stone thrown), no crash (`life-wake1.png`, `life-wake2.png`). |
| R42 | No `uses-permission` / no INTERNET | PASS | `aapt2 dump badging`: no `uses-permission` lines; `aapt2 dump permissions`: none; `AndroidManifest.xml` strings: none. `export_presets.cfg` `custom_permissions` empty. LEANBACK_LAUNCHER and banner present, touchscreen and leanback `required=false`. |
| R43 | No external links, no network classes in code | PASS | Grep over `*.gd`, `*.tscn`, `*.tres`, `*.json`, `project.godot`, `export_presets.cfg` (excluding `android/build`, `docs`, `tests`) for `HTTPRequest`, `HTTPClient`, `http://`, `https://`, `shell_open`, `WebSocket`, `StreamPeer`, `TCPServer`, `UDPServer`, `ENet`, `PacketPeer`, `WebRTC`, `OS.execute`, `JavaScriptBridge`: zero matches. The only `OS.`/`Engine.` hits are in the Godot Android template test code (not used) and `get_tree().quit()` in `main.gd`. |
| R44 | No gore in visuals | PASS | All visuals are flat placeholder shapes: sheep, jackal and wolf (circle with ear and red eye dot), lion (circle with face), bear (brown shape), David. Defeated animals simply run off. The fall is a fade with text. |
| R45 | Unbounded node growth during a long night | PASS | Sim: `Performance` monitors sampled every 20 game seconds in a Normal run through Main: 77 nodes and 0 orphans for the whole of nights 1 to 3 (objects 1712, 1713, 1714); predators and stones are pooled. |
| R46 | Frame rate, 60 fps on TV | NOT-TESTABLE | Emulator is software rendered. |
| R47 | Physical remote hardware, real TV (button mapping incl. Back, OK hold) | NOT-TESTABLE | Only `adb shell input keyevent` was used. Back arrives both as `ui_cancel` and as the Android back request; the 250 ms dedupe handled both in every test. |
| R48 | Audio (narrator, harp, music) | NOT-TESTABLE | There is no `res://audio/` folder, so every `Audio` call is a silent no-op. Nothing to test. See D6. |
| R49 | Real use of Resume button and Quit-to-title from the Blessing pick pause | NOT-TESTABLE | Not run because it needed another 90 s night each; the code path (`_close_pause`) is shared with the Back path in D1, so Resume is likely to leave the same unfocused state. |

Row count: 49 rows. PASS 39 (rows marked "PASS (with ...)" are counted as PASS and their caveat is stated in the row), FAIL 6 (R8, R16, R18, R20, R27, R30), NOT-TESTABLE 4 (R46 to R49). The four script-line rows R8, R16, R18, R20 share one root cause (D2); R30 is D1; R27 is D4.

## Prioritized defect list

Severity scale: High = blocks play or fails a stated acceptance criterion; Medium = visible spec gap or confusing behaviour; Low = cosmetic, balance or edge case.

### D1 (High) Blessing pick softlocks after the pause menu is closed
- Steps (Normal, Shepherd or Lamb): finish Night 1 so the Blessing pick appears; press Back (pause menu opens); press Back again (menu closes); press D-pad left/right/up/down and OK.
- Expected: focus is back on a card (or first card) and left/right plus OK pick one, as at the first appearance (AC-ALL-2: Back closes menus).
- Actual: no card is highlighted, D-pad and OK do nothing, forever. The only way out is Back, then "Restart stage" (replays Night 1) or "Quit to title". Evidence: `bk-bless-pause.png`, `bk-bless-closed.png`, `bk-bless-stuck.png`, `bk-restart-from-bless.png`.
- Probable cause (read from `main.gd`, `screens/pause-menu/pause-menu.gd`): the pause menu's buttons take focus and are freed on close; nothing re-grabs the card focus. Resume button probably the same (R49, not run).

### D2 (High) Win-event story lines are never visible; 1.6 opening line is overwritten
- Steps: play any Chapter 1 run to the end of a night, the lion, the bear and the harp. Capture frames around each end (device) or log `SubtitleBox` text per frame (`flow.gd`).
- Expected: sunrise line "Morning comes. The sheep are safe." after each night; lion narrator "David chased the lion and saved the lamb from its mouth." with "1 Samuel 17:35"; bear narrator "The lion and the bear could not beat the LORD's shepherd."; at harp end the Saul line "I feel better. Stay, young David. Stay and play.", then "When David played, Saul was refreshed." (1 Sam 16:23), then the end card; at harp start "King Saul was troubled, and his heart was dark." then the servant line. (AC-1.6 "ends in the Saul line", AC-ALL-4.)
- Actual: the stages call `play_event(&"win")` and then `win()` in the same call; `StageHost` immediately runs `RunState.advance()` and `Main._swap()` frees the stage host, so these lines are set but never drawn. Device frames: `night-end-no-sunrise-line.png`, `harp-end-no-saul-line.png`. At 1.6 start both opening lines are emitted in one frame, so the narrator line is replaced before drawing (`line-1-6-harp-start.png`). Six lines affected: sunrise (x3 nights), lion narrator, bear narrator, troubled narrator, Saul line, refreshed narrator. Only the chapter-complete card reaches the screen, on the summary page.
- Why the existing tests did not catch it: they count `line_requested` signals, not rendered frames.

### D3 (Medium) Chapter 2 card is enabled but inert
- Steps: clear Chapter 1 in any mode, press Back or Continue to reach chapter select (focus returns to card 1), press right, OK. (Also: after choosing a mode, pressing Up from the mode row focuses card 2, not card 1.)
- Expected: either a "coming soon" message or the card stays locked until Chapter 2 exists; chapter cards 2 to 4 carry titles.
- Actual: card 2 shows only the digit "2", looks unlocked, OK does nothing (no error in logcat). Evidence `ch2-click.png`.

### D4 (Medium) Lamb mode Blessing offers are fewer than three, then none
- Steps: Lamb mode, finish Night 1, 2, 3.
- Expected: three cards (script and spec "three Blessing cards"). Actual: 2 cards, then 1 card ("Pick a blessing" with a single card), then the offer is silently skipped. Cause: `modeRelevance` marks 5 of the 7 Chapter 1 cards as not relevant to Lamb (`docs/data-schema.md` documents this, so it is a spec vs design conflict to decide). Evidence `b1.png`, `b2.png`.

### D5 (Low) "Restart stage" from the Blessing pick replays the cleared stage
- Steps: Blessing pick, Back, Restart stage. Actual: Night 1 restarts and the pending pick is dropped (re-roll of Blessing options is possible). Evidence `bk-restart-from-bless.png`. Same for "Change mode" there.

### D6 (Medium, needs a decision) Lamb "OK plays the harp" and narrator audio are missing
- Script: Lamb mode "walk the fields, tap OK to play the harp, gather sheep, hear the narrator". Actual in M1: OK does nothing in nights and gather stages (no free-play harp outside 1.6) and there is no audio anywhere (no `res://audio/`; `Audio` calls are no-ops). Audio is NOT-TESTABLE (R48).

### D7 (Low) Placeholder art does not show the scripted scenes
- Flat colour backdrops derived from a hash of the cue name; the night is the same dull purple as the dawn cutscene; no sheep, brothers, Samuel, Saul or Jesse are drawn in cutscenes; the lion's held lamb is almost invisible (`shepherd-tired-rest.png`, `normal-lion-bear-harp-visuals.png`). Stage notes such as "Dawn over green hills" are not visible. Expected for a placeholder milestone, listed so it is not mistaken for finished.

### D8 (Low) Lamb gather can complete instantly
- Lamb lion stage (1 lamb at a random point): in 200 seeds, 1 spawned within 70 px of David's start and the stage ended on the first tick (seed 7 in my Main run). About 0.5% per attempt.

### D9 (Low) Predators draw over the HUD hearts
- Wolf or jackal at the top-left corner covers the heart icons (`nsh5.png` shows a wolf and jackal near the HUD).

### D10 (Low) Stone and follower counters show "0" all chapter
- Chapter 1 has unlimited stones and no followers, so the permanent "stone 0" and "follower 0" HUD counters suggest the player has no stones.

### D11 (Low) OK is registered on release; a hold of 2 s or more cancels the tap
- Stone throws and harp hits fire on button release; holding OK for 2 s or longer fires the unused hold action and ignores the tap (`stage-host.gd`). A toddler who presses and holds OK on the harp gets no hit.

### D12 (Low, spec ambiguity) Normal nights can also fail on hearts
- `data/stages/ch1.json` gives nights a `hearts-zero` lose entry; the spec table lists only "<3 sheep alive". Touching a predator costs a heart and scares it off. Both lead to the same restart.

### D13 (Low) Fixed random seed per chapter attempt
- `RunModel.rng_seed` is set once per chapter and every stage and every restart re-seeds from it, so predator spawn positions repeat on every restart of the same night. The "David falls" line pick uses a separate generator and does vary (R12).

## Notes (not defects)

- N1 Difficulty: in Normal, tapping OK without walking cleared the whole chapter on the emulator (auto-aim stones find the nearest predator). The bear fight can end in about 7 s.
- N2 Bear: a stone that hits the bear during its charge stops the charge, so the "slips on rocks, hit twice" window mostly appears only for players who wait. The double hit itself works (R5).
- N3 Subtitle timing: a line is shown for max(3 s, 0.06 s per character) and cutscene beats advance every 4 s unless OK is pressed; there is a short empty gap between lines.
- N4 Changing mode in the pause menu also overwrites the saved mode.
- N5 The Shepherd tired line "You can do it. Stay close to the flock." can appear during a boss fight where there is no flock; script-compatible, just contextual.
- N6 Resume after HOME: the cutscene continued from where it was, no crash.

## Script-fidelity differences list

Text of all 36 Chapter 1 lines in `data/` equals the script (checker plus manual comparison). Differences are in format, placement and visibility:

1. Six lines requested by the game never appear on screen (D2): `c1-2-sunrise` (Night 1 to 3), `c1-3-lion-narr` and its reference "1 Samuel 17:35", `c1-4-bear-narr`, `c1-6-narr-troubled` (overwritten by the servant line), `c1-6-saul-better`, `c1-6-narr-refreshed`.
2. Script "Caption: 1 Samuel 17:35" (1.3) is data-modelled as a reference attached to the narrator line, not a caption; never visible anyway.
3. 1.1: the verse caption "The LORD is my shepherd; I shall not want." / Psalm 23:1 appears at the same moment as David's line (caption box at the top, subtitle at the bottom). The script lists the caption after the line.
4. References are shown without the script's parentheses: "(1 Sam 16:13)" shows as "1 Sam 16:13", "(1 Sam 16:23)" as "1 Sam 16:23" (never visible), "(Ps 145:14)" as "Ps 145:14". Reference under "1 Samuel 16:7" is written in full as in the script.
5. 1.6 end card "Chapter 1 complete — The Shepherd. Next: The Hero." appears on the run-summary screen after the summary stats, not as a card in the stage.
6. Run summary line has no final period: "Sheep saved: 8 · Stones thrown: 23 · Blessings: Smooth Stones, Quick Feet" vs the script's trailing "." inside the quotes (ambiguous sentence period).
7. Title: "Shepherd King — Press OK to begin." is split into the heading "Shepherd King" and a button "Press OK to begin."; the em dash is not shown. The sheep is beside the button, as scripted (bounce not checked in a still frame).
8. Text not in the script appears on screen: Blessing names and descriptions (for example "David walks 20% faster"), the "Continue" button, chapter card names, Blessing references. Not a script violation if these were specified elsewhere (Blessings are in `data/blessings.json`); flagging because AC-ALL-4 compares against the script.
9. Order checked and matching the script: 1.1 (narrator, narrator, Jesse, David + caption, three tutorial prompts); 1.5 (Samuel, narrator, gold caption, Samuel, Jesse, Samuel, narrator). Scene descriptions (dawn hills, brothers in a row, oil and sparkles) are not drawn (D7).
10. In Lamb mode the line "Hey! That lamb belongs to my father!" plays at the start of the lion stage, which has no lion; "LORD, help me again!" likewise at the bear stage.

## What was not tested

- Real frame rate, real remote, real TV (emulator only).
- Audio (none exists).
- Resume button from the Blessing pick pause, Back during the tired rest, Back during the death fade (ignored in code, not exercised on device).
- Lion and bear closing lines on a device frame: shown by headless Main-flow logs only (same cause as the night and harp ends, which were captured on device).
- Chapters 2 to 4 (no data in M1).
- Skilful Normal play (only a fall-and-restart and a button-mash clear were exercised).
