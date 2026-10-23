# Milestone 1 re-test (after fixes)

Tester: independent (same role as `docs/test-report-m1.md`). Branch `feature/milestone-1-core-chapter-1`, HEAD f878653 as stated in the brief (git was not run by the tester).
Build under test: `builds/shepherd-king-debug.apk` (13:18), installed on `emulator-5554` at 13:31. No source or data file is newer than the APK.
Device: Android TV emulator 1280x720, software rendered. Frames were grabbed with `adb screencap` at about 10 per second and compared in order (so a line shown for 3 s appears in about 30 frames). Only D-pad, OK and Back key events were used (`--longpress` for walking and for the 2.6 s OK hold).
Evidence: `docs/evidence/m1-retest/*.png` (640x360, or 1280x720 sheets of 2x2 frames; the label `t=` on a frame is seconds from the start of that recording).
Throwaway drivers (not in repo): scratchpad `rec.py` (frame recorder), `sheetsel.py` (picks frames where the subtitle bar changes), `mash2.sh` and `mashuntil2.sh` (OK taps with random D-pad taps), `lib2.sh`.
Automated checks, re-run: `Godot --headless -s res://tests/runner.gd` gives 410 passed, 0 failed, 0 skipped (was 358). `python3 -I tests/check-data-fidelity.py` gives "OK: 36 lines, 8 stages, 2 cutscenes; all checks passed". Logcat over the whole session: no `SCRIPT ERROR`, `USER ERROR`, `USER WARNING` or `FATAL`; only the engine's "Failed to load cached shader, recompiling" after relaunch and Android's "Consumer closed input channel" after force-stop.

## Verdict

M1 meets its criteria for everything that can be tested on an emulator. All six rows that failed before (R8, R16, R18, R20, R27, R30) now pass on device frames in Lamb, Shepherd and Normal, defects D1 to D4, D6 (visual part), D8 to D11 and D13 are fixed, and I found no queue deadlock, no replayed line after a restart or quit, no double advance and no focus loss. Two Low issues are new (N-1, N-2) and one Low text mismatch (N-3). Not testable here: frame rate, a physical remote, audio (there is still no `res://audio/`). D5, D7 and D12 were deliberately left open and I did not re-check D5 or D12.

## Re-verified rows

