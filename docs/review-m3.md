# Review: Milestone 3 (Chapter 3, "The Fugitive")

Reviewer: independent (did not write the code). Scope: `git diff f448d18..HEAD` on `feature/milestone-3-chapter-3` (HEAD 40ecbc1), read-only. Sources of truth: `docs/script-source.md`, `docs/spec.md`, `docs/architecture.md`, `docs/data-schema.md`, `docs/contracts.md`, `docs/build-log.md`.

## Verdict: CHANGES REQUESTED

No Blocker. Four Major findings, all about player-facing behaviour (two Blessings that do nothing in a real run, a harsh boss-loss target that can be triggered by carried-over hearts, and a camp that is both trivially winnable by idling and unrecoverable after earlier scatters). Everything on the hard rules (story fidelity, Saul spared, no Blessing required, no Blessing or mode changing an outcome, stage/host layering) holds.

Run evidence (a `git archive` copy of HEAD under the scratchpad, so the shared project and `.godot` cache were not touched):
- `Godot --headless -s res://tests/runner.gd`: **3586 passed, 0 failed, 0 skipped** (M2 baseline: 1782). The two exit warnings (2 ObjectDB instances, 1 resource in use) were already present in the M2 review.
- `python3 -I tests/check-data-fidelity.py`: OK (91 lines, 26 stages, 10 cutscenes, 3 chapters).

Counts: Blocker 0, Major 4, Minor 11, Nit 7.

## Must-fix list (for APPROVED)

1. **R3-1** Make Watchful Eyes do something in Chapter 3 (spear glow in 3.2, raider glow in 3.9), or drop it from the Chapter 3 `blessingPool`, and add a behaviour test.
2. **R3-2** Make Gift of Abigail reachable: as data stands it is first offered after 3.8 and the next stage (3.9) never reads food. Re-point `availableAfterStage` / `blessingAfter` or let 3.9 consume it.
3. **R3-3** Give 3.9 `hearts-zero` its own `onLose` (`restart-stage`), as M2 did for 2.6, and either refill hearts on entering the boss or document that carried hearts apply.
4. **R3-4** Make Normal day 3 recoverable after earlier scatter losses (or prove it with a test), and make the camp's gathering and hiding matter (Minor R3-5 shares the same fix).

## Summary by requirement

1. **Spec and decisions.** Matches the Chapter 3 table apart from the items below.
   - 3.2: 3 dodges win, 3 spear hits restart the stage. Shepherd has a longer glow and no lose. Lamb has no spears and wins on time.
   - 3.5: day 3 in Normal replays the day when under 400 and restores the men the day began with (`_entry_followers`). Shepherd and Lamb top up. `RunState` restores scripted food too.
   - 3.6/3.8: noticed means reset to the start, never a failure. Saul is spared in every path.
   - 3.9: timeout restarts the stage, Shepherd and Lamb ignore the timer, Lamb has no raiders. Spec says Lamb "families gather around David" and that is not implemented (R3-6).
2. **Script fidelity.** I read every line, caption, reference and note in `data/dialogue/ch3.json` and `data/cutscenes/ch3.json` against `script-source.md` lines 221-289 as well as running the checker.
   - All text is verbatim, in script order, with no added or cut beat. The chapter card string matches.
   - God's words appear only once: `c3-9-lord` as a `gold-light` beat in 3.9, speaker `lord`. David's and the narrator's lines are never attributed to God.
   - The `note` fields are copies of script stage directions and are never rendered. Cue names (`field-big-stone-jonathan`, `ziklag-burned-smoke`, ...) are not displayed text.
   - No gore: Saul is only ever robe-cut and the cut is a faint dark patch. Raiders run off the field (`AWAY`) and return. Families and the sleepers are drawn upright or lying asleep (see R3-20). `StageUtil.is_body_cue` still guards visual cues.
