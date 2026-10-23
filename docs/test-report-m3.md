# Milestone 3 test report (Chapter 3: The Fugitive)

Tester: independent (changed no source, data or tests). Branch `feature/milestone-3-chapter-3`, build of HEAD 40ecbc1 (debug APK built 23:50 from the working tree; no source file changed after it). One slip: I ran a read-only `git log` once; nothing else touched git.
Device: Android TV emulator `emulator-5554`, 1280x720, software rendered. Input only by `adb shell input keyevent` (D-pad, OK, BACK, `--duration` to hold). Frames: screencap at 2 to 10 per second, text read with a Vision OCR helper. Evidence: `docs/evidence/m3/*.png` (72 files, 640x360, 1.4 MB). Drivers (colour-based bots for dodge, camp, En-gedi, 3.8, Ziklag) are throwaway files in the scratchpad.
Automated: headless runner **3586 passed, 0 failed, 0 skipped**; `check-data-fidelity.py` "OK: 91 lines, 26 stages, 10 cutscenes, 3 chapters"; `aapt2 dump permissions` prints only the package line (**no permissions**). Logcat over all sessions: no SCRIPT ERROR, USER ERROR, USER WARNING, FATAL.

**Environment problem (not a game defect):** another session shares this emulator and the same package id. It uninstalled and reinstalled other builds twice (one build had a "Hard" mode, i.e. not HEAD) and killed my runs. I re-installed my APK (md5 f5705620...), verified the install time before every later run, and discarded every run that a foreign install interrupted. Results below come from the verified build only. The host was also heavily loaded (frame gaps of 100+ s), so I do not claim any timing precision beyond what is stated.

## Verdict

Chapter 3 is **completable with D-pad, OK and Back only in Lamb, Shepherd and Normal** (each completed on device, Shepherd and Normal with bots plus a few manual corrections). No crash, softlock or script error. Script lines and references match. Main findings: En-gedi gives no on-screen action prompt and no feedback when OK is pressed too far from Saul (D-1), Ziklag in Normal can kill an idle David in about 5 s and a death restarts the chapter at 3.2 (D-2), two Blessings (Watchful Eyes, Gift of Abigail) have no effect anywhere in Chapter 3 (D-3, D-4), Mercy and Still Waters are mostly invisible (D-5), the Jonathan arrow scene has no OK prompt (D-6).

## Criteria

