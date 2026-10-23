# Review: Milestone 2 (Chapter 2, "The Hero")

Reviewer: independent (did not write the code). Scope: `git diff ffa66f4..HEAD` on `feature/milestone-2-chapter-2` (HEAD dbfd057), read-only. Sources of truth: `docs/script-source.md`, `docs/spec.md`, `docs/architecture.md`, `docs/data-schema.md`, `docs/contracts.md`, `docs/build-log.md`.

## Verdict: APPROVED

No Blocker and no Major findings. Minor and Nit items are listed for the fix round, and none of them blocks the M2 PR.

Run evidence (a clean `git archive` copy of HEAD under the scratchpad, so the shared `.godot` cache was not touched):
- `Godot --headless -s res://tests/runner.gd`: **1782 passed, 0 failed** (M1 baseline ffa66f4: 926 passed). The two exit warnings (2 ObjectDB instances, 1 resource in use) also appear on the M1 baseline, so they are not new.
- `python3 -I tests/check-data-fidelity.py`: OK (60 lines, 15 stages, 6 cutscenes, 2 chapters).
- Two extra probes of my own in the scratch copy only:
  - A bot that walks straight right through the Normal road wins 40 of 40 seeds, finishing with 1 loaf in 14 runs, 2 in 20 and 3 in 6.
  - A tap on the last tick of the glow window (1.9 s) still wins the fight.

Counts: Blocker 0, Major 0, Minor 10, Nit 12.

## Summary by requirement

1. **Spec and decisions.** Matches the Chapter 2 table.
   - Normal: a 2.2 timeout restarts the stage. No loaves restarts the chapter, whose restart stage is 2.2, so the player lands on the same stage. This is what data-schema line 390 specifies and `test-chapter2-flow` asserts it.
   - Goliath with no stones, or hearts at zero, goes to 2.5 with "Go back to the brook and try again." Blessings are kept and stones reset.
   - Shepherd and Lamb ignore `stones-out`, because the loss modes veto it and stones refill.
   - Lamb is the same stages with no enemies. Hazards stay in 2.2, and Lamb has no scouts, spears or shield.
2. **Script fidelity.** I compared every line, caption, reference and the chapter-level strings of `data/*/ch2.json` against `script-source.md` by eye as well as with the checker. All are verbatim, and beat order is identical. In 2.7 the order is slow-mo, stone, faces, THUD, narrator "fell on his face", army runs, "David won…", soldiers, card. No body is shown and the data contains no body cue. Nothing is attributed to God beyond the script. The `note` fields are copies of the script's stage directions and are never rendered.
3. **Architecture.** Stages never call `Audio` or `RunState` (grep is clean) and communicate only through signals. Names are hyphenated and every id passes the checker's underscore test. The one-class-per-stage-type rule is bent by design: `boss` has two classes, `StageBoss` and `StageGoliath`, chosen by `StageHost._scene_key`. `architecture.md` and `contracts.md` document this (see R2-18).
4. **No Blessing or mode changes the story outcome.** Verified in code.
   - `StageGoliath` reads no modifier on the win path. `on_action_tap` → `_launch_at(_forehead)` sets `_hit_pending` and moves to `Phase.HIT`. The stone homes on the forehead, so it always arrives. If no pooled stone is free, `_fell()` is called directly.
   - After the hit, `_spears_step` skips damage, so nothing can fail the fight. Spears only exist in phase 1 and are all gone before the laugh, so `hearts-zero` cannot fire during the laugh or glow.
   - The only modifiers read are `stone-speed` (flight time) and `enemyTelegraphSec` (spear warning). Neither changes whether a glow hit wins.
   - Strength of the LORD (`stun-time`) is never read by the Goliath stage, so it is moot as the spec requires.
   - `test-chapter2-goliath::_hit_wins_everywhere` runs mode × (no Blessing plus the 6-card Chapter 2 pool), 21 combinations. It asserts `won == 1`, `failed == 0` and zero stones spent. The same combinations are run for the delivery and stealth win paths and for the four cutscenes (same lines, same order, always won). It asserts behaviour, not only signals.