3. **Architecture.** `grep` finds no `Audio.` or `RunState.` in `stages/`. All coupling is by signal and the host connects `spared`, `heal_requested`, `grant_requested`. Names are hyphenated and pass the checker. One class per stage type: `survival-camp` -> `StageSurvivalCamp`; Ziklag is a boss variant chosen by `StageHost._scene_key`, the same pattern as Goliath, and `architecture.md` already lists it. Ownership of the shared contracts is clean (`StageBase` owns the signals and helpers, the host owns the effects), but `contracts.md` does not describe them (R3-10).
4. **No Blessing or mode changes the outcome, none required.**
   - 3.8 thorns: `_move_david` slides around a patch that fills only half the 140 px path, so the path is passable without a Sword. `_completable_everywhere` walks it for 3 modes x 13 Blessing states (none + 12) and asserts a win, both items, zero pushbacks.
   - 3.9 ropes: `_nearest_tied(...)` runs first, so a roped family is freed by standing next to it. The Sword only adds a range shortcut. `_outcomes` (3 x 13) asserts 8 wins, 8 followers, no failure.
   - 3.6: `_saul_always_spared` runs 3 x 13 and asserts `spared == 1`, win, no failure. 3.2 `_outcomes` and the camp matrix assert identical story line ids across the 39 combinations. 3.3 `_cannot_fail` covers the modes.
   - Mercy's heart is applied in the host (`_on_spared`), so it changes hearts only. Spared is reported on a win path in 3.6, and in 3.8 only when nobody woke, and nothing reads it for story.
5. **Blessing reads (all 12).** See the table after the findings. Ten read their key somewhere in Chapter 3. Two are effectively no-ops in a real run (R3-1, R3-2). Three more have only a thin real effect (R3-7).
6. **TV performance.** Good.
   - The camp crowd is a bounded visual: `campCrowdMax` 24 `ActorFollower` nodes, `ceil(men / 20)` shown (20 figures for 400 men). Newcomers 4, men 3, brushes 4, patrol 1. The men count is a number, not nodes.
   - Companions 3, helper stone pool 4 + 2 per companion, families at most 12, raiders at most 10, sleepers at most 10, thorns at most 4. The rhythm stage creates 2 to 3 lane rects, one David and one spear once.
   - No per-frame allocation in the new `_step` paths (only value types; `modulate` and `color.a` writes). No tweens added, no signal connected after setup, `_process` stops after finish (`tick` -> `_idle` / `set_process(false)`).
   - The only smell is the negative `follower_added` (R3-9).
7. **Data.** Numbers are mostly in data. Findings R3-11 and R3-12.
8. **Assets.** No new non-code asset in the diff (only `.gd`, `.json`, `.tscn`, `.uid`). All art is code-drawn. The cues used (`harp`, `pickup`, `bump`, `bounce`, `thud`, `stone-hit`) are existing files. Every `feel(...)` key read in `stages/` exists in `balance.json`. `CREDITS.md` needs no change.
9. **Debug code, safety, offline.** No `print`, `TODO`, `breakpoint` in `stages/ actors/ screens/ autoload/`. No networking. Back is unchanged (`main.gd`), opens the pause menu mid-run. Test-only public API is listed in R3-17.
10. **Tests.** Mostly behaviour (walk a route, tap, count nodes, compare timings and lines), not only signals. Gaps in R3-13 to R3-16.

## Findings

Severity: Blocker = must fix before merge, Major = fix before merge, Minor = fix soon, Nit = optional.

### A. Correctness and spec

