# Milestone 2 test report (Chapter 2: The Hero)

Tester: independent (did not write the code, changed no source, data or tests; git was not run). Branch `feature/milestone-2-chapter-2`, HEAD as given.
Build under test: `builds/shepherd-king-debug.apk`, rebuilt and installed with the supplied `deploy.sh` at the start of the session (deploy printed "Success"). Device: Android TV emulator `emulator-5554`, 1280x720, software rendered.
Input: only `adb shell input keyevent` (D-pad, ENTER/OK, BACK; `--duration` to hold a direction). Frames: `screencap` at about 8 per second, plus `screenrecord` (640x360) cut into 30 fps frames where timing mattered (victory, shake, pause).
Evidence: `docs/evidence/m2/*.png` (50 files, 640x360, 0.8 MB total). File names start with the criterion (`ac22-`, `ac25-`, `ac26-`, `ac27-`, `fid-`).
Throwaway drivers (scratchpad only, not in repo): `t2/lib.py`, `ch2bot.py`, `brook.py`, `glowok.py`, `golnorm.py`, `torun.py`, `pz.py`, `hide.py` (colour-based state detection, stone chasing, spear-lane dodging, glow detection, pause tests).
Automated checks, re-run on this HEAD: `Godot --headless -s res://tests/runner.gd` gives **1782 passed, 0 failed, 0 skipped**; `python3 -I tests/check-data-fidelity.py` gives "OK: 60 lines, 15 stages, 6 cutscenes, 2 chapters; all checks passed". `aapt2 dump permissions` on the APK prints only the package line: **no `uses-permission` entries**.
Logcat over the whole session (about 135k lines, about 15 app launches): no `SCRIPT ERROR`, `USER ERROR`, `USER WARNING`, `FATAL`. Only the engine's "Failed to load cached shader, recompiling" after each relaunch and one emulator-driver line (`eglCodecCommon removeVertexArrayObject`).

## Verdict

Chapter 2 is playable start to finish with D-pad, OK and Back only, in **Lamb, Shepherd and Normal** (each completed on device: Lamb twice, Shepherd once, Normal once after a forced restart cycle). All acceptance rows below pass. I found **no crash, softlock, stuck state, wrong spec number or time-scale leak**. Defects are all Medium or lower: the Goliath intro-line queue can show the laugh taunt after the hit (D-1), the THUD shake plays after the soldiers' faces instead of on them (D-2), and most script "visual beats" are not drawn (D-3, flat backdrops only, same style as M1). Chapter 3 stays locked and unfocusable after the chapter is cleared.

## Acceptance rows