5. **TV performance.** No per-frame allocation in the new `_step` paths. Hazards (max 16), spears (4), stones (4), scouts (max 6), rocks, pickups and faces are all pooled or capped at setup. The only tweens are the old M1 harp ring. There is no particle system and no signal or tween leak. `_process` stops when a stage finishes (`_idle` → `set_process(false)`). Slow motion is restored on every exit path I could find: finish, setup, pause, `_exit_tree`, `PREDELETE` and `StageHost.clear_stage`. See R2-12 for app background.
6. **Data.** Hazards, speeds, lanes, glow and laugh times, and the feel numbers are in data. Some geometry and difficulty constants remain in code (R2-7, R2-8).
7. **Assets.** No new non-code assets. The four new audio cues reuse existing Kenney CC0 files and all eight referenced files exist. All art is code-drawn placeholder. One CREDITS line is stale (R2-17).
8. **Debug and test-only code.** No `print`, `TODO` or `breakpoint` in `stages/`, `actors/`, `screens/` or `ui/`. A few members are public mainly for tests (R2-19).
9. **Child safety and offline.** No networking, no gore. Goliath is drawn standing at all times and the cut-away shows only faces. `Engine.time_scale` is bounded to 0.05–1.0 and shake is clamped. Back opens the pause menu mid-run (`main.gd::_handle_back`); only the title screen quits.
10. **Tests.** Good on behaviour and on mode × Blessing coverage. The gaps are in the findings.

## Findings

Severity: Blocker = must fix before merge, Major = should fix before merge, Minor = fix soon, Nit = optional.

### A. Correctness and spec (Goliath, delivery, stealth, flow)

| ID | Sev | File:line | Issue | Suggested fix |
|---|---|---|---|---|
| R2-1 | Minor | `stages/stage-goliath.gd:244-245` and `screens/stage-host/stage-host.gd:150-163` | The glow hit counts when OK is released, because outside Lamb the host fires `on_action_tap` on release. A press made inside the 2 s glow but released after it is a miss and costs a stone. A tap is also swallowed while `_throw_cd` (0.35 s) is running; a miss thrown just before the glow eats the first 0.25 s of it. My late-tap probe passes, so this is an edge. It runs against "a forehead hit in the glow always wins". | Cheapest fix: in `StageGoliath`, if a miss was thrown within the last cooldown, let a glow tap bypass `_throw_cd` for the glow case only. For the release case, treat a tap released within a small grace after the glow closes as a hit (data key `feel.glowGraceSec`, 0.15), and test both. |
| R2-2 | Minor | `data/stages/ch2.json:238-243`, `stages/stage-goliath.gd` (`_contact_hit`) | `hearts-zero` in 2.6 shows the scripted "Go back to the brook and try again." even when David still has stones. The script defines that line only for running out of stones. The spec lists only the stone miss as a Goliath loss; hearts-zero here is an [A] addition. | Give `hearts-zero` its own `onLose` message (for example the `david-falls` pool) and target the stage itself (`restart-stage`). Add a flow test for the message. |
| R2-3 | Minor | `stages/stage-stealth.gd:157-173` | Spec: "hide behind a rock until the scout looks away". Scouts never look away, and sight is purely a distance check, so standing below any rock is permanently safe and nothing needs waiting for. That makes hiding a position puzzle only. Not story-affecting. | Add a look-away cycle to `ActorScout` (data: `scouts.lookSec` and `scouts.awaySec`) and require the scout to face David to see him. Or document the simplification in `spec.md` as an [A]. |
| R2-4 | Minor | `data/stages/ch2.json:128-137` | Two numbers for one fact: `pickups.count` 5 and `stoneSpots.count` 5. The code reads only `stoneSpots.count`, so editing `pickups.count` silently does nothing. `attackEnabled` is also unused. | Keep one key, delete the other, and add a check in `check-data-fidelity.py` or a test that unknown stealth params are rejected. |
| R2-5 | Minor | `data/stages/ch2.json:174` and `data/stages/ch2.json:269`; `data/balance.json` (`modes.shepherd.enemySpeedMult` 0.6) | Shepherd speeds are hand-multiplied copies of the mode value: scouts 70 → 42 and spears 320 → 192. `ModeBase` already provides `enemy-speed` (0.6). If `enemySpeedMult` is tuned, Chapter 2 silently diverges. The contract acknowledges this ("the code does not apply `enemy-speed` again"), and the test `ns._spear_speed * 0.6` bakes in the literal. | Apply `get_modifier(&"enemy-speed", base)` in the Goliath and stealth stages and delete the per-mode speed overrides. Alternatively keep them but add a data check that they equal base × `enemySpeedMult`. |
| R2-6 | Minor | `stages/stage-delivery.gd:25-26`, `tests/test-chapter2-delivery.gd:77-82` | The Normal winnability of 2.2 is not asserted. The test accepts "one outcome" when hazards are present, so a data change that made the road unwinnable would still pass. My straight-walk probe won 40 of 40, so it is fine today. | Add a test with a straight-walk bot over about 20 seeds in Normal asserting a win and at least 1 loaf. |