| ID | Sev | File:line | Issue | Suggested fix |
|---|---|---|---|---|
| R3-3 | Major | `data/stages/ch3.json:582-596`, `autoload/run-state.gd:392` (`_reset_attempt` is the only full heart refill), `autoload/run-state.gd:244-245` | 3.9 `hearts-zero` has no entry of its own, so it takes the stage default `onLose` (`chapter-start`): the whole chapter restarts at 3-2-spear (400 men, Sword, Blessings, 3.4 and 3.7 all gone). Hearts also carry between stages. In 3.2 a hit floors hearts at 1 (no `hearts-zero` there), so a child who won 3.2 with two hits enters 3.9 with 1 heart and loses the entire chapter on the first raider touch. This is the same problem M2 fixed as R2-2 for 2.6. Spec only says "out of hearts" with no target. | Add `{"cond":"hearts-zero","onLose":{"target":"restart-stage","message":"pool:david-falls"}}` (the contract already uses this shape for 2.6). Consider refilling hearts when a boss stage is entered. Add a flow test: hearts-zero in 3.9 returns to 3-9 with 8 families tied and 400 men kept. Update data-schema line 411. |
| R3-4 | Major | `data/stages/ch3.json:199-269` (`startMen 0`, `followersPerDay 135`), `stages/stage-survival-camp.gd:504-513, 541-551`, `autoload/run-state.gd:189-194` | Day 3 in Normal can fall under 400 and replays day 3 only, with the men it started with. Maximum intake per day is 135 plus meal bonuses (3 gatherers, 6 men per meal), and a scatter removes 15% of everyone present. Earlier-day scatters cannot be recovered by replaying day 3: with a deficit above roughly the bonus a day can earn, 400 is unreachable and the child loops until the pause menu restarts the chapter. No test models "scattered on days 1 and 2 then day 3". A kid's game must not dead-end. | Make the target recoverable: carry the shortfall into the next arrivals (`followersPerDay` scaled), or on a failed day 3 replay the whole `3-5-day-*` run, or after one failed replay top up as Shepherd does. Add a Normal test with a bot that is scattered every day and must still win within N replays. |
| R3-1 | Major | `stages/stage-rhythm.gd:309-351` (`_glow_sec` from data only), `stages/stage-ziklag.gd` (never sets `ActorRaider.glow`), `data/blessings.json` (`watchful-eyes`, `enemyTelegraphSec 1.0`, chapters 1-4) | **Watchful Eyes is a no-op in all of Chapter 3.** Only `stage-boss.gd`, `stage-protect-flock.gd` and `stage-goliath.gd` read `enemyTelegraphSec`. 3.2 has a spear glow that ignores it, patrols and sleepers and Saul ignore it, and Ziklag raiders never glow (`ActorRaider.glow` is never assigned). The M1 review flagged no-op Blessings. No Chapter 3 test asserts any Watchful Eyes effect. | In 3.2 add `get_feature(&"enemyTelegraphSec", 0.0)` to `glowSec` (glow starts earlier; the spear timing is unchanged). In Ziklag set `r.glow = true` for `enemyTelegraphSec` seconds before a returning raider re-enters (`_return_raider`), and for the patrol in the camp. Add a test that a Watchful Eyes run shows the warning and a plain run does not, with identical outcomes. |
| R3-2 | Major | `data/blessings.json` (`gift-of-abigail`, `availableAfterStage 3-7-abigail`), `data/stages/ch3.json` (3.7 `blessingAfter:false`, 3.8 `blessingAfter:true`, 3.9 `blessingAfter:false`), `stages/stage-ziklag.gd` (no `take_food_bonus`) | **Gift of Abigail cannot do anything in a real run.** The card needs 3-7 cleared, so the first offer is after 3.8. The next stage is 3.9, which does not call `take_food_bonus()`. Only `StageSurvivalCamp` (before 3.7 can happen) and 3.8 (before the card exists) read food. The tests inject the card directly into 3.5 and 3.8, which hides this. Even the scripted 3.7 grant only heals hearts missing in 3.8 (3.8 has no damage), so "extra food" is almost invisible. | Either let 3.9 spend food (each food restores a heart at entry, `_eat_food` as in 3.8) so the card is real, or move the card's availability to before 3.8 (e.g. offer after 3.6 with `availableAfterStage 3-6-en-gedi`). Add a flow test that picks the card through `RunState` offers and sees an effect in the next stage. Align data-schema line 527 and the spec note. |
| R3-6 | Minor | `stages/stage-ziklag.gd` (no Lamb branch beyond `raiders 0`), `docs/spec.md:64` | Spec modes line: "Lamb - no patrols/raiders, families gather around David." Raiders are removed, but families do not gather: in Lamb the child still walks to all 8 families and presses OK. Not a story change, but it is a stated mode behaviour. | Lamb: free a family automatically when David is within `sheepRescueRadius * 2` (or move gathered families toward him), data-driven under `modes.lamb.params`. Or record the simplification in the spec as an [A]. |
| R3-5 | Minor | `stages/stage-survival-camp.gd:495-500, 357-368`; `tests/test-chapter3-camp.gd`, `tests/test-chapter3-blessings.gd:140-158` | A player who does nothing wins the camp in Normal. David starts 200 px from the cave centre, inside `campShelterRadius` (210), so the patrol never sees him. Men in camp are always hidden. Groups that nobody greets join anyway after 14 s, so 3 x 135 = 405 men with no input. The matrix test uses exactly such a bot (OK spam, no movement). The scatter rule behind AC-3.5 is only reachable by leaving the shelter, and gathering and hiding are optional bonuses. | Decide intent. If the camp is meant to be a challenge, start David outside the shelter or make unwelcomed groups wait longer / join fewer. If it is meant to be easy, say so in the spec and keep it. Add a test that the passive bot ends below 400 or document that it is intended. |
| R3-7 | Minor | `stages/stage-survival-camp.gd:156`, `stages/stage-stealth.gd`, `stages/stage-play-base.gd:187-208`, `tests/test-chapter3-blessings.gd:34-44, 98-134` | Some Blessings only have a thin effect in Chapter 3. Shepherd's Staff scales the camp crowd's drawing radius (cosmetic; the test asserts only that radius) and the Ziklag helper ring. Mighty Men is spawned only in Ziklag (3.2, 3.5, 3.6 and 3.8 have no stone throwing, so it is absent there). Mercy heals via `heal`, which clamps at max hearts and hearts are almost always full in 3.6/3.8, so it is usually invisible. Quick Feet, Smooth Stones and Song of Courage matter only in Ziklag. None is a strict no-op. | Cheap wins: spawn the companion in the camp and stealth stages for display, give Mercy a visible cue when it heals or when hearts are full (a short sparkle), and make the Staff pull the newcomers closer too. At least assert in the tests that each Blessing changes something observable in Ziklag or the camp. |
| R3-8 | Minor | `data/blessings.json` (`faithful-friend`, `availableAfterStage 3-3-arrows`), `stages/stage-cutscene.gd:325`, `tests/test-chapter3-cutscene.gd:100-132` | Faithful Friend needs 3-3 cleared, so it can never be held during 3.3 (chapter restarts reset Blessings). The cutscene's arrow trail is dead code in a real run; only the hint arrow in 3.6/3.8 can show. Spec describes "Jonathan's arrow shows the safe path"; the cutscene trail is not a path. | Either drop the cutscene trail, or change availability to apply from the next chapter's replay. Keep the 3.6/3.8 hint arrow as the real effect. Record the decision in the build log. |