| ID | Criterion | Verdict | Evidence |
|---|---|---|---|
| AC-2.2a | Road: carry basket to the camp, no enemies, hazards cart/goat/rolling rock on the road | PASS | Basket drawn on David; 2 carts, 2 goats, 2 rocks (=data); no enemies. `ac22-lamb-halfway-line.png`, `ac22-normal-timer-1-55.png` |
| AC-2.2b | 2 min limit in Normal only | PASS | Normal HUD shows the clock from 1:55 down to 0:01, then fade to black with the pool fall line "The LORD lifts up those who fall. Try again!" / "Ps 145:14" and a fresh road with 3 loaves and 2:00 (video: 0:15 at 118.0 s, 0:01 at 132.0 s, black at 133.0 s). Lamb and Shepherd roads show no clock and ran past it. `ac22-normal-timeout-fall-line.png` |
| AC-2.2c | A hazard bump costs one loaf | PASS | Normal 3 -> 2 -> 1 on bumps (HUD). Lamb/Shepherd count stops at the floor 1 (Lamb arrival with 1 loaf). `ac22-normal-loaves-1.png` |
| AC-2.2d | At least 1 loaf to finish | PASS | Lamb finished with 1 loaf, Normal with 2, Shepherd with 3. Not seen: Normal finish with exactly 1 (covered by the headless delivery tests). |
| AC-2.2e | Losing all loaves restarts in Normal; Shepherd/Lamb never fail | PASS | Normal: third bump -> black "Be strong and of good courage. One more time!" -> road again with 3 loaves, timer 2:00. Observed twice. Lamb/Shepherd: no failure from bumps or time (road idle runs not needed; Lamb road left at the 1-loaf floor). `ac22-normal-loaves-zero-fall-line.png` |
| AC-2.2f | Halfway line "I can see the tents!" and arrival line | PASS | Shown at the halfway mark on every attempt (also after each Normal restart) and "David heard a giant shouting across the valley." on arrival, then the Blessing pick. `ac22-lamb-halfway-line.png`, `ac22-lamb-arrival-line.png` |
| AC-2.5a | Brook: 0 to 5 stones, each pickup line, five-stone line | PASS | 5 collected (Lamb, Shepherd, Normal), 4 collected (Normal retry), 0 collected (Normal, walked straight to the exit). "Smooth and round. Just right." at each pickup; at the fifth "He chose five smooth stones from the brook." with "1 Sam 17:40". HUD stone counter matches. `ac25-brook-first-stone-line.png`, `ac25-brook-five-stones-line.png` |
| AC-2.5b | Scouts, sight, hide behind a rock, pushback not failure | PASS | 3 scouts walk the far bank with sight discs and a "!" when they see David (Shepherd and Normal; Lamb has none, as designed). Unhidden and seen: David is moved to the near bank at the same x, no stone lost, no failure. Standing below a rock for 30+ s with scouts passing: no "!" and no pushback. `ac25-scouts-seen-alert.png`, `ac25-pushback-near-bank.png`, `ac25-hidden-behind-rock-no-alert.png` |
| AC-2.6a | Shield phase, spears on D-pad lanes | PASS | Shepherd and Normal: gold shield-bearer bobs in front of Goliath, a red lane band warns, then a spear flies down one of 4 lanes (4 spears a round); Lamb has neither (data). OK on the shield costs no stone. `ac26-shield-and-spear-telegraph-shepherd.png` |
| AC-2.6b | Laugh, then 2 s forehead glow, OK in the glow ends the fight in EVERY mode | PASS | Glow measured 2.0 s (4.3 to 6.3 s, repeats every 6.1 s in Lamb). OK at the glow ended the fight in Lamb (several runs), Shepherd and Normal (with 4 stones). 1 stone thrown each time. `ac26-forehead-glow-lamb.png`, `ac27-hit-stone-flies.png` |
| AC-2.6c | Miss costs a stone | PASS | Normal: OK in the laugh phase -> "Again! The battle is the LORD's." and the counter 5 -> 4 (five presses took it to 0). `ac26-normal-miss-again-line-stone-4.png` |
| AC-2.6d | 0 stones in Normal restarts at 2.5 with the message | PASS | After the 5th miss: black "Go back to the brook and try again." then the brook with all 5 stones and no counter. Also with 0 stones carried: Goliath fails at once with the same message. `ac26-normal-out-of-stones-go-back.png`, `ac25-zero-stones-normal-goliath-fails-at-once.png` |
| AC-2.6e | Shepherd/Lamb never run out of stones | PASS | Lamb: 8 misses in 45 s, counter stays 5, no fail. Shepherd: 3 misses, counter stays 5; hearts reaching 0 only rests (hearts back to 3 after about 5 s), never restarts. `ac26-lamb-miss-stones-stay-5.png`, `ac26-shepherd-miss-stones-stay-5.png`, `ac26-shepherd-hearts-zero-rests-not-fails.png` |
| AC-2.6f | Stones carried from 2.5 are what you have | PASS | 5 -> 5 (Lamb, Shepherd), 4 -> 4 (Normal retry), 0 -> immediate fail. |
| AC-2.6g | Lines | PASS | "Am I a dog, that you come with sticks?" + "1 Sam 17:43", "You come with a sword and a spear.", "I come in the name of the LORD of hosts!" + "1 Sam 17:45", "Ha! Ha! A shepherd boy!", "Again! The battle is the LORD's." See D-1 for ordering. `ac26-goliath-enter-17-43.png`, `ac26-goliath-enter-17-45.png`, `ac26-goliath-laugh-line.png` |
| AC-2.7a | Slow motion, cut to soldiers' faces, THUD with screen shake | PASS (see D-2) | After the hit: stone flies, slow-motion backdrop with a slow dot about 1.2 s, cut to 3 soldiers with wide eyes about 1.7 s, then the screen shakes about 0.8 s (navy slivers appear at the screen edge on alternating frames at 103.87 to 104.7 s in the 30 fps extract). The shake plays on the next beat (narrator backdrop), not on the faces. `ac27-slowmo-stone-dot.png`, `ac27-soldiers-faces.png`, `ac27-shake-edge-visible.png` |
| AC-2.7b | NO body shown anywhere | PASS | No Goliath sprite or body in the stage after the hit, in slow motion, in the faces shot or in any later beat; the fall is only the narrator line. `ac27-narrator-17-49-no-body.png` |
| AC-2.7c | Lines in order and end card | PASS | "The stone hit Goliath in the forehead, and he fell on his face." + "1 Sam 17:49" (4.1 s), then "David won, and the Philistines ran away." (3.0 s), "David! David!" (3.0 s), end card "Chapter 2 complete — The Hero. Next: The Fugitive." (4.0 s), then the run summary with the same text and Continue. 17:51 is never shown. `ac27-david-won-line.png`, `ac27-soldiers-david-david.png`, `ac27-end-card.png`, `ac27-run-summary-lamb.png` |
| AC-2.7d | Chapter 3 stays locked and unfocusable | PASS | Save shows `chapters_unlocked: 3` after clearing (2 -> 3 observed from a save with 2), but card 3 is drawn locked and two extra RIGHT presses leave focus on card 2. `ac27-chapter-select-ch3-locked.png` |
| AC-ALL-1 | Chapter 2 completes with D-pad, OK, Back only | PASS | All three modes (see Verdict). |
| AC-ALL-2 | Back pauses mid-stage, closes menus, exits only from the title | PASS | Back paused in cutscene 2.1, road, brook, Blessing pick, Goliath and the 2.7 slow motion; Back in the pause menu resumes (David unmoved); Quit to title -> title; Back at the title left the app (process gone, launcher focused). Pause freezes the Normal road clock (1:56 -> 10 s paused -> 1:55). `back-pause-during-slowmo.png`, `ac22-pause-freezes-timer.png` |
| AC-ALL-3 | No Blessing alters a scripted outcome | PASS (partial) | Goliath fell to one stone with: Quick Feet + Smooth Stones (Lamb), Song of Courage + Quick Feet (Shepherd), Smooth Stones + Strength of the LORD + Song of Courage (Normal). Watchful Eyes and Still Waters were never owned at Goliath; hold-OK with Song of Courage not tried. |
| AC-ALL-4 | Every Chapter 2 line, caption, reference on screen in order | PASS with notes | See "Script fidelity" below. |

