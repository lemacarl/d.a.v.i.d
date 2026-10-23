# Milestone plan (Phase 4)

Each milestone ends in an installable APK, versioned `0.<milestone>.<build>`. Branch `feature/milestone-<n>-<slug>`. Nothing here adds, cuts or rewords script content; all story text comes from `docs/script-source.md` via data files (`docs/data-schema.md`). Architecture: `docs/architecture.md`.

## Milestone 1: core systems + Chapter 1 (vertical slice), all three modes
Branch `feature/milestone-1-core-chapter-1`. Version 0.1.x.

**Stage types introduced:** cutscene, protect-flock, boss (chase-hits lion, charge-lanes bear), rhythm (ok-input).

**Builder units (disjoint file ownership; run in parallel after unit A lands the shared contracts):**
| Unit | Owns | Delivers |
|---|---|---|
| A: Core | `autoload/`, `model/`, `modifiers/`, `main.tscn/gd`, `tests/runner.gd`, `data/balance.json`, `data/blessings.json` | RunState, SaveData, Settings, Audio, RunModel, SaveModel, ModifierStack, mode modifiers, 7 Chapter-1 Blessings, Main with Back/pause routing, headless test runner |
| B: Screens | `screens/`, `ui/`, `theme/` | title, chapter select with mode row, blessing pick, run summary, pause menu, SafeArea, focus theme, placeholder fonts |
| C: Stages | `stages/`, `stage-scenes/`, `actors/` | StageBase, cutscene player, protect-flock, boss (lion, bear), rhythm; David, sheep, predators as placeholder shapes |
| D: Data | `data/chapters/`, `data/stages/`, `data/cutscenes/`, `data/dialogue/`, `data/recurring-lines.json` | Chapter 1 data transcribed verbatim from the script plus a fidelity test |

Unit A publishes `StageBase`/`StageDef` signatures first (small PR to the branch) so B, C and D can start.

**Risks:** Back-button routing on Android (verified on emulator, needs real TV); TV performance with many nodes (cap spawned predators and effects); Hold-OK vs tap timing; text legibility at 3 m; stone-throw auto-aim on a D-pad-only control scheme.

**Test plan (per criterion):**
- AC-1.2a night length 90 s ±1 s and AC-1.2b win only with ≥3 of 10 sheep (Normal): headless stage simulation with fake clock.
- AC-1.3 lion drops after 3 hits and flees after 3 more; bear runs away after hits (bear count is an [A] value).
- AC-1.6 rhythm lasts 60 s and never fails.
- Modes: Lamb has no predators and no failure; Shepherd cannot end a run (rest 3 s); Normal fails and restarts chapter with a random falls line.
- AC-ALL-1/2: full playthrough with D-pad, OK, Back only in all three modes; Back pauses mid-stage, closes menus, quits only from title.
- AC-ALL-3: automated test over every mode and Blessing: story lines, captions and outcomes identical.
- AC-ALL-4: data test: each line, caption and reference equals the script text.
- Persistence: chapter 2 unlock and mode choice survive restart (emulator + TV).
- Offline: aapt2 shows no permissions; no network classes in code.
- Performance: 60 fps on a real TV (emulator cannot show this).

## Milestone 2: Chapter 2
Branch `feature/milestone-2-chapter-2`. Version 0.2.x.
**New stage types:** delivery (2.2), stealth (2.5 brook), boss weak-point (2.6 Goliath, phased), cutscene features: slow motion, screen shake, cut-away (2.7).
**Files:** `stages/stage-delivery.gd`, `stages/stage-stealth.gd`, boss variant, `data/*/ch2.json`, Chapter 2 pool, tests.
**Risks:** Goliath fall must be handled by cut-away only (no body); stone carry-over between 2.5 and 2.6; scout line-of-sight on D-pad; Lamb version of Goliath (stands, glowing forehead).
**Tests:** AC-2.2 delivery (2 min, ≥1 loaf), AC-2.5 stones 0 to 5, AC-2.6 forehead hit ends fight in all modes, out-of-stones restarts at 2.5 (Normal only), AC-2.7 no body shown, script fidelity, remote-only.

## Milestone 3: Chapter 3
Branch `feature/milestone-3-chapter-3`. Version 0.3.x.
**New stage types / variants:** survival-camp (3.5), rhythm with spear dodge (3.2), stealth variants (3.6 En-gedi, 3.8 camp), boss rescue (3.9), interactive cutscene (3.3 watch-then-OK), unlock beat (3.4), grant beat (3.7).
**Blessings added:** Hidden in the Rock, Faithful Friend, Goliath's Sword, Mighty Men, Gift of Abigail, Mercy, Shepherd's Staff.
**Risks:** most complex chapter; follower AI cost on TV (cap followers on screen, instance pooling); Saul always spared in every mode and with every Blessing; Mercy rules.
**Tests:** AC-3.5 400 men by day 3, scatter rules, AC-3.6 only OK action, no attack, AC-3.9 families freed in 3 min, Blessing availability after 3.3, 3.4, 3.7, all modes.

## Milestone 4: Chapter 4, ending, polish
Branch `feature/milestone-4-chapter-4-polish`. Version 0.4.x.
**New stage types:** maze (4.3), patience (4.4), search (4.7), rhythm with arrow prompts (4.5), 20 s quiet moment (4.1), ending sequence (4.8).
**Polish:** art/audio direction (human choice needed before replacing placeholders), licences in `CREDITS.md`, performance pass, texture sizing, release signing (keystore at `~/.shepherd-king-signing`), banner and icon.
**Tests:** AC for each stage, full four-chapter run in each mode, resume after TV sleep, final reviewer pass over the whole diff.

## Per-milestone process (phases 5 to 9)
Build (builders) -> static checks and headless tests -> tester subagent (not a builder) -> reviewer subagent (not a builder or tester) -> PR with evidence -> release APK signed with the local keystore -> hand-off notes for Andrew. The next milestone does not start until Andrew has playtested and approved.