### B. Script fidelity

No findings. See requirement 2. Two Nits on presentation only:

| ID | Sev | File:line | Issue | Suggested fix |
|---|---|---|---|---|
| R3-20 | Nit | `actors/actor-sleeper.gd:6-22` | The sleeping soldiers are a reddish-brown horizontal rectangle (`BODY` 0.5,0.25,0.22). On a dark field this can read as a fallen figure for a young child. No text is wrong and nothing is harmed. | Use a blanket colour (blue-grey) and a "z" mark. |
| R3-21 | Nit | `data/stages/ch3.json:332-340` | `events.enter` for 3.6 holds a `visual` whose `note` repeats the script's scene direction. It is a verbatim script sentence (so fine), but it is the only stage-level `visual` note in the chapter and is never shown. | Keep, or drop to keep notes in cutscenes only. |

### C. Architecture and contracts

| ID | Sev | File:line | Issue | Suggested fix |
|---|---|---|---|---|
| R3-9 | Minor | `stages/stage-survival-camp.gd:504-510`, `stages/stage-base.gd:186`, `autoload/run-state.gd:298` | Scatter reuses `follower_added(count)` with a **negative** count. It works (`set_followers` clamps at 0) and is written in contracts.md, but a signal named "added" carrying a loss is a trap for any future listener (HUD, achievements, audio). | Add `follower_lost(count)` or rename to `followers_changed_by(delta)`; the host connects `RunState.add_followers.bind(-n)` or a new `lose_followers`. Update contracts. |
| R3-10 | Minor | `docs/contracts.md` (Chapter 3 section, lines 47-57) | The doc covers companions, `grant_requested`, the camp and cutscene keys, but not the other shared contracts this milestone added: `StageBase.spared` and `report_spared()`, `heal_requested` and `report_heal()`, `clears_obstacle(kind)`, `RunModel.next_stage_food` and the host handlers (`_on_spared` reading `heartOnSpare`, `heal_requested -> RunState.heal`). Ownership (stage emits, host applies) is only visible in code. | Add one paragraph per signal: emitter, applier, which Blessing key it serves (`heartOnSpare`, `food-start`, `actionClearsObstacles`). Also note `StageHost._scene_key` `rescue`. |
| R3-18 | Nit | `stages/stage-ziklag.gd:157-158` | `if has_method(&"spawn_companion_if_blessed"): call(...)` although the method is defined on the base class `StagePlayBase`. Dynamic dispatch hides typos. | Call `spawn_companion_if_blessed()` directly. |
| R3-19 | Nit | `autoload/run-state.gd:310-326, 350`; `stages/stage-cutscene.gd:262-268`; `docs/contracts.md:55` | The sword unlock has two sources: the 3.4 cutscene `unlock` beat (via `grant_requested(&"goliaths-sword", 1)`) and `RunState` unlocking on clearing 3-4-nob (line 350, tested in `_run_state`). It also shares `grant_requested(resource, amount)` with food, so the "resource" is sometimes an unlock id and an unknown id is silently ignored by `apply_grant`'s `match`. It works and is a defensible small contract, but it is two ways to the same state. | Pick one (keep the data beat, drop the implicit unlock) or add an `unlock_requested(id)` signal. Make `apply_grant` push a warning in debug for an unknown resource. |