## Time scale after pause, restart, quit (slow motion in 2.7)

Method: pause during the slow-motion backdrop, then compare the speed of everything after with an uninterrupted run (lines hold 3.0 s, narrator 4.0 s, slow-mo about 1.2 s).

| Action while paused in slow motion | Result |
|---|---|
| Resume | PASS. Cutscene finishes in normal time: narrator 3.8 s, "David won" 3.0 s, soldiers 3.0 s, end card 4.0 s. |
| Restart stage | PASS. 2.7 replays: slow-mo 1.2 s, faces 1.8 s, narrator 4.0 s, the rest 3.0 s each. |
| Quit to title, start chapter 2 again | PASS. Cutscene 2.1 lines hold 3.4, 3.3, 3.0 s (same as a fresh launch). |

## Blessings

- Offers seen across about 14 Blessing screens: Quick Feet, Watchful Eyes, Strength of the LORD, Smooth Stones, Song of Courage, Still Waters only. Never a Chapter 1 or 3 card. Offers appear after 2.2 and after 2.5, and **not** after 2.6 (the victory goes straight to 2.7). PASS.
- Reset at chapter start: after a Chapter 1 Lamb run with picks, the Chapter 2 summaries list only Chapter 2 picks ("Quick Feet, Smooth Stones", "Song of Courage, Quick Feet", "Smooth Stones, Strength of the LORD, Song of Courage"). PASS.
- An owned card is not offered again within a run.

## Script fidelity (docs/script-source.md, Chapter 2)

Lines and references match the script word for word (speaker names are not shown, only the text; see D-5).