### B. Script fidelity (data and presentation)

| ID | Sev | File:line | Issue | Suggested fix |
|---|---|---|---|---|
| R2-9 | Minor | `data/stages/ch2.json:195-197`; `tests/check-data-fidelity.py` | `references: ["1 Samuel 17:45"]` is not verbatim: the script gives "1 Sam 17:45" for this line. It is not rendered, and the checker does not look at the stage `references` field or at cutscene `note` text, so a typo there would pass unchecked. | Remove the field (the line already carries its reference) or make it "1 Sam 17:45". Extend the checker to cover stage `references` and beat `note` text against the script. |
| R2-10 | Nit | `data/cutscenes/ch2.json:6-9` | The first 2.1 beat is a `visual` whose `note` repeats the narrator line. The script has no visual direction there. It is never displayed, so it is harmless but invents a beat. | Drop the beat, or give it a neutral cue with no note. |
| R2-11 | Nit | `docs/script-source.md:200-202` vs `data/stages/ch2.json` events | The 2.6 direction "David walks into the valley with his staff, his sling and his bag" has no visual beat or note. It is a stage direction, not text, so nothing spoken is cut. | Add a `visual` beat on `enter` (note copied from the script) when real art arrives. |

### C. TV performance and effect safety

| ID | Sev | File:line | Issue | Suggested fix |
|---|---|---|---|---|
| R2-12 | Nit | `stages/stage-cutscene.gd:353-356` | Slow motion is restored on pause, exit tree, delete and stage clear, but not on `NOTIFICATION_APPLICATION_PAUSED` or `FOCUS_OUT` (Android Home or app switch). It self-heals, because the hold is measured in real seconds (`delta / time_scale`) and the effect ends within about 3.6 s of resuming, so the clock cannot get stuck. | Add `NOTIFICATION_APPLICATION_PAUSED` and `WM_WINDOW_FOCUS_OUT` to the `restore_time_scale()` condition. One line. |
| R2-13 | Nit | `stages/stage-cutscene.gd:54-66` | Every cutscene (1.x, 3.x, 4.x as well) instantiates a stray sheep, an FX stone and 3 faces that only 1.1 and 2.7 use. It is bounded, so no leak. | Build the faces and FX stone lazily on the first cut-away cue or tutorial beat. |
| R2-14 | Nit | `data/balance.json:78-79` (`slowMotionSec` 3.0, `cutawaySec` 0.5) | `slowMotionSec` is tuned by hand to cover two 0.5 s cut-aways at scale 0.3 (about 3.3 real seconds). Raising `cutawaySec` would run the first narrator line in slow motion, because the host line queue and cut-away timers use scaled delta. | Add a comment in the contract or a test that `2 × cutawaySec / slowMotionScale ≤ slowMotionSec + 2 × slowMotionRampSec`. Verify on a device whether audio pitch follows `Engine.time_scale`. |
| R2-15 | Nit | `stages/stage-util.gd:59-68` | `is_body_cue` matches substrings: "ground" would drop a cue like "background-hills", and "dead" would drop "deadline". It silently returns false and swallows the cue. It is applied only in `StageCutscene._start_visual`, not in `_apply_visuals`. No current Chapter 2 cue is affected. | Match whole hyphen-separated words, and apply the same check in `_apply_visuals`. |

### D. Data maintainability

