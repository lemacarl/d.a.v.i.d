# Milestone 3 re-review (round 2)

Reviewer: independent. Branch `feature/milestone-3-chapter-3`, HEAD `7d6ebd9`, diff `40ecbc1..HEAD`.

Run in a temp copy: `--import` clean, `tests/runner.gd` **3761 passed, 0 failed**, `check-data-fidelity.py` "92 lines, 26 stages, 10 cutscenes, 3 chapters; all checks passed". The only exit noise is Godot's usual ObjectDB/resource leak warning at shutdown.

## Status of previous findings

| ID | Status | Evidence |
|---|---|---|
| R3-1 / D-3 Watchful Eyes no-op in Ch3 | RESOLVED | Reads `enemyTelegraphSec` (1.0 in `data/blessings.json:18`). 3.2: `stage-rhythm.gd:199` adds it to `_glow_sec`, flight unchanged. 3.5: `stage-survival-camp.gd:463-467` arms the lane and sets `_patrol.warn` for the last N s before entry. 3.8: `stage-stealth.gd:673-690` sleepers glow and cannot notice until `_warn_seen >= _telegraph_sec`. 3.9: `ActorRaider.State.WARN` at start and on every return (`stage-ziklag.gd:323-373`). Tests assert behaviour, not just wiring: `_watchful_ziklag` (still, glowing, then chase; returning raider glows only with the Blessing; Ziklag still won), `_watchful_camp_patrol`, `_watchful_sleepers`, `_watchful_spear`. |
| R3-2 / D-4 Gift of Abigail unreachable | RESOLVED | Food is eaten in 3.9 (`_eat_food`, `stage-ziklag.gd:674`: `heal_requested`, HUD `food` counter). `_gift_reaches_ziklag_in_the_flow` runs the real flow: offered after 3.8, picked, then 3.9 begins with hearts 1 and heals `[2]` with `food == 3`. Camp also shows the food counter. The 3.8 `startFoodAdd` is also consumed. |
| R3-3 3.9 hearts-zero sends child to 3-2 | RESOLVED | `ch3.json` 3.9 `hearts-zero` has its own `onLose` `restart-stage` + `pool:david-falls`. `_ziklag_hearts_zero_restarts_the_stage` checks the data, that `fail_stage` returns `restart-stage` and stays on 3-9, that 400 entry men are restored, hearts refilled to max, earlier stages still cleared, three touches via `apply_hit` replay 3.9, and Shepherd/Lamb return `ignored`. `run-state.gd:178-195` restores followers and food. |
| R3-4 day-3 replay can dead-end | RESOLVED | `minMenAtDayStart` 0/140/280 in stage data, topped up in `_on_begin`. `_day_three_is_always_winnable` scatters twice on day 1 and day 2, fails day 3, restarts it with the carried men, and the next normal replay wins with >= 400. The floors rise, and floor + per-day reaches 400. |
| R3-5 idle camp win | RESOLVED | `unwelcomedJoinFraction` 0.5 (data) in `_join`. `_idle_vs_engaged_camp`: idle bot < 400 (347 by design, asserted `<= 360`), welcome bot >= 400 and wins, meals bot adds more, Shepherd and Lamb still top up to 400. |
| D-1 En-gedi prompt | RESOLVED | New `ui` line `c3-6-prompt-cut` is **verbatim** the script (`script-source.md:265`, "cut a corner of his robe"). `_build_prompt` reads it from the data event `in-reach`, with no text in code. The label shows only while in reach, and out-of-reach OK flashes a wordless ring. `_en_gedi_prompt` covers it. Saul is still always spared (`report_spared`, unchanged). |
| D-2 Ziklag idle death / restart | RESOLVED | `raiderSpeed` 150 to 110 (Shepherd 66), stun 4 s, `raiderStaggerSec` 3, a touch sends the raider away (`_contact_hit` then `_send_away`) so one raider no longer drains hearts in a row. `_raiders_are_gentler` covers it, and the hearts-zero path restarts only the stage. |
| Other tester items touched here | RESOLVED | Followers lost now use `followers_scattered` (stage-base, host `stage-host.gd:137`, `RunState.lose_followers`), and `follower_added` is never negative. `grep add_followers(-` is clean. Arrow-beat OK glyph (3.3) and HUD heart pop added with tests. |

## Checks requested

- **Script fidelity:** the only new text is `c3-6-prompt-cut` (verbatim). No spoken lines changed; no story outcome changed (Saul is spared in every mode, and Goliath is untouched).
- **Blessings and modes cannot alter outcomes:** Watchful Eyes only lengthens a warning or delays noticing. Gift of Abigail only heals. The Ziklag win is tested with and without Watchful Eyes. No stage requires a Blessing. The tester's "no Blessing required" holds: all stages are winnable with `blessings = []` in the flow tests.
- **[A] deviation documented:** yes, in `docs/spec.md` (3.9 row) and `docs/contracts.md` (Fix round). Limited to the Ch3 final boss.
- **Signal contract:** `followers_scattered(count)` is documented in `docs/contracts.md`, and the host wires it. RESOLVED.
- **Balance in data:** `arrivalsPerDay`, `mealBonusMen`, `sightPx`, `turnX`, `pauseSec` and the new fairness numbers are in stage params. The `camp*` keys were removed from `balance.json`. The code constants `DEFAULT_*` are only fallbacks, and every day's data sets them. Dead stage keys (`darkCave`, `kind`, `lengthPx`, `attackEnabled`, `startFoodAdd`, `min`) are gone from `data/stages/ch3.json`, with no code reads left.
- **Performance and leaks:** glow, warn and `reach_glow` setters redraw only on change. The prompt Label, OK glyph (3 discs) and `food` HUD counter are created once per stage, with no per-frame node creation. The HUD pulse creates one node-bound tween per gained heart (freed with the icon). No debug leftovers (no `print`, TODO or FIXME in the added lines).

## New findings

| ID | Sev | Where | Finding / fix |
|---|---|---|---|
| R3b-1 | Minor | `ui/hud.gd:787-793` | `_pulse` starts a new tween on a heart without killing a running one, so two quick heals (food then Mercy) leave two tweens fighting over `scale`. Store the tween per icon and `kill()` it first. |
| R3b-2 | Minor | `data/balance.json:85` | `spearLaneHalfWidthPx` has no reader in any `.gd` (and none at `40ecbc1`). Delete it, or use it in the lane width. |
| R3b-3 | Minor | `docs/contracts.md:55`, `docs/data-schema.md` (3.6/3.8 rows ~409-411, `startFoodAdd` 233) | Stale: contracts still lists `startMen (floor)` (now `minMenAtDayStart`), and data-schema still mentions `attackEnabled` and "startFoodAdd from grant" for stages whose keys were removed. Update the lines. |
| R3b-4 | Nit | `stages/stage-stealth.gd`, `stage-survival-camp.gd`, `stage-cutscene.gd` | Test-only accessors `prompt_visible()`, `patrol_warning()`, `ok_glyph_shown()` are public. They are harmless one-liners (state queries), so just keep them marked as test hooks. |
| R3b-5 | Nit | `actors/actor-sleeper.gd:6` | `BODY` colour changed red to blue with no note in the build log or contracts. Add a line, or revert if it was only a test of the glow contrast. |

No Blocker or Major findings.

## Verdict: APPROVED

Every previous Major and every tester Medium is resolved and covered by behavioural tests (3761 pass, fidelity check green). The Minors and Nits above are optional and can be done during M4. There is no must-fix list.