| Script beat | On screen | Match |
|---|---|---|
| 2.1 Narrator | "The Philistines came to fight Israel in the valley of Elah." | yes |
| 2.1 Jesse (1 Sam 17:17) | "Take this grain and bread to your brothers at the camp." + "1 Sam 17:17" | yes |
| 2.1 David | "Yes, Father! I'll run the whole way." | yes |
| 2.2 halfway / arrival | "I can see the tents!" / "David heard a giant shouting across the valley." | yes |
| 2.3 Goliath | "Send me a man! Who will fight me?" | yes |
| 2.3 David (17:26) | "Who is he, to defy the armies of the living God?" + "1 Sam 17:26" | yes |
| 2.3 Eliab | "Why are you here? Go back to your little sheep!" | yes |
| 2.3 David | "What have I done now? I only asked a question." | yes |
| 2.4 Saul | "You are only a boy. He is a warrior." | yes |
| 2.4 David + caption | "I fought a lion and a bear. God saved me then." with caption "The LORD that delivered me out of the paw of the lion… he will deliver me." and "1 Samuel 17:37" | yes |
| 2.4 armor | "I can't walk in this! I'll take it off." | text yes; armor falling not drawn (D-3) |
| 2.5 each stone / five | "Smooth and round. Just right." / "He chose five smooth stones from the brook." + "1 Sam 17:40" | yes |
| 2.6 entry | "Am I a dog, that you come with sticks?" + "1 Sam 17:43"; "You come with a sword and a spear."; "I come in the name of the LORD of hosts!" + "1 Sam 17:45" | yes |
| 2.6 laugh / miss | "Ha! Ha! A shepherd boy!" / "Again! The battle is the LORD's." | yes (timing D-1) |
| 2.6 out of stones | "Go back to the brook and try again." | yes |
| 2.7 | narrator 17:49, "David won, and the Philistines ran away.", "David! David!", end card text | yes, order as script |

Differences found:
1. Visual beats are mostly not drawn. 2.1 (valley armies), 2.3 (two armies on two hills, giant walking in, soldiers stepping back), 2.4 (Saul puts the armor on, David wobbles and falls) and the army running / Israel cheering in 2.7 show only a flat colour backdrop and the subtitle; the soldiers' faces in 2.7 are drawn. Same placeholder style as Chapter 1 cutscenes (D-3).
2. 2.6 "David walks into the valley with his staff, his sling and his bag": David simply starts at the left of the arena (no walk-in).
3. The caption box and David's line are shown together (caption above the subtitle bar) rather than one after the other. Matches the data; the script does not forbid it.
4. The run summary for Chapter 2 starts "Sheep saved: 0 · Stones thrown: N", a Chapter 1 stat label (D-6).

## Defects (prioritized)

| ID | Severity | Summary | Repro | Expected vs actual |
|---|---|---|---|---|
| D-1 | Medium | Goliath laugh/glow ordering: the first glow opens while the three entry lines are still queued, and a hit then waits for the queue and shows the taunt after the hit | Lamb, start 2.6, press OK at the first glow (about 2.5 to 4.3 s in; entry lines still on screen). `ac26-taunt-shown-after-hit-lamb.png` | Expected: laugh line, then glow, hit, cut-away at once. Actual: the stone is already in flight, the stage waits about 9 s (OK at 2.5 s, slow-mo at 11.7 s), "Ha! Ha! A shepherd boy!" appears over the glowing, hit Goliath, then the cut. In Shepherd/Normal the spear round delays the first glow so it does not happen there. Suggest holding the first laugh until the entry lines are done, or letting the win cut skip pending lines. |
| D-2 | Low | THUD shake is not on the faces shot | Any hit; 30 fps extract | Expected: "Cut to soldiers' faces ... A huge THUD shakes the screen." Actual: faces shown about 1.7 s unmoved, the shake (about 0.8 s, small amplitude) starts when the narrator backdrop appears. |
| D-3 | Low (Medium for story fidelity) | Script visual beats not drawn in 2.1, 2.3, 2.4, 2.7 (armies, giant, soldiers stepping back, armor falling, army running) | Play the cutscenes | Flat colour backdrops with subtitles only; only the soldiers' faces and Goliath/shield/scouts in play stages are drawn. Probably known placeholder art; flag for Andrew. |
| D-4 | Low | Blessings can be stacked by replaying 2.5 in Normal | Normal: fail 2.6 (or walk to the exit with 0 stones), the brook is replayed and a new pick is offered each time (observed: 3 picks in one chapter, 4 with the zero-stone walk) | Expected one pick per stage per run; actual one per completion of 2.5. Does not change any outcome (Goliath still falls to one hit). `keepBlessings: true` is in the data. |
| D-5 | Low | Speaker names are never shown | 2.3 | "Eliab:" and "Goliath:" are only in the script; subtitles show the bare text. Same as Chapter 1. |
| D-6 | Low | Run summary shows "Sheep saved: 0" and counts stones across failed attempts ("Stones thrown: 6" after 5 misses + 1 hit) | End of a Chapter 2 run | Cosmetic. |
| D-7 | Low | Glow is small | Goliath phase 2 | Yellow dot about 8 px at 640 wide (about 25 px at 1080p) on a head of about 40 px, plus a slight head tilt. Readable on the emulator; on a TV at distance it may be easy to miss for a child. Suggest a larger halo or a ring. |
| D-8 | Low | Stone counter still shows 1 when the last stone is spent and the stage fails | Normal, 5th miss | The fade starts with the counter at 1; the fall message follows. Cosmetic. |

