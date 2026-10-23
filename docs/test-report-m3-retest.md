# Milestone 3 re-test (after fix round, HEAD 7d6ebd9)

Tester: independent. Changed no source, data or tests; one read-only `git log`. Emulator `emulator-5554` only (real TV untouched). Debug APK rebuilt from HEAD with the scratchpad deploy.sh and reinstalled (md5 7dd45abc...); no foreign install seen this time. Input only by D-pad/OK/Back keyevents (holds via `--duration`); frames by screencap; OCR transcript of the Lamb run. Evidence: `docs/evidence/m3-retest/` (29 PNG, 640x360, 0.84 MB).

Automated: headless runner **3761 passed, 0 failed, 0 skipped**; `check-data-fidelity.py` "OK: 92 lines, 26 stages, 10 cutscenes, 3 chapters; all checks passed"; `aapt2 dump permissions` prints only the package line (no permissions). Logcat (cleared at start, covers Normal, Shepherd, Lamb, Ch1/2 smoke, Back tests): no SCRIPT ERROR, USER ERROR, USER WARNING or FATAL.

## Verdicts

| ID | Check | Verdict | Evidence |
|---|---|---|---|
| D-1 | En-gedi shows "cut a corner of his robe" in reach; visible flash when OK is pressed out of reach | PASS | In reach: yellow label beside Saul, OK then David's line "My lord the king! ... 1 Sam 24:6, 8-11": `d1-engedi-prompt-cut-a-corner-in-reach`, `d1-engedi-ok-in-reach-david-line`. Out of reach: no label (`d1-engedi-no-prompt-out-of-reach`); OK spam out of reach draws a ring around Saul: `d1-engedi-flash-ring-ok-out-of-reach`. |
| D-2a | Normal 3.9, idle David survives ~12+ s; raider touch costs one heart and raider runs off | PASS | Idle: first heart lost about 7 s after the timer starts (3:00 to 2:53), raiders then leave, death about 16 s in (2:44): `d2-normal-idle-raider-hit-hearts-2-at-2-53`, `d2-normal-idle-hearts-2-at-2-45-last`. Note: after the first hit the next two hearts went within about 2 s (two raiders at once), so the margin is about 16 s, not much longer. |
| D-2b | Hearts zero restarts only Ziklag, with a "David falls" line | PASS | Black card "Be strong and of good courage. One more time!", then Ziklag again at 3:00 with 415 men and the intro lines, not 3.2: `d2-hearts-zero-david-falls-line`, `d2-ziklag-restarts-only-3-00-415-men`. |
| D-2c | 3.9 timeout restart, Normal only | NOT RE-TESTED on device | Needs 3 min of survival; behaviour unchanged by the fix round and covered by headless tests; seen on device in the first M3 test. Shepherd and Lamb 3.9 show no clock (seen again). |
| D-3 | Watchful Eyes glow before patrol, raiders, sleepers | PASS (patrol, raiders); sleepers and 3.2 spear not isolated | Picked on device after 3.2 (offered, chosen). Camp: yellow ring around the patrol as it enters (`d3-watchful-eyes-camp-patrol-glow-ring`); the first M3 test's patrol had no ring. Ziklag: raiders carry a halo before entering (`d3-ziklag-raider-halo-watchful-eyes`); first M3 test had none. 3.8 sleepers already show wake rings in Normal so a Watchful Eyes glow cannot be told apart; 3.2 spear glow not seen (card is offered only after 3.2). Rest relies on headless tests. Cannot force the card through the save. |
| D-4a | Gift of Abigail: HUD food counter at 3.9 | PASS | Picked after 3.8 (offered on the first try in Normal): food icon "3" in the Ziklag HUD: `d4-gift-food-hud-3-at-3-9-start`. |
| D-4b | Food eaten at 3.9 start, heart pop when hearts rise | NOT-TESTABLE on device | Hearts are always full when 3.9 starts (3.7 food heals them in 3.8 first, Shepherd run showed 3 hearts at 3.8). The food counter stays at 3 while hearts are full and was not used by hits in-stage. Effect is thus mostly invisible in a real run (see N-1). A heart enlarged on the HUD was seen once in Shepherd 3.9 (`shepherd-ziklag-hud-food-none-no-clock`) but its cause is not established. |
| D-4c | Normal 3.5: idle David ends under 400 and restarts day 3 | PASS | Day 3 idle: 280 to 346 at 0:01, black "The LORD lifts up those who fall. Try again! Ps 145:14" (earlier loop: "Be strong ... One more time!"), day 3 restarts at 280 men, 1:30; four idle replays all failed the same way: `d4-normal-day3-idle-346-at-0-01`, `d4-normal-day3-idle-fall-line`. |
| D-4d | Day 3 replay winnable by a human-like bot | PASS | A driver that only welcomes (OK next to the cave mouth each arrival, no walking) gets 280, 325, 370, 415 at end of day and wins; it was not scattered. 400 is reachable with the welcome action alone; food/water trips were not needed or tested: `d4-normal-day3-welcome-370`, `d4-normal-day3-welcome-415-at-end`. |
| D-4e | Lamb/Shepherd camp still tops up to 400 | PASS | Lamb: "About four hundred men followed David." and HUD 400: `lamb-camp-day3-about-four-hundred`; Shepherd run entered 3.6 with 400. |
| D-6 | 3.3 arrow scene shows an OK glyph | PASS | Pulsing round OK button (ring plus gold dot) under the boy: `d6-ch3-3-arrow-ok-glyph`. |

