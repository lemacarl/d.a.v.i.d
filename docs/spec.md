# Shepherd King — Phase 1 Spec

Source: "Shepherd King: Game Script" (Claude Doc, rev 10, 2026-10-23). Values marked **[A]** are assumptions not in the script (balance numbers only, no story content); they need Andrew's approval. Items marked **[Q]** are blocking questions (see build-log.md).

## Global rules
- Run = one attempt at a chapter. Falling restarts the chapter's first stage with a random "David falls" line. Finishing a chapter unlocks the next.
- After each stage (except cutscenes) three Blessing cards; pick with left/right + OK. **[Q6]** whether the final stage of a chapter offers cards, and whether Blessings reset per chapter.
- Modes: **Normal** as written. **Shepherd**: enemies slower **[A: 60% speed]**, sheep wander less, David cannot fall, only tires and rests **[A: 3 s rest, then continues]**. **Lamb**: no enemies, no failure; walk, OK plays harp, gather sheep, narrator. **[Q1]** how Lamb handles Goliath/Saul/raiders.
- Hearts: **[A]** 3 max, 1 lost per hit, 1.5 s invulnerability.
- No mode or Blessing changes a story outcome.

## Stage-type catalogue
| Type | Used by |
|---|---|
| cutscene | 1.1, 1.5, 2.1, 2.3, 2.4, 3.1, 3.3, 3.4, 3.7, 4.1, 4.2, 4.6, 4.8 |
| protect-flock | 1.2 (Nights 1–3) |
| boss | 1.3 Lion, 1.4 Bear, 2.6 Goliath, 3.9 Ziklag (rescue variant) |
| rhythm | 1.6, 3.2 (with spear dodge), 4.5 (arrow prompts) |
| stealth | 2.5 brook, 3.6 En-gedi, 3.8 Saul's camp |
| survival-camp | 3.5 (3 days) |
| maze | 4.3 |
| patience | 4.4 |
| search | 4.7 |
| **delivery** (new, **[Q2]**) | 2.2 road to camp (fits no listed type) |

## Chapter 1 — The Shepherd (1 Sam 16; 17:34–37)
| Stage | Type | Win | Lose |
|---|---|---|---|
| 1.1 | cutscene | all lines shown, tutorial prompts in order | — |
| 1.2 Nights 1–3 | protect-flock | night lasts 90 s; ≥3 of 10 sheep alive at sunrise | <3 sheep alive (before 90 s) → run ends |
| 1.3 Night 4 Lion | boss | 3 hits → drops lamb, 3 more → flees (6 total) | David out of hearts **[A: lion contact = 1 heart]** |
| 1.4 Night 5 Bear | boss | bear **[A: 6 hits; 2 hits when slipped on rocks count as one throw window]** → runs away | out of hearts |
| 1.5 | cutscene | lines + gold light + caption 1 Sam 16:7 | — |
| 1.6 Harp | rhythm | 60 s elapses; always completes | never fails |

Blessings: Smooth Stones, Shepherd's Staff, Quick Feet, Song of Courage, Watchful Eyes, Still Waters, Strength of the LORD.
Modes: Lamb — no predators, sheep gather, harp free-play, all cutscenes play. Shepherd — slower predators, David tires not falls; boss still ends in flee.

## Chapter 2 — The Hero (1 Sam 17)
| Stage | Type | Win | Lose |
|---|---|---|---|
| 2.1 | cutscene | lines shown | — |
| 2.2 road | delivery | reach camp within 2 min with ≥1 loaf | all loaves lost **[A: start with 3]**; timeout **[Q3]** |
| 2.3, 2.4 | cutscene | lines + caption 1 Sam 17:37 | — |
| 2.5 brook | stealth | collect up to 5 stones; scout sight → hide behind rock until it looks away | **[A]** scout sees David unhidden >1.5 s → David pushed back, no stone loss |
| 2.6 Goliath | boss | one hit on forehead during 2 s glow ends fight, Goliath always falls | stone miss uses one stone; 0 stones → restart from 2.5 with "Go back to the brook and try again." |
| 2.7 | cutscene | slow-mo, cut-away, THUD, no body shown | — |