### D. Data and maintainability

| ID | Sev | File:line | Issue | Suggested fix |
|---|---|---|---|---|
| R3-11 | Minor | `data/stages/ch3.json:353-366` (3.8), `:306-331` (3.6), `:236-267` (day 3) | Data keys that the code does not read, and numbers with more than one home. 3.8 `darkPath.lengthPx 2400` is ignored (the path is built from `PATH_FRACTIONS` of the field, about 2090 px), `startFoodAdd:"grant"`, `pickups.kind`, 3.6 `attackEnabled`, `darkCave`, `hidingSpots.kind`; day 3 `lose[0].min` (the stage reads `win.min`). The number 400 lives in `goalMen`, `win.min`, `lose.min` and two `topUpTo`, and `followersPerDay`/`goalMen`/patrol blocks are pasted three times. Shepherd patrol numbers are hand-multiplied copies (`speed 42 = 70 x 0.6`, `raiderSpeed 90 = 150 x 0.6`), the same smell as R2-5. | Delete dead keys (or use them: derive the path length from `lengthPx`). One `goalMen`. Add a checker that rejects unknown stage `params` keys per type, and a check that Shepherd values equal base x mode multiplier, or apply `enemy-speed` in code and drop the overrides. |
| R3-12 | Minor | `data/balance.json:82-107` (`campArrivalsPerDay`, `campMealBonusMen`, `campPatrolSightPx`, `campPatrolTurnX`, `campPatrolPauseSec`, `campCrowdMax`, `campMenPerFigure`), `stages/stage-survival-camp.gd:134-145` | The camp has two homes for the same number: the stage params read `arrivalsPerDay`, `mealBonusMen`, `patrol.sightPx`, `patrol.turnX` first and fall back to `feel`. The per-day difficulty numbers (arrivals, meal bonus, sight, pause) are stage balance, not "feel". Layout and code constants are also numbers outside data (`PATROL_LANES`, `HOMES`, `BRUSHES`, `FOOD_Y`, `FOLLOW_BASE/STEP`, `HELPER_STONES`, `THORN_AT`, `DEFAULT_*`). | Move the five difficulty keys into the day stages' `params` (one place, tunable per day) and keep only input-feel numbers (`campSelectRadius`, `campSelectWindowSec`, `campWelcomeRadius`, `campGatherWorkSec`) and display caps (`campCrowdMax`, `campMenPerFigure`) in `feel`. Leave pure geometry in code with a comment. |

### E. Performance, safety, debug

| ID | Sev | File:line | Issue | Suggested fix |
|---|---|---|---|---|
| R3-17 | Nit | `stages/stage-survival-camp.gd:516, 522, 527`, `stages/stage-ziklag.gd:233, 342`, `stages/stage-stealth.gd:412`, `stages/stage-cutscene.gd:85-95` | Public members that exist for tests ("tests and tools" comment on `summon_patrol`, "Public for tests" on `free_family`/`repel`, `exposure()`, `hint_visible()`, `arrow_x()`, `boy_x()`). Several tests also write privates (`s._per_day = 0`, `staff._crowd`, `s._stones`). Not harmful; they widen the API. | Prefix with `_`/`test_` or keep a single "test hooks" block per class. Prefer a `StageDef` param over `_per_day = 0` in tests. |
| R3-22 | Nit | `project.godot` | The diff reorders `config/icon` and `boot_splash/*` (editor re-save noise). No functional change. | Revert the reorder to keep the diff clean. |