| ID | Sev | File:line | Issue | Suggested fix |
|---|---|---|---|---|
| R2-7 | Minor | `actors/actor-hazard.gd:28-32`, `stages/stage-delivery.gd:13-14`, `stages/stage-stealth.gd:14,21`, `stages/stage-goliath.gd:236` | Difficulty-bearing numbers live in code: hazard collision radii (36/44/56), goat span 160, road height 380, `SCOUT_Y`, the stone placement table `STONE_DEPTH` (which stones sit inside scout sight), the spear hit offset `-26.0`, and the shield bob. The brief asks that no balance numbers sit in code. | Move radii and spans to `feel` or per-hazard keys in `hazards[]`, and `STONE_DEPTH` to `stoneSpots.depths`. Pure layout constants (positions) can stay. |
| R2-8 | Minor | `docs/data-schema.md` (stage params, cutscene beats, feel list) | The new params and beats are documented only in `contracts.md`. data-schema does not describe `hazards[{kind,speed,count}]`, `win.minLoaves`, `stoneSpots`, `scouts{count,speed,sightRangePx}`, `walkSpeed`, the cutscene beats `sfx`/`shake`/`slow-motion` with `scale` and `seconds`, or the 13 new `feel` keys. | Add them to data-schema (one table row each). |
| R2-16 | Nit | `data/stages/ch2.json` (`win.windowKey`, `win.target`, `win.goal`, `win.exit`) | `windowKey` and `target` are not read: the Goliath stage reads `phase2.glowSec` directly. Several `win` keys are documentation only. | Either read `windowKey` or note in data-schema that these keys are informational. |

### E. Licensing and housekeeping

| ID | Sev | File:line | Issue | Suggested fix |
|---|---|---|---|---|
| R2-17 | Nit | `CREDITS.md:20` | The "In use" sentence lists the old Kenney files. The cues `thud`, `bump`, `pickup` and `bounce` now use `impactPlate-heavy`, `impactWood-heavy`, `impactGlass-light` and `impactMetal-light`. They are CC0, so there is no licence problem, but the note is stale. | Update the sentence. |
| R2-20 | Nit | `docs/evidence/m1-final/*` (about 60 PNGs in this range) | These M1 test screenshots arrived on the M2 branch (commit 13c6f30). Several are screenshots of the Android TV launcher UI (`launcher-apps*.png`). They are not shipped in the APK but bloat the repo and show third-party UI. | Move the evidence to the M1 PR or prune it. |

### F. Architecture and test hygiene

| ID | Sev | File:line | Issue | Suggested fix |
|---|---|---|---|---|
| R2-18 | Nit | `docs/architecture.md:275-282`, `screens/stage-host/stage-host.gd:108-112` | `boss` is now two classes selected by `variant` string matching in the host, which departs from "one class per stage type". The host's `_scene_key` is the only link; a new boss variant needs a host edit. Documented, and tested (`test-chapter2-flow::_data`). | Optionally move the variant to scene mapping into data (`stage.scene`). |
| R2-19 | Nit | `stages/stage-goliath.gd:145`, `stages/stage-cutscene.gd:11,332` | `glow_active()`, `is_slow_motion()` and the `visual_requested` signal exist mainly for tests ("tests and tools watch this"). The tests also reach into private members (`_spear_speed`, `_tele_lane`, `_faces`, `_check_bump`, `_shake_amp`). Harmless but couples the tests to internals. | Keep, but mark them `## Test hook` in the doc comment. |
| R2-21 | Nit | `stages/stage-delivery.gd`, `stages/stage-stealth.gd` | In Lamb, OK in 2.2 and 2.5 does nothing (the spec says OK plays the harp); in 2.6 it slings, which is required to win. | Call `play_harp_tap()` in `StageDelivery` and `StageStealth` when `lamb_harp_mode()`. |
| R2-22 | Minor | `tests/test-chapter2-goliath.gd` | The test gaps for the central safety claim. (a) The win test taps at the first glow tick only. (b) There is no test of a glow tap while the throw cooldown runs, nor with a miss stone in flight and all 4 pool stones busy. (c) There is no test of Song of Courage hold during the fight. (d) Nothing runs the real host path (press, release, `RunState.advance` into 2.7) for Goliath. (e) `test-chapter2-victory` resets `Engine.time_scale = 1.0` at the end of `run`, which hides a leak by a failing test. | Add tests for (a)-(d). For (e), assert `Engine.time_scale == 1.0` before the reset instead of masking it. |

## Must-fix list

None. Verdict is APPROVED. Recommended before the M2 PR, in order: R2-1 and R2-22 (they touch the headline guarantee that a glow hit always wins), R2-2, R2-9, R2-4 and R2-5. The rest can go into the M2 fix round or M4 polish.

## Items still owed (outside this diff)

- Physical-TV checks remain open (#9): frame rate with the scout sight discs, slow-motion feel, audio pitch under `Engine.time_scale`, and the real remote's OK press and release timing for R2-1.
- The M1 PR and the M1 re-review sign-off (H-4) are still tracked in `build-log.md`.