Not a defect, noted: the Goliath scene accepts OK during the entry lines (a miss or the hit). In Lamb the "hit" is allowed from 2.5 s.

## Numbers against the spec

- Road: 120 s limit (clock verified), 3 loaves start, floor 1 in Shepherd/Lamb, one loaf per bump, 2 carts / 2 goats / 2 rocks.
- Brook: 5 stones, 3 scouts, 4 rocks, Normal sight 1.5 s (a "!" for about 1 s did not push; sustained sight did), Shepherd sight 3.0 s with slower scouts; Lamb no scouts.
- Goliath: 4 lanes, 4 spears per round (one every 2.5 s), laugh 4 s then glow 2 s (laughSec 6 minus glow 2); a Normal round is about 25 s, Shepherd about 29 s (misses at 16.4, 41.4, 66.4 s and 51.5, 80.6, 109.5 s). Hearts 3.
- Stage timings: 2.1 lines hold about 3.3 s with about 0.6 s gaps, road starts about 13 s after the chapter starts; a Lamb road takes about 10 s; Lamb brook with a bot about 15 s.

## Stability, performance, resources

- No stuck state or softlock found: restarts from timeout, loaves-zero, out of stones, zero-stone walk, pause > Restart, pause > Quit all recover; the 0-stone Normal path cannot loop forever without player action (the brook is replayable). Idle Shepherd Goliath keeps going (rests at 0 hearts).
- Node growth proxy: Android `dumpsys meminfo` TOTAL PSS 171.6 MB before and 172.0 MB after 25 pause > Restart stage cycles on the road (no growth). I could not read the engine's node count.
- Hitches: not measurable on a software-rendered emulator. Screen captures showed no visible stutter, but this says nothing about the TV.

## Regression: Chapter 1

Lamb run driven with a sheep-chasing bot (about 7 min): tutorial prompts ("Use the arrows to walk.", "Walk near a lost sheep...", "Press OK to throw a stone."), three Lamb nights, the Blessing picks (Still Waters / Song of Courage / Watchful Eyes), the lamb gathers, Samuel cutscene lines with "1 Samuel 16:7" and "1 Samuel 16:13", the harp (60 s), "I feel better. Stay, young David. Stay and play." and "When David played, Saul was refreshed." with "1 Sam 16:23", then the save moved from `chapters_unlocked: 1` to 2 and Chapter 2 became focusable. Line queue showed each line once, no replays, no deadlock. Chapter 1 in Shepherd and Normal was not re-run.

## Child safety

- Nothing frightening beyond the script tone: no gore, no blood, no body. Goliath is a flat figure with a mouth; the fall is narrated; soldiers have wide-eyed faces. Spears are thin lines with a telegraph band, they never show a hit effect beyond the heart count.
- The APK declares no permissions.

## Not tested

- Frame rate and hitches on real hardware, a physical remote (only `adb input keyevent`), audio loudness and music/SFX (no audio assets were audible to me on the emulator).
- Hold OK 2 s with Song of Courage across the glow; Watchful Eyes and Still Waters at Goliath; Normal road finish with exactly 1 loaf.
- Pause > Restart stage inside Goliath (stone count afterwards); sleep/wake and HOME during Chapter 2.
- Skilled human play of the spear lanes (the driver dodged with a simple rule).
- Chapter 1 in Shepherd/Normal, and the engine node count.