### Regression

| Check | Verdict | Notes |
|---|---|---|
| Lamb Chapter 3 remote-only, start to finish (3.1 to 3.9, end card, summary) | PASS | OCR transcript in order: 18:7, "They give him more than me.", 18:11, "LORD, be my hiding place!", Jonathan lines (20:37-38, 20:42), Nob incl. 21:9, cave 22:1-2, follower pairs, "About four hundred men followed David.", En-gedi lines (24:6, 8-11; 24:17), Nabal, Abigail 25:32, 26:8, 26:9, 26:22, 30:6 "Shall I chase them?", gold "Pursue, for you will recover all. 1 Sam 30:8", 30:19, end card "Chapter 3 complete - The Fugitive. Next: The King.", run summary. All 32 ch3 dialogue lines found by fuzzy match except the En-gedi prompt label (Lamb frames not sampled there; seen in Normal). Two manual stretches (3.8: items and a thorn detour after my 3.8 driver skipped the items) used D-pad only. |
| Chapter 4 stays locked | PASS | Save `chapters_unlocked: 4`; card 4 drawn dim, no name, in Lamb and Normal: `lamb-ch4-locked-after-ch3`, `ch4-card-locked-after-ch3-normal`. |
| Normal Chapter 3 completed | PASS | All stages 3.1 to 3.9 incl. a Ziklag death and restart; summary: `normal-ch3-complete-run-summary`. |
| Shepherd smoke 3.5, 3.8, 3.9 | PASS | Camp day 3 to 400, 3.8 with Sword (thorn 1 cleared by OK; thorn 2 needed a detour), Ziklag won, no clock, summary and chapter select. |
| Saul spared | PASS | "I would not harm the LORD's anointed", "You are more righteous than I" in all three modes: `lamb-saul-spared-line`. |
| Back pauses, closes, exits only from title | PASS | Pause menu in Ch1 and Ch2 (Resume, Restart stage, Change mode, Quit to title), Back resumes, Quit to title works, Back at title leaves to the launcher: `back-pause-menu-ch1-normal`, `back-pause-ch2-lamb`, `ch-quit-to-title-selected`, `back-from-title-exits-to-launcher`. |
| Manifest permissions | PASS | None. |
| Chapters 1 and 2 quick smoke | PASS | Ch1 opening line, walk prompt (Normal); Ch2 Lamb road with loaves counter and hazards: `reg-ch2-lamb-road`. |
| Logcat | PASS | Clean (see above). |

## New defects

| ID | Severity | Summary | Repro |
|---|---|---|---|
| N-1 | Low | Gift of Abigail is still barely visible: food shows in the 3.9 HUD, but hearts are always full at 3.9 start, so nothing is eaten and no heart pop can be seen | Pick Gift after 3.8, start 3.9: HUD shows 3 food, hearts unchanged. Acceptable for a story-neutral Blessing; consider eating food when a raider hit costs a heart. |
| N-2 | Low | Normal 3.9 idle: after the first raider hit, two more hearts can go within about 2 s (two raiders), so idle survival is about 16 s total | Normal, 3.9, do nothing. Meets the "12+ s" target. |
| N-3 | Info | My earlier OK spam on the run summary passed through Continue and started Chapter 1 (not a defect, the Continue button simply took the next OK) | n/a |

No crash, softlock or script error. Earlier Lows D-5, D-7, D-8, D-9, D-10 were not re-examined (intentionally skipped by the fix round); D-7 is now moot since idle David fails day 3.

## Overall verdict

M3 meets its criteria on the points re-tested: the four fix-round items (En-gedi prompt and flash, Normal Ziklag fairness and stage-only restart, Watchful Eyes, camp fairness) work on device, Chapter 3 is completable in Lamb, Shepherd and Normal with the remote only, Saul is spared, Chapter 4 stays locked, Back behaves, no permissions, no logcat errors, 3761 headless tests green. Open small points: Gift of Abigail's heart effect not observable (N-1), 3.9 timeout and the Watchful Eyes effect on sleepers and the 3.2 spear were not seen on device.

## Not tested

Frame rate and hitches on a real TV (software emulator), the physical remote, audio loudness and narration (volumes saved as 0), 3.9 timeout restart in Normal on device, Watchful Eyes in 3.2 and on 3.8 sleepers, food/water trips and hiding in the camp (welcome-only bot), Faithful Friend, Song of Courage, Mercy and other individual Blessings, 4-year-old usability, Ch1/Ch2 beyond the opening.