| ID | Item | Result | Evidence |
|---|---|---|---|
| R8 | 1.6 ends with the Saul line "I feel better. Stay, young David. Stay and play." | PASS in Lamb, Shepherd, Normal | Order on device: Saul line, then "When David played, Saul was refreshed." with "1 Sam 16:23", then end card "Chapter 1 complete — The Shepherd. Next: The Hero.", then the summary. Each line is on screen about 3 s (Lamb: 87.1, 90.1, 93.1, summary 96.1; Normal: 219.1, 222.4, 225.2, summary 228.1). `lamb-1-6-lines-saul-refreshed.png`, `lamb-1-6-endcard-summary.png`, `shep-1-6-end-sequence.png`, `normal-1-6-end-sequence.png`, `normal-endcard-summary.png` |
| R16 | Sunrise "Morning comes. The sheep are safe." after each night | PASS | Lamb nights 1, 2, 3; Shepherd nights 1, 2, 3; Normal nights 1, 2, 3. Line appears at the 90 s mark, 3 s later the Blessing pick. `lamb-night{1,2,3}-sunrise-bless3.png`, `shep-night1-start-sunrise.png`, `shep-night2-sunrise-night3-start.png`, `normal-night{1,2}-sunrise-bless.png`, `normal-night3-sunrise-lion-hey.png` (Shepherd night 3 sunrise seen in a frame set, not kept) |
| R18 | Lion narrator + "1 Samuel 17:35" and bear narrator, before the Blessing pick | PASS in all three modes | Lamb `lamb-lion-narr-bless3.png`, `lamb-bear-narr-bless3.png`; Shepherd `shep-lion-narr-bless.png`, `shep-bear-narr-bless.png`; Normal `normal-lion-narr-bless.png`, `normal-bear-narr-bless-samuel.png` |
| R20 | 1.6 opening: narrator "King Saul was troubled, and his heart was dark." then servant line, both visible, in that order | PASS in all three modes | Lamb `lamb-1-5-end-1-6-start.png` (troubled line, then servant line "Find a boy who plays the harp well. Jesse's son David!"); Shepherd (frames in the same run, 35.3 and 38.3 s, not kept); Normal `normal-1-5-end-1-6-start.png`. End card now shown in the stage first, then on the summary (see R8) |
| R27 / D4 | Lamb offers three Blessing cards | PASS | Three cards after Night 1, Night 2, Night 3, the lamb gather (lion) and the bear gather. Pick is never silently skipped. `lamb-night{1,2,3}-sunrise-bless3.png`, `lamb-lion-narr-bless3.png`, `lamb-bear-narr-bless3.png` |
| R30 / D1 | Back closes menus; Blessing pick not a softlock | PASS | Lamb: Back, Back leaves the first card focused; D-pad moves focus; Back then OK (Resume) returns focus to the previously focused card; OK picks. Normal: same with Resume and with Back, Back. Shepherd: Back, Back, RIGHT, OK picked a card. `d1-lamb-blessing-back.png`, `d1-normal-blessing-pause-resume.png`, `shep-blessing-back-back-pick.png` |
| R49 | Quit to title from a Blessing-pick pause (was NOT-TESTABLE) | PASS | Blessing pick, Back, Quit to title: title screen with focus on the button. `quit-to-title-from-blessing.png`. Resume from the Blessing pause also PASS (see R30) |
| D3 | Chapter 2 card enabled but inert | FIXED | After clearing Chapter 1 in Lamb the save has `chapters_unlocked: 2` but card 2 is drawn locked like 3 and 4 and cannot take focus; no dead click. `d3-chapter-select-after-clear.png`. The card is blank apart from the digit (no "coming soon"), which matches the intent (locked until the chapter exists). |
| D6 | Lamb OK plays the harp | PASS (visual); audio NOT-TESTABLE | In a Lamb night, OK shows a gold ring above David each press; no stone. No sound (no audio files, as expected). `lamb-ok-harp-ring.png` |
| D8 | Lamb gather can complete instantly | PASS | Headless test `_gather_distance` passes (60 seeds, minimum distance >= 300 px at 1920 scale). On device the Lamb lion lamb and the three bear lambs were 358 to 793 px from David at 1920 scale (read by eye from the stage-start frames; those frames are not kept). I could not run the earlier 200-seed instant-win script because it uses an old stage API. |
| D9 | Predators draw over the HUD hearts | PASS | A jackal at the top left is drawn under the third heart (zoomed crop of a Normal night frame; the heart is on top). |
| D10 | Stone and follower counters "0" | PASS | No counters in any HUD frame of Chapter 1; only the hearts. Visible in every night frame above. |
| D11 | OK is registered on release; a 2 s hold cancels the tap | PASS | Normal 1.1 tutorial: `input keyevent --duration 2600 KEYCODE_ENTER` (a 2.6 s hold) ended the "Press OK to throw a stone." prompt on release and started Night 1. `hold` run frames, not kept. Shepherd and Normal nights: normal tap throws still work under OK mashing. |
| D13 | Fixed random seed per attempt | PASS | Normal Night 1, attempts 1, 2, 3 (second and third via pause > Restart stage): first jackal appeared at the top right, right edge and left edge respectively, at 13.7 s, 12.4 s and 12.2 s after the start. `d13-first-jackal-3-attempts.png` |
| D2 (six lines) | sunrise x3, lion narrator + 1 Sam 17:35, bear narrator, troubled narrator not overwritten, Saul line, refreshed narrator | PASS in Lamb, Shepherd, Normal | See R8, R16, R18, R20. Order matches the script. No line cut off: every line is held at least 3 s (LineQueue `max(3 s, 0.06 s per character)`). |

## Re-verified regression rows (touched by the fixes)