Stones in boss = stones collected in 2.5 (0–5). **[Q4]**: 0 stones collected, and contradiction with "restart from chapter's first stage".
Blessings: Smooth Stones, Quick Feet, Song of Courage, Watchful Eyes, Still Waters, Strength of the LORD (stun is moot vs Goliath — fall is one-stone).
Modes: Lamb — **[Q1]**. Shepherd — spear slower, stones never run out **[A]**.

## Chapter 3 — The Fugitive (1 Sam 18–30)
| Stage | Type | Win | Lose |
|---|---|---|---|
| 3.1, 3.3, 3.4, 3.7 | cutscene | lines shown; 3.3 interactive arrow watch **[Q5]**; 3.4 unlocks Goliath's Sword | — |
| 3.2 | rhythm + dodge | 3 successful dodges **[A]** → escape | **[A]** 3 spear hits → restart stage |
| 3.5 Stages 2–4 | survival-camp | ≥400 men at end of day 3 **[A: start 0, +~135/day with food/hiding]** | patrol finds camp scatters men; <400 at day 3 end → replay day 3 **[A]** |
| 3.6 En-gedi | stealth | reach Saul, press OK once ("cut a corner of his robe"); Saul is always spared | **[A]** noticed → Saul wakes, reset position (no failure) |
| 3.8 camp | stealth | take spear + jug and reach far hill on dark path | **[A]** off-path/noticed >N s → return to path start |
| 3.9 Ziklag | boss (rescue) | free all families within 3 min; every freed family adds a helper | timeout **[Q3]** or out of hearts |

Blessings: Smooth Stones, Shepherd's Staff, Quick Feet, Song of Courage, Watchful Eyes, Still Waters, Hidden in the Rock, Faithful Friend, Goliath's Sword (after 3.4), Mighty Men, Gift of Abigail (after 3.7), Mercy.
Modes: Lamb — no patrols/raiders, families gather around David. Shepherd — patrols slow, sight time doubled.

## Chapter 4 — The King (2 Sam 2; 5–7; 9)
| Stage | Type | Win | Lose |
|---|---|---|---|
| 4.1 | cutscene | 20 s quiet harp moment | — |
| 4.2 | cutscene | lines shown | — |
| 4.3 Jerusalem | maze | reach water shaft and climb it | **[A]** rock tile hit = 1 heart; out of hearts → restart stage |
| 4.4 Rephaim | patience | OK during the rustle window **[A: 1.5 s]** → army charges; early OK only triggers "Not yet!" | never fails |
| 4.5 Ark | rhythm | arrow prompts for fixed duration **[A: 60 s]**; each hit adds a dancer | never fails |
| 4.6 | cutscene | lines + caption 2 Sam 7:16 | — |
| 4.7 Lo-debar | search | talk to villagers **[A: 4]**, reach Mephibosheth's house | never fails |
| 4.8 | cutscene | ending lines, Luke 1:32–33 caption, "The End…" | — |

Blessings: Smooth Stones, Quick Feet, Song of Courage, Watchful Eyes, Still Waters, Goliath's Sword, Mighty Men, Mercy.
Modes: Lamb — Jerusalem guards drop no rocks; otherwise identical. Shepherd — rocks slower.

## Acceptance criteria (testable, examples; full IDs in test plan at milestone start)
- AC-1.2a: Night 1–3 each end at 90 s ±1 s.
- AC-1.2b: Night won iff ≥3 of 10 sheep alive at sunrise (Normal); in Shepherd/Lamb a night can never end the run.
- AC-1.3: Lion drops lamb after exactly 3 hits and flees after 3 more.
- AC-1.6: Rhythm stage lasts 60 s and ends in the Saul line regardless of misses.
- AC-2.6: In every mode, a forehead hit during the glow ends the fight with the fall cut-away; no body drawn.
- AC-3.5: Normal ends day 3 with ≥400 men only if the scatter rules hold; the Narrator line plays on success.
- AC-ALL-1: Every stage completes using D-pad, OK, Back only.
- AC-ALL-2: Back pauses mid-stage; exits only from the title.
- AC-ALL-3: No Blessing alters any scripted outcome.
- AC-ALL-4: Every dialogue line, caption and reference renders exactly as in the script.