| ID | Criterion | Verdict | Evidence |
|---|---|---|---|
| 3.1 | Women's line + 1 Sam 18:7, Saul quietly, narrator | PASS | `ac31-women-line`, `ac31-saul-quietly`, `ac31-narrator`. Dancing women not drawn (flat backdrop, D-8). "Quietly" not conveyed. |
| 3.2a | Harp notes, lane glow, D-pad dodge | PASS | Red lane glow 1.2 s (Normal), spear falls, David steps to other lane: `ac32-normal-glow-lane-spear-dodged`. |
| 3.2b | 3 dodges = escape, line "LORD, be my hiding place!" | PASS | Normal 72.6 s after start (spears at about 27, 49, 71 s): `ac32-normal-hiding-place-line`; also Shepherd, Lamb. |
| 3.2c | 3 hits restart the stage, Normal only | PASS | Hearts 3 to 0, black "The LORD lifts up those who fall. Try again! Ps 145:14", stage 3.2 restarts (not 3.1; Saul line again 18 s later): `ac32-normal-hit-heart-lost`, `ac32-normal-3-hits-fall-line`. Shepherd: no restart (hearts lost, no failure). |
| 3.2d | Lamb: no spears | PASS | Lamb 60 s, no glow; Saul line "I will pin David to the wall! 1 Sam 18:11" still shown: `ac32-lamb-saul-line-no-spear`. |
| 3.3 | Jonathan lines in order, arrow, hug, "Go in peace" | PASS with notes | Lines and refs (1 Sam 20:37-38, 20:42) in order: `ac33-*`. Arrow loops; with no OK the scene moves on after about 30 s, with OK after one throw, cannot fail. No OK prompt shown, boy, Jonathan and hug not drawn (D-6, D-8). Faithful Friend trail not seen here (card can only be picked later). |
| 3.4 | Nob lines, ref 1 Sam 21:9, Goliath's Sword unlocked | PASS | `ac34-goliaths-sword-line`; Sword card appears first in the offer after day 1: `ac34-sword-card-offered-after-day1`. |
| 3.5a | Cave narrator + 1 Sam 22:1-2, follower lines | PASS | OCR in every mode. |
| 3.5b | Send men (OK then direction) | PASS | Ring on the man, UP sends him to food, he returns carrying it: `ac35-send-man-selected-ring`, `ac35-man-returns-with-food`. |
| 3.5c | Keep camp hidden from patrols; scatter | PASS | Patrol with sight disc; David by the cave: no loss. David in the open: 270 to 229 (15 percent), again 274 to 233: `ac35-normal-patrol-sight-disc`, `ac35-normal-patrol-scatter-270-to-229`. Not tested: hiding by a brush, a man out gathering when the patrol arrives. |
| 3.5d | Welcome followers | PASS | OK next to the group: lines, men +45 (135 per day in 3 groups). |
| 3.5e | Normal: 400 by end of day 3 else day 3 restarts | PASS | Scattered to 323: fade, "Be strong and of good courage. One more time!", day 3 restarts with 270 men and 1:30. Unscattered: 405 and narrator "About four hundred men followed David.": `ac35-normal-day3-under-400-fall-line`, `ac35-normal-day3-restart-270-men`, `ac35-normal-day3-405-narrator`. Note idle David always reaches 405 (arrivals alone are 135 per day), so food, water and meals add little (D-7). |
| 3.5f | Shepherd/Lamb topUp, Lamb no patrols | PASS | Shepherd day 3 scattered to 268, ended 358 then 400 with the narrator line: `ac35-shepherd-day3-topup-400-narrator`. Lamb: no patrol in 3 days, 405: `ac35-lamb-day3-405-narrator`. |
| 3.6a | Only OK "cut a corner of his robe", no attack | PARTIAL | OK works and there is no attack, but **no prompt or label is shown** and OK pressed more than about 40 px away does nothing silently (D-1). `ac36-normal-behind-saul-no-ok-prompt`. |
| 3.6b | Noticed resets position, not failure | PASS | Walking into Saul's cone: "!" over Saul after 2.5 s, David back at start, no fade, no heart loss: `ac36-normal-saul-notices-exclamation`, `ac36-normal-reset-to-start-not-failure`. |
| 3.6c | Saul always spared, lines and refs | PASS | "This is your chance! The LORD gave him to you!", "My lord the king! ... 1 Sam 24:6, 8-11", "You are more righteous than I. 1 Sam 24:17" in Lamb, Shepherd, Normal; no robe or harm drawn: `ac36-normal-ok-cut-robe-david-line`. |
| 3.7 | Abigail lines, ref 1 Sam 25:32, extra food next stage | PASS (food invisible) | Lines OK. Food only restores missing hearts in 3.8 and there is no food display (D-4). |
| 3.8a | Dark path, sleepers, items, hill | PASS | `ac38-camp-path-overview`; wake rings visible in Normal: `ac38-normal-sleeper-wake-rings`. |
| 3.8b | Take spear and jug, climb hill | PASS | Items taken by walking close, then goal. |
| 3.8c | Lines 26:8, 26:9, 26:22 | PASS | In order, all modes: `ac38-normal-abishai-line-items-taken`. |
| 3.8d | Thorns on the path; completable without a Blessing | PASS | Thorns block the path. Without the Sword they can be walked around briefly (Lamb freely; Normal needs under 2 s off the path: my first tries were reset to the start, a careful one passed). With the Sword OK clears them: `ac38-normal-sword-cleared-thorn`. Normal off-path or near a sleeper more than 2 s: back to start (observed). |
| 3.9a | Free 8 families (stand next, OK) | PASS | Lamb, Shepherd, Normal: all three finished. Roped families are freed by standing next as well. |
| 3.9b | Raiders chase and flee when hit; each freed family adds a helper | PASS | Stones from OK send raiders off (no gore); men counter and helper ring grow per family (405 to 413): `ac39-normal-helpers-following`, `ac39-lamb-families-freed-6`. |
| 3.9c | 3 min limit Normal only; timeout restarts | PASS | Timer 3:00 to 0:00, black "Even David had hard days. Let's go again." and Ziklag restarts at 3:00 with 405 men. Timer paused at 3:00 during the intro lines. Shepherd and Lamb: no clock. |
| 3.9d | Shepherd slower raiders; Lamb none | PASS (partly by data) | Shepherd raiders visibly slower and never took a heart in my runs; speed 90 vs 150 is read from data. Lamb: no raiders. |
| 3.9e | Lines, gold light, end card, summary | PASS | Order: raiders, encouraged (1 Sam 30:6), "Shall I chase them?", gold overlay "Pursue, for you will recover all. 1 Sam 30:8", end "David got back everything. Nothing was missing. 1 Sam 30:19", card "Chapter 3 complete — The Fugitive. Next: The King.", summary: `ac39-*`. |
| 3.9f | Chapter 4 stays locked; host loads Ziklag scene | PASS | Save `chapters_unlocked: 4`, card 4 drawn locked and not focusable: `ac39-ch4-locked-after-ch3`. The Ziklag scene (families, raiders, timer) is the real scene, not the plain boss. |
| BL-1 | Pool and gating | PASS | Offers seen across about 30 screens contained only pool cards; Goliath's Sword only after 3.4; Gift only after 3.8; Faithful Friend only after 3.3; none after 3.9; Blessings reset at chapter start (summaries list only this run). |
| BL-2 | Each of 12 Blessings visible or measurable | PARTIAL | See table below. |
| BL-3 | No Blessing or mode changes a story outcome | PASS | Saul spared and Ziklag completed in all three modes; all lines identical across modes (OCR); Normal run with Sword, Quick Feet and Song picked vs Lamb without: same lines. |
| ALL-1 | Remote-only completion | PASS | Lamb, Shepherd, Normal (Normal: all stages, 3.5 day 3 failure and recovery, 3.9 timeout and death restarts all seen). |
| ALL-2 | Back pauses, closes menus, exits only from title | PASS | Pause menu (Resume, Restart stage, Change mode, Quit to title) on the cutscene, the camp (clock held at 1:26 for 5 s), Ziklag, and the Blessing screen; Back in the menu resumes; Quit to title works; Back at title leaves the app: `back-*`. |
| PERS | Unlock persistence | PASS | Save file `chapters_unlocked: 4` after Chapter 3; Chapters 1 and 2 stay selectable. |
| REG | Chapter 1 and 2 | PASS (smoke) | Lamb: Ch1 opening lines and walk prompt; Ch2 cutscene lines and the road with 3 loaves, hazards: `reg-*`. Not played to the end. |
| SAFE | Child safety | PASS | Raiders run away, Saul asleep, no body or blood; no permissions in the manifest. |
| PERF | Node growth | PASS | PSS 181.6 MB at start, 178.2, 177.6, 177.5, 177.6 MB after 10, 20, 30, 40 pause-menu stage restarts (cutscene stage only; heavier stages not repeated). |