| ID | Item | Result | Evidence |
|---|---|---|---|
| R22 | Lamb, Chapter 1 start to finish with D-pad/OK/Back only | PASS | Tutorial (walk to the sheep with long-presses, OK), 3 nights (idle, they cannot fail), lamb gather, three-lamb gather (walked), Samuel cutscene, harp, end card, summary, Back to chapter select. |
| R23 | Shepherd, full chapter | PASS | D-pad for the tutorial, OK taps from Night 1 to the summary, 5 Blessing picks. Tired rest seen: `Tired` line "You can do it. Stay close to the flock." with dim overlay, hearts back about 3 s later, no failure. |
| R24 | Normal, full chapter | PASS (partial caveat) | Two complete Normal runs to the summary (`normal-endcard-summary.png`). Input was OK taps plus, in the second run, random D-pad taps; no skilled play. Of three such automated attempts one fell in the lion fight ("Be strong and of good courage. One more time!"), so Normal is not trivially cleared by mashing; I did not test deliberate dodging or how hard bears and wolves are for a human. |
| R12 | Normal: falling restarts at Night 1 with a "David falls" line | PASS | Idle Night 1: fade to black with "Even David had hard days. Let's go again.", Night 1 restarts with 10 sheep and 3 hearts, night-start line shown once. A fall in the lion fight also restarted at Night 1. |
| R10 | Shepherd tired rest | PASS | See R23. |
| R14 / R15 / R17 | 1.1 lines in order, tutorial prompts, night-start lines, lion and bear opening lines | PASS | 1.1 order: "Long ago, in Bethlehem...", "He was the youngest of eight brothers.", Jesse "David! Keep the sheep safe tonight. Bring them all home.", caption "The LORD is my shepherd; I shall not want." / Psalm 23:1 with David "I will, Father. The LORD is my shepherd too!", then the three prompts. Gaps between 1.1 lines are about 1 s (4 s beat, 3 s hold). |
| R19 | 1.5 Samuel cutscene in script order | PASS | Unskipped (Lamb): Samuel, narrator Eliab, gold caption + 1 Samuel 16:7, Samuel "Are these all your sons, Jesse?", Jesse, Samuel "This is the one.", narrator "The Spirit of the LORD came upon David from that day on." + 1 Sam 16:13. `lamb-1-5-end-1-6-start.png`. See N-1 for what happens when OK is pressed repeatedly. |
| R21 | Recurring lines (blessing prompts, tired, falls) | PASS | "Well done! Pick a blessing." and "Safe for now. What will help you next?" both seen. |
| R25 | Blessing pick: LEFT/RIGHT + OK, three cards | PASS | Normal, Shepherd, Lamb. |
| R26 | Summary appears; Continue focused | PASS | `lamb-1-6-endcard-summary.png`, `normal-endcard-summary.png`. |
| R28 | Back pauses and freezes the stage | PASS | Paused in 1.1 cutscene, Night 1 and 2, the Blessing pick and while a line was showing (see "Line queue" below). |
| R29 | Pause menu items | PASS | Resume, Restart stage, Change mode (shows current mode), Quit to title. Change mode Normal to Lamb restarted the stage and saved `"mode":"lamb"` (`change-mode-normal-to-lamb.png`). |
| R31 / R32 | Back exits only from the title | PASS | Back at the summary goes to chapter select, Back at chapter select goes to title (`back-summary-chsel-title.png`), Back at title exits to the launcher (process gone). Back in stages, cutscene, queue and Blessing pick opens the pause menu and never exits. |
| R37 | Mode persists across restart | PASS | Normal saved by the pause menu / chapter select, `force-stop`, relaunch: chapter select shows Normal selected (`persist-after-force-stop.png`). Lamb and Shepherd also seen in `save.json`. |
| R38 | Chapter 2 unlock persists | PASS | `save.json` `chapters_unlocked: 2` before and after `force-stop` and relaunch. |
| R40 | HOME then relaunch | PASS | HOME from the 1.1 cutscene, relaunch: game still running and responding (`lifecycle-home-sleep.png`). |
| R41 | Sleep and wake | PASS | `KEYCODE_SLEEP` (Asleep), `KEYCODE_WAKEUP` (Awake), top activity still the game, D-pad moved David (screenshot diff non-empty). No crash. |
| R42 / R43 | No permissions, no network code | PASS | `aapt2 dump badging`: no `uses-permission`; leanback `required=false`, banner present. Grep of `*.gd`, `*.tscn`, `*.tres`, `*.json` for the network and shell patterns used before: no hits outside `android/build`, `docs`, `tests`. |
| R2 to R7, R9, R11, R13, R33 to R36, R39, R44 to R45 | Timing, balance, data fidelity, safe margin, subtitles, corrupt save, visuals, node growth | Not re-run on device, carried over | The headless suite (410 passed) and the data checker cover timing, balance and fidelity. Frame timelines agree with R1/R6: nights end at 90 s (sunrise line at 90.0 to 90.4 s in every night) and the harp lasts 60 s (start 27.1 s, Saul line 87.1 s in the Lamb recording; 159.1 s to 219.1 s in Normal). Safe margin, subtitle style and the corrupt-save path were not re-measured. |
| R46 / R47 / R48 | Frame rate, physical remote, audio | NOT-TESTABLE | Software-rendered emulator, `adb input keyevent` only, no `res://audio/`. |

