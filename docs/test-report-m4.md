# Milestone 4 test (Chapter 4: The King, ending, polish)

Tester: independent. No source, data or tests changed; one read-only `git log`. Emulator `emulator-5554` only (real TV untouched). First pass was on the debug APK built from f8690f3; after the coordinator's note (HEAD 807ef1a+, data reference fix only) the APK was rebuilt once with deploy.sh and the Normal and Shepherd passes, Back tests, restarts and regression ran on that build. Input by D-pad/OK/Back keyevents only (holds with `--duration`); frames by screencap, OCR for transcripts. Evidence: `docs/evidence/m4/` (PNG 640x360, about 1.3 MB).

Automated: headless runner **6575 passed, 0 failed, 0 skipped** (the "resources still in use at exit" lines are existing exit noise); `check-data-fidelity.py` "OK: 116 lines, 34 stages, 14 cutscenes, 4 chapters; all checks passed". `aapt2 dump permissions` on `builds/shepherd-king-debug.apk` and `builds/shepherd-king-0.4.0.apk`: only the package line, no permissions. Logcat (whole device session, both builds, covers Lamb, Normal, Shepherd, restarts, Back): no SCRIPT ERROR, USER ERROR, USER WARNING or FATAL.

## Criteria

| ID | Check | Verdict | Evidence |
|---|---|---|---|
| 4.1 | Narrator Gilboa line, "How are the mighty fallen!" 2 Sam 1:19, "Jonathan, my brother. You were so kind to me." | PASS | 02, 03, 04 |
| 4.1 | 20 s quiet moment, no input needed; Back pauses it | PASS | Last line gone at about 11 s, next scene line at 32.4 s (about 21 s incl. fades); harp circle only: 05. Back in the quiet moment opens the pause menu, still paused 6 s later, Back closes it: 28, 29. |
| 4.2 | Hebron lines in order (2 Sam 2:4, 5:1-3, elders) | PASS | 06, 07, 08 |
| 4.3 | Guards' line "You'll never get in here!" 2 Sam 5:6 on entry | PASS | 09, 31 |
| 4.3 | Marked tiles flash, then rock falls, heart lost on hit | PASS (Normal) | 30 (red diamonds, rocks falling), hearts 3 to 2 to 1 to 0 on three hits |
| 4.3 | No rocks in Lamb; slower in Shepherd | PASS (Lamb); Shepherd slower rock only seen as running, speed 156 vs 260 not measured | 10 (Lamb: guards, no marks, no rocks), 42 |
| 4.3 | Hidden arrows toward the shaft | PASS | Arrows fade in near David and point along the route: 10 |
| 4.3 | Reaching shaft wins with narrator line "David took the stronghold of Zion..." 2 Sam 5:7 | PASS on HEAD (see D-1) | Lamb on f8690f3: line shown, no reference: 11. Normal on rebuilt HEAD: line with "2 Sam 5:7" (OCR). |
| 4.3 | Mercy heart for passing a guard unhit | NOT-TESTABLE on device | Blessings reset at chapter start and the maze is the first playable stage, so Mercy cannot be held there. Covered only by headless tests. |
| 4.3 | Every maze solvable | PASS | Seed 4301 maze walked start to shaft in Lamb, Normal and Shepherd; headless tests check solvability. |
| 4.3 | Normal fail restarts that stage only | PASS | Idle on a marked tile: hearts 3 to 0 in 31 s, black card "The LORD lifts up those who fall. Try again! Ps 145:14", maze restarts with the guards' line again, cutscenes not replayed: 33, 34 |
| 4.4 | David and gold-light lines (2 Sam 5:23-24) | PASS | 13, 14 |
| 4.4 | Early OK gives only "Not yet!" | PASS | 17 |
| 4.4 | Rustle then OK: army charges, Philistines flee, no gore | PASS | 15 (trees lit), 18 (army forward, Philistines running off, no blood) |
| 4.4 | Window per mode | PASS Lamb and Shepherd (lit frames about 3 s: 12.5 to 15.5 s). Normal 1.5 s only indirectly: OK 0.5 s after start works; the 1.5 s length was not timed on device. |
| 4.4 | Missed window re-rustles, never fails | PASS | Idle Lamb run: rustles at about 12.5, 23.3, 34.6 and 45.6 s, no fail |
| 4.5 | Arrow prompts; hits add dancers and musicians, bounded | PASS | 35, 36, 37: parade grows to about 18 dancers and 8 musicians, then stops; bot hit about half of the arrows |
| 4.5 | Misses never end; 60 s; hearts untouched | PASS | Idle Lamb run and Normal bot run ended at 60 s, hearts stayed 3 |
| 4.5 | Narrator "David danced before the LORD with all his might." 2 Sam 6:14; same in all modes; OK does nothing | PASS | Line seen in Lamb, Normal, Shepherd. OK pressed every second during the Normal run: no effect. |
| 4.6 | Lines and caption "Thy throne shall be established for ever." 2 Samuel 7:16 | PASS | Caption speaker is "caption", shown centred in gold light, not as God's speech; order David, Nathan, caption, David 7:18 correct |
| 4.7 | 4 villagers talked to with OK, no invented hint text | PASS | Four villagers each show a "..." bubble and a pointing arrow; no text hints. Rings mark villagers met. House opens (door lights) after the fourth. |
| 4.7 | Lines, long table, no enemies, never fails, no Blessing card after it | PASS (table content see D-3) | "Why would the king..." and "Don't be afraid... 2 Sam 9:7" shown, then table: 21. Ending follows with no card. |
| 4.8 | Narrator lines, caption Luke 1:32-33, final shot, end card, OK/Back returns to title | PASS | 22 to 26; OK on Continue and Back at the end card both return to title: 27, 39 |
| 4.8 | Nothing unlocks after | PASS | Save after finishing in Normal: `chapters_unlocked` 4, mode normal unchanged |
| Unlock | Chapter 4 only after chapter 3 | PASS on device (locked card with 3 unlocked, not focusable): 40, 41. Unlock by finishing 3 not run on device (headless only). |
| Blessings | Ch4 offers only allowed ones | PASS | Cards seen: Quick Feet, Watchful Eyes, Mighty Men, Still Waters, Mercy, Song of Courage, Smooth Stones: 12, 19, 20. Goliath's Sword never offered (not unlocked). Reset at chapter start not seen directly (maze showed no companion). |
| Blessings | None changes a story outcome or is required | PASS | Normal and Shepherd runs of 4.3 to 4.8 completed with no useful Blessing; patience and ark ignore them (source comments and headless tests). |
| Fidelity | Every Ch4 line, caption, reference in script order | PASS with differences below | OCR transcripts of all 8 stages |
| Remote-only | Complete Ch4 in Lamb, Shepherd, Normal | PASS Lamb (4.1 to end card); Normal 4.1 to end card (maze failed once and retried); Shepherd 4.3 to 4.5 only, 4.6 to 4.8 not repeated (same code as the other modes). Hard not played through Ch4. |
| Back | Pauses mid-stage, closes menus, exits only from title | PASS | Quiet moment (28), maze (43), patience (16), ending (38); Back at title previously leaves to the launcher (M3 evidence), not re-run |
| Regression | Chapters 1, 2, 3 each load (Lamb) | PASS to first stage only | 47, 48, 49 (opening lines of 1.1, 2.2 "grain and bread" 1 Sam 17:17, 3.x "They give him more than me."). Not played to the end. |
| Regression | Hard mode option; mode and unlock persistence | PASS | Selecting Hard writes `mode: hard`, restart shows it highlighted; Shepherd and Normal persisted similarly: 44. Pause menu entry "Change mode (Lamb / Shepherd / Normal / Hard)" wraps to two lines (cosmetic): 16, 46 |
| Memory | PSS over repeated restarts | PASS | Maze restarts x6: 173.7 to 175.0 MB (flat). Ark restarts x6: 180.6 to 180.1 MB (flat). Node counts not measured. |
| Safety | No gore, no permissions, offline | PASS | See above. Rocks fall on tiles with a thud cue only; Philistines run off. |