### Blessings (12)

| Blessing | Seen on device | Notes |
|---|---|---|
| Goliath's Sword | yes | OK clears thorns (3.8). Roped families freed by standing next anyway. |
| Mighty Men | partly | Picked in the Shepherd run (summary), a helper-like figure walked with David; not isolated from the family helpers. Headless test checks the extra stone. |
| Quick Feet | indirect | Walk speed measured about 112 px/s vs 93 expected at 3.8 in a run that had picked it; not a controlled test. Headless test. |
| Song of Courage | no | Hold OK 2 s not observed to scare raiders (bot hold not captured). Headless only. |
| Faithful Friend | no (hint arrow in 3.6/3.8 not seen) | Headless only. |
| Hidden in the Rock | no | Headless only. |
| Smooth Stones, Shepherd's Staff | no | Cosmetic or speed changes; headless only (staff scales camp crowd and Ziklag helper ring). |
| Still Waters, Mercy | no | Only visible when hearts are missing (Shepherd hearts were 1 of 3 at En-gedi); not isolated (D-5). |
| Watchful Eyes | **no effect in Chapter 3** | Read only by lion/bear/Goliath stages; no Ch3 stage reads it (D-3). |
| Gift of Abigail | **no effect in practice** | D-4. |

Not observable by me: Smooth Stones, Shepherd's Staff, Hidden in the Rock, Faithful Friend, Song of Courage, Still Waters, Mercy as isolated effects.