### F. Tests

| ID | Sev | File:line | Issue | Suggested fix |
|---|---|---|---|---|
| R3-13 | Minor | `tests/test-chapter3-camp.gd`, `tests/test-chapter3-blessings.gd:140-158` | The camp outcome matrix and `_three_days` use an idle bot (tap OK, no movement), so they prove the camp is winnable but not that gathering, hiding or the scatter rule work together. Scatter recovery (R3-4) is untested. | Add a Normal scenario with a scripted gatherer and a scatter on each day; assert the final count and that day 3 is winnable after one replay. |
| R3-14 | Minor | `tests/test-chapter3-*.gd` | Per-Blessing coverage is uneven: Watchful Eyes, Quick Feet, Smooth Stones and Still Waters have no Chapter 3 assertion (Watchful Eyes is the no-op, R3-1). Gift of Abigail and Faithful Friend tests inject the card into a stage the real flow would never give it (R3-2, R3-8). | Add one table-driven test: for each of the 12 cards, run the stage that should be affected twice (with and without) and assert a measurable difference (speed, count, glow, timer), and run a flow test that gets the card through `RunState.offer_blessings()` in the stage order of the data. |
| R3-15 | Minor | `tests/test-chapter3-ziklag.gd` | No test for 3.9 `hearts-zero` (what the flow does with it) or for carried-over hearts. This hid R3-3. Ziklag stone-hit and raider-flee behaviour is covered. | Add flow tests for hearts-zero and timeout in 3.9 through `RunState`. |
| R3-16 | Nit | `tests/test-chapter3-cutscene.gd:81-98` | The 3.3 safety timeout is exercised (nobody presses OK, the stage still ends within 200 s), but the test does not assert that it happens at `arrowWaitSec` or that a late OK does not double-advance. | Assert elapsed is about `arrowFlightSec + arrowWaitSec` plus the line times, and that OK just after the timeout does not skip a line. |

## Blessing read map (Chapter 3)

| Card | Key | Read by (Chapter 3) | Real effect | Verdict |
|---|---|---|---|---|
| Smooth Stones | `stone-speed` | Ziklag player and helper throws, companion throws | Faster stones | OK, Ziklag only |
| Shepherd's Staff | `follow-distance` | Ziklag helper ring, camp crowd radius | Helpers stand closer; camp is drawing only | Thin (R3-7) |
| Quick Feet | `walk-speed` | `walk_speed()` in camp, stealth, Ziklag | Faster David | OK |
| Song of Courage | `harpFrighten*` | `play_harp_hold` -> Ziklag `_frighten` | Raiders flee 3 s | OK, Ziklag only |
| Watchful Eyes | `enemyTelegraphSec` | none | none | **No-op (R3-1)** |
| Still Waters | `heart-regen` | `RunState._enter_stage` | +1 heart per stage | OK |
| Hidden in the Rock | `notice-time` | camp patrol, 3.6, 3.8 | Longer notice | OK, tested |
| Faithful Friend | `arrowHintPerStage` | 3.6/3.8 hint arrow; 3.3 trail | Arrow for 8 s once | OK in 3.6/3.8; 3.3 dead (R3-8) |
| Goliath's Sword | `actionClearsObstacles` | 3.8 thorns, 3.9 ropes | Shortcut only | OK, never required |
| Mighty Men | `companionCount`, `companionThrowsStones` | Ziklag only | Extra stone per throw | Thin (R3-7) |
| Gift of Abigail | `food-start` | camp days, 3.8 | not reachable in order | **No-op in flow (R3-2)** |
| Mercy | `heartOnSpare` | host `_on_spared` after 3.6/3.8 | Heals, clamped | Thin (R3-7) |

## What is good

- Story-protecting design is thorough: shared contracts (`spared`, `heal_requested`, `grant_requested`, `clears_obstacle`) are the only way stages affect the run, and each one is a mode/Blessing-neutral signal.
- Bounded representation of the 400 men (24 nodes, 20 figures at 400) and pooled stones, companions and families; no per-frame allocation.
- 3.8 and 3.9 are passable with no Blessing (route and rope tests across 39 combinations).
- `RunState` restores scripted food and men on a stage restart, with tests.
- The 3.3 arrow beat has a safety timeout, ignores OK while flying, and works from a copy of the cutscene beats so the LineBook cache is not mutated.