## Line queue (new LineQueue timing) checks

| Check | Result | Evidence |
|---|---|---|
| No line cut off | PASS | Every subtitle in the recordings stays at least about 3 s; last-line-of-stage waits for its full hold before the next screen (sunrise 3.0 s, lion narrator and reference about 3.4 s, harp end sequence 3 x 3 s). |
| Dead gaps | PASS | Longest empty gap between consecutive scripted lines is about 1 s in the 1.1 cutscene and about 3 s between the 1.5 beats (a visual beat without text). Win to next screen adds 3 to 3.4 s of line time. No gap longer than that. |
| Pause while a line is queued or showing | PASS | Night-start line and sunrise line freeze (dimmed) under the pause menu; on Resume the remaining time counts down and the stage then advances normally (`pause-resume-during-win-lines.png`: sunrise shown, pause, resume, line, Blessing pick). Not repeated or stuck. |
| Restart stage while win lines are showing | PASS | Back during the sunrise line, Restart stage: fresh night, night-start line, no blessing or sunrise appears later (checked for 15 s of the new night). `pause-during-win-lines-restart.png` |
| Quit to title while a line is queued, then start again | PASS | Night start line showing, pause, Quit to title, start chapter again: 1.1 opens with its own first line; no stale "sun goes down" or sunrise line. |
| Restart or fall: stale lines | PASS | After the Normal fall the previous stage's lines do not replay; the new night shows its start line once. |
| Back during queue and Blessing pick | PASS | See R30, R31 and the two rows above. |

## New defects and observations

### N-1 (Low) Cutscene visuals run ahead of the subtitles when OK is pressed repeatedly
- Repro: Shepherd or Normal, reach the 1.5 Samuel cutscene and press OK every half second.
- Expected: subtitles and the gold caption stay in script order (Samuel, narrator about Eliab, then the caption).
- Actual: each beat advances immediately but every subtitle is held at least 3 s, so the gold caption "The LORD looketh on the heart." appears while the previous Samuel line is still showing, and the narrator line "Samuel looked at tall Eliab, but God had not chosen him." appears about 2 s after the caption. No line is lost, order of the text lines is correct, and the cutscene still ends only after the last line has been shown. Without pressing OK (Lamb run) the order is exactly the script's. Evidence: `normal-bear-narr-bless-samuel.png` (frame at 46 s, 47 s) and Shepherd run frames at 17.7 to 22.4 s (not kept).

### N-2 (Low) Focus jumps between the chapter card and the mode row at the edges
- Repro: chapter select with only card 1 unlocked. Press RIGHT on card 1: focus goes to the "Lamb" button. From "Lamb" press LEFT: focus goes back to card 1. OK on card 1 starts the chapter.
- Expected: RIGHT on card 1 stays put (cards 2 to 4 are locked) and LEFT on "Lamb" stays put, so a player who wanted to pick a mode with LEFT cannot start the chapter by accident.
- Actual: I started the chapter by accident twice while moving to the mode row. Not a blocker; the mode row is reached with DOWN. (I did not check whether this existed before the fixes; D3's note says the focus order was already odd.)

### N-3 (Low) Lamb tutorial and summary still use stone wording
- In Lamb the 1.1 prompt still reads "Press OK to throw a stone." although OK now plays the harp, and the Lamb summary shows "Stones thrown: 1" (the tutorial tap). Matches the script text, so only a design note. (Hearts HUD is also still shown in Lamb, as in the first report.)

No other new defects: no deadlock (queue never stalled in about 30 pauses/restarts/quits across stages), no line replay after Restart, Quit, a fall or a mode change, no double advance (lines never skipped a stage), no focus loss on the Blessing pick (D1 is fixed on both exits from the pause menu).

## Not tested or not re-checked

- Frame rate, a physical remote and real TV, audio (none exists).
- D5 (Restart stage from the Blessing pick replays the cleared stage), D12 (hearts-zero fail in Normal nights), D7 (placeholder art): left open on purpose; I did not re-verify them. My attempt to repeat the D5 case missed the Blessing screen because the OK taps picked a card first.
- Corrupt save, safe margin measurement, subtitle contrast, node growth: not repeated; the fixes did not touch these.
- Skilled Normal play and difficulty for a human (only automated OK taps with random D-pad taps).
- The earlier 200-seed Lamb gather script (old API); D8 relies on the repo test plus the device frames.
- Frame times come from 10 fps screenshots on a software renderer, so sub-second timings are approximate.