## Defects (prioritized)

| ID | Severity | Summary | Repro and expected vs actual |
|---|---|---|---|
| D-1 | Medium | En-gedi: the "cut a corner of his robe" action is never shown, and OK out of reach gives no feedback | Any mode, 3.6: walk up behind Saul. Script says the only action offered is OK "cut a corner of his robe". No label appears; OK from about 50 px away does nothing, silently (my bot lost minutes here). Expected: a visible prompt near Saul. |
| D-2 | Medium | Normal Ziklag: raiders reach an idle David in about 3 s after the timer starts, three hits in about 3 s, and a death restarts the chapter at 3.2 (loses 3.2 to 3.8, about 8 minutes) | Normal, 3.9, do nothing after the gold light. Matches data (`onLose` chapter-start) and the spec global rule but is harsh for a young player, and OK both frees families and throws stones. A timeout only restarts Ziklag. Consider a stage restart for hearts-zero. Once playing (OK bursts, free nearby families) the stage was won in 12 s. |
| D-3 | Medium | Watchful Eyes does nothing in Chapter 3 | Offered after 3.2 to 3.8. No Chapter 3 stage reads `enemyTelegraphSec` (grep of stages). |
| D-4 | Medium | Gift of Abigail does nothing in practice, and the scripted food from 3.7 is invisible | Gift can only be offered after 3.8, whose next stage (Ziklag) never reads food; 3.7 food only heals missing hearts at 3.8, no HUD food. The script says the next stage starts with extra food. |
| D-5 | Low | Mercy and Still Waters are almost invisible | Heal clamps at max hearts; hearts are usually full. |
| D-6 | Low | 3.3 shows no "press OK" prompt; boy, Jonathan, hug not drawn | Arrow loops until OK or about 30 s. |
| D-7 | Low | 3.5 balance: idle David reaches 405 men (135 arrivals per day), so sending men and meals are optional | Normal, stay by the cave for 3 days. |
| D-8 | Low | Script visuals are mostly not drawn (women dancing, Jonathan, donkey and Abigail, smoke and burned town at Ziklag); speaker names not shown | Flat colour backdrops with subtitles, same style as M1 and M2. |
| D-9 | Low | Cosmetic: hearts HUD shown in cutscenes; run summary starts "Sheep saved: 0 · Stones thrown: N" | Chapter 3 summary. |
| D-10 | Low | 3.8 thorn without the Sword in Normal is awkward | Needs a quick off-path detour under 2 s; my timed detours were reset to the start twice. Completable but fiddly. |

## Script fidelity (Chapter 3)

Every line, caption and reference below was read on screen in script order: 18:7; 18:11; "LORD, be my hiding place!"; 20:37-38 (en dash); 20:42; Nob (21:9); 22:1-2; follower pair; "About four hundred men followed David."; men whisper; 24:6, 8-11; 24:17; Nabal narrator, Abigail, 25:32; 26:8, 26:9, 26:22; raiders, 30:6, "Shall I chase them?", gold light 30:8, 30:19; end card (em dash). Differences: (1) the script's visuals and speaker names are not drawn (D-8); (2) "quietly", "escaping", "later, calling out" are not conveyed; (3) the cave narrator line appears at the start of day 1 only; (4) the gold light is a full-screen tint with the line; (5) no "cut a corner of his robe" label (D-1); (6) the Ziklag end card appears as a subtitle bar over the field, then the run summary repeats it.

## Not tested

Frame rate and hitches on a real TV (software emulator; the host stalled for minutes at times), the physical remote, audio loudness and narration (volumes were saved as 0), hiding by a brush in camp, men out gathering during a patrol, controlled Blessing effects listed above, Lamb 3.6 and 3.8 sleepers waking (Lamb does not wake them by design), a Normal Ziklag win with exactly 3 minutes, Chapters 1 and 2 beyond the opening, 4-year-old usability.
