# Hard mode

Added for GitHub issue #41 ("a 3rd level - difficult"). Andrew chose a harder difficulty mode above Normal rather than a new chapter. Modes are now Lamb / Shepherd / Normal / Hard.

Approved deviation from the script: the pause item reads `Change mode (Lamb / Shepherd / Normal / Hard)` (script: `... / Normal)`). The story is not affected: every chapter, line, caption and ending is identical in every mode, and no mode or Blessing changes a story outcome (Goliath falls to one forehead hit, Saul is spared).

## Rules
Hard is Normal plus pressure. It fails and restarts like Normal, stones do not refill, there is no extra help. Everything is data in `data/balance.json` `modes.hard`; the display name is `screens.modes.items` in `data/recurring-lines.json` (rename there).

| Key | Hard | Effect |
|---|---|---|
| `enemySpeedMult` | 1.3 | predator, lion, bear speed (`enemy-speed`) |
| `sheepWanderMult` | 1.25 | more sheep drifting (`sheep-wander`) |
| `heartsMax` | 2 | hearts at the start of a run (Normal 3) |
| `invulnerableSec` | 1.0 | invulnerability after a hit (Normal 1.5) |
| `noticeTimeMult` | 0.7 | patrols notice faster (`notice-time`) |
| `stunTimeMult` | 0.8 | boss stun shorter (`stun-time`) |

Per-stage overrides: a stage `modes.hard` block works like the others; without it Hard uses the Normal values (no stage JSON defines one yet).

## Not tuned yet (no stage reads a key for it)
- Time limits (`timeLimitSec` is read directly by the delivery stage; there is no `time-limit` key).
- Enemy spawn pressure (only the on/off `enemy-spawn-enabled` key exists).
- Rhythm hit window (`hitWindowSec` is read directly by the rhythm stage).
To tune these, a stage must read a mode multiplier through `get_modifier`; then add the key in `ModifierStack.TUNABLE_KEYS` and `ModeBase`.

## Save and UI
`RunModel.Mode.HARD` is appended last (existing values unchanged). The save accepts `"hard"`; old saves with the three older modes load unchanged. The chapter-select mode row shows four buttons in data order with the saved mode highlighted; the pause menu cycles Lamb, Shepherd, Normal, Hard.