## Defects

| ID | Severity | Summary | Repro / detail |
|---|---|---|---|
| D-1 | Low, FIXED on HEAD | 4.3 win line lacked "2 Sam 5:7" | Seen on f8690f3 (11). Verified present on the rebuilt HEAD build. |
| D-2 | Low (polish) | Opening scenes are near-empty placeholders: 4.1 shows a brown-red flat sky with no messenger or David; 4.2 a flat dark screen with no crown or elders; 4.6 a flat teal screen, not night, no palace or Nathan | 4.1 (02), 4.2 (06), 4.6 (sheet frames; evidence 13 shows the stage after). Script visuals "Grey sky. A messenger runs up", "Night. David in his palace. Nathan stands before him" are not drawn. |
| D-3 | Low | Long-table scene shows a table, chairs and plates but no David, men or Mephibosheth | 21. Script: "David, his men, Mephibosheth, everyone together". |
| D-4 | Low | Luke caption sits over the star for about 5 s of the final shot; the End line shows as a subtitle bar, then again as the end card (which wraps with "King." alone on a second line) | 25, 25b, 26 |
| D-5 | Info | HUD hearts show in every cutscene (4.1, 4.2, 4.6, 4.8) | 02, 06 |
| D-6 | Info | "Change mode (Lamb / Shepherd / Normal / Hard)" button wraps to two lines (known cosmetic) | 16, 46 |

No crash, softlock or script error found. Blind walking the maze in Normal can be hit by rocks (expected); Shepherd and Lamb never end the run.

## Script fidelity differences

All 24 Chapter 4 lines, both captions and the end card appeared in script order with the right speaker styling. Differences: (1) 5:7 reference missing on f8690f3 (fixed, D-1); (2) reference dash shows as "5:1-3" and "5:23-24" in OCR but source data uses en dashes, fine; (3) visuals listed in D-2 and D-3. The "Not yet!" line shows after the gold-light line finishes (queued) when OK is pressed during the entry lines.

## Not tested

Frame rate and hitches on a real TV (emulator is software rendered), the real remote, audio (volumes saved as 0; wind, marching, slow-harp-song have no files, expected), Normal 4.4 window length (1.5 s) timing, Mercy heart in the maze, finishing chapter 3 to unlock chapter 4 on device, Hard played through Chapter 4, Shepherd 4.6 to 4.8, Chapters 1 to 3 played to the end, node counts, Blessing reset between chapters observed directly, 4-year-old usability.
