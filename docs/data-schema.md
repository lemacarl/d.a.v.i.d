# Shepherd King: Data Schema

Status: draft for approval. Source of truth for story text: `docs/script-source.md` (never reworded here). Balance defaults: `docs/spec.md` values marked **[A]**. File paths below are suggestions; `docs/architecture.md` owns final locations.

## 0. Conventions

- Format: JSON, UTF-8, loaded with `JSON.parse_string` into Dictionaries. Every file has `"schemaVersion": 1`.
- Names we create (ids, file names, stage types, cue ids, pool ids, modifier values that are strings) use **hyphens, never underscores**. JSON keys use camelCase.
- Ids: lines `c{chapter}-{stage}-{slug}` (e.g. `c1-3-lion-hey`); stages `{chapter}-{n}-{slug}` (e.g. `1-2-night-1`); cutscenes reuse the stage id; blessings kebab-case (`smooth-stones`); cues kebab-case.
- Text is stored exactly as in the script. A trailing script parenthetical such as `(1 Sam 17:26)` goes to `reference`, not `text`. Stage directions in parentheses ("quietly", "later, calling out") go to `direction`.
- Suggested files: `data/balance.json`, `data/recurring-lines.json`, `data/blessings.json`, `data/chapters/chN.json` (one chapter definition), `data/stages/chN.json`, `data/cutscenes/chN.json`, `data/dialogue/chN.json`.
- A **run** = one attempt at a chapter. Blessings reset when a chapter starts (human decision); Goliath's Sword is the one per-run exception (section 6).
- Rule for designers (script): no modifier key may change a story scene or outcome. The loader rejects any blessing modifier key not in the registry in section 5.

## 1. Dialogue line

File `data/dialogue/chN.json`: `{ "schemaVersion": 1, "lines": [ ...line ] }`.

| Field | Type | Req | Notes |
|---|---|---|---|
| `id` | string | yes | unique, hyphenated |
| `speaker` | enum | yes | `narrator`, `david`, `jesse`, `samuel`, `eliab`, `saul`, `goliath`, `jonathan`, `ahimelech`, `abishai`, `abigail`, `nathan`, `mephibosheth`, `servant`, `women`, `soldiers`, `elders`, `guards`, `david-men`, `new-follower`, `lord` (reserved, not used in Chapter 1), `caption` (a verse caption: on a dialogue line's `caption` field it is shown with that line's turn; as a speaker it marks verse text such as the gold-light line `c1-5-lord-heart`, no voice), `ui` (on-screen text) |
| `text` | string | yes | verbatim script text |
| `caption` | string | no | verse quote shown with a spoken line (script "Caption: ..." that directly follows a line) |
| `reference` | string | no | scripture reference shown beside the line, as written in the script |
| `direction` | string | no | stage direction, e.g. `quietly`, `singing`, `whispering`, `escaping`, `from the hill`, `laughing` |

Example:
```json
{ "id": "c1-1-david-i-will", "speaker": "david",
  "text": "I will, Father. The LORD is my shepherd too!",
  "caption": "The LORD is my shepherd; I shall not want.",
  "reference": "Psalm 23:1" }
```

## 2. Beat and cutscene

A **beat list** is an ordered array used by cutscenes and by stage `events`.

| Beat `type` | Fields | Meaning |
|---|---|---|
| `visual` | `cue`, `note` | scene/staging cue id; `note` = script stage direction verbatim |
| `narration` | `line` | narrator line id |
| `dialogue` | `line` | character line id |
| `caption` | `line` | stand-alone verse card (speaker `caption`) |
| `gold-light` | `line`, `seconds` | screen fills with soft gold for `seconds` (the stage passes it to the overlay with the signal); `line` has speaker `caption` in Chapter 1 (script "Caption:"); text + reference shown |
| `tutorial` | `line`, `until` | prompt shown until event (`david-moved`, `sheep-returned`, `stone-thrown`) |
| `interactive` | `kind`, `target`, `then` | `watch-then-ok` (3.3): player watches `target`, then presses OK |
| `quiet-moment` | `seconds`, `music` | no input (4.1) |
| `sfx` / `music` | `cue` | sound cue id. In a cutscene the `sfx` cues `slow-motion` and `screen-shake` also start the effect (optional `scale`/`amount`, `seconds`; 0 or absent = `feel` defaults) |
| `shake` | `amount?`, `seconds?` | cutscene only: bounded screen shake in px (clamped to `feel.shakeMaxPx`); runs while the following beats play |
| `slow-motion` | `scale?`, `seconds?` | cutscene only: `Engine.time_scale` eases to `scale`, holds `seconds` of real time, eases back (always restored on exit) |
| `unlock` | `id` | unlocks a Blessing (3.4) |
| `grant` | `resource`, `amount`, `appliesTo` | resource for the next stage (3.7) |
| `end-card` | `line`, `seconds?` | chapter-complete or game-complete card (sticky, held `seconds` or the stage `lineSec`) |

Cutscene: `{ id, scriptRef, chapter, skippable, beats[] }`. `skippable` is true after the first viewing (profile flag `seenCutscenes`).

Example (1.1; stage `1-1-opening` has `type: "cutscene"`, `params.cutsceneId: "1-1-opening"`):
```json
{ "id": "1-1-opening", "scriptRef": "1.1", "chapter": 1, "skippable": true, "beats": [
  { "type": "visual", "cue": "dawn-hills-bethlehem",
    "note": "Dawn over green hills. A boy sits on a rock with a harp. Sheep graze." },
  { "type": "narration", "line": "c1-1-narr-long-ago" },
  { "type": "narration", "line": "c1-1-narr-eight-brothers" },
  { "type": "dialogue", "line": "c1-1-jesse-keep-safe" },
  { "type": "dialogue", "line": "c1-1-david-i-will" },
  { "type": "tutorial", "line": "c1-1-tut-walk", "until": "david-moved" },
  { "type": "tutorial", "line": "c1-1-tut-sheep", "until": "sheep-returned" },
  { "type": "tutorial", "line": "c1-1-tut-stone", "until": "stone-thrown" } ] }
```

## 3. Stage definition

File `data/stages/chN.json`: `{ "schemaVersion": 1, "stages": [ ...stage ] }`.

| Field | Type | Notes |
|---|---|---|
| `id`, `scriptRef`, `chapter`, `title` | | `scriptRef` = script heading number ("1.2") |
| `type` | enum | `cutscene`, `protect-flock`, `boss`, `rhythm`, `stealth`, `survival-camp`, `maze`, `patience`, `search`, `delivery` (new) |
| `params` | object | Normal values; keys per type (section 3.2) |
| `modes` | object | optional `shepherd` / `lamb`, each `{ params?, win?, lose?, onLose?, events? }`. Deep-merge `params` over `params`; `win`, `lose`, `onLose` replace; `events` replace per trigger. Applied after the global mode defaults in `balance.json` |
| `events` | object | trigger name to beat list (lines for Normal; same in all modes unless `modes.*.events` replaces) |
| `win` | object | `{ "kind": ..., ... }` (3.1) |
| `lose` | array | lose conditions `{ "cond": ..., args, "onLose"? }`; empty = never fails |
| `onLose` | object | default `{ "target", "message", "keepBlessings" }`; target is `chapter-start` (chapter's `restartStage`), `restart-stage`, or `stage:{id}`; `message` is `pool:{id}` or `line:{id}`; `keepBlessings` defaults false for `chapter-start`, true otherwise |
| `blessingAfter` | bool | three cards after the stage clears (never after cutscenes; false on the last playable stage of a chapter, because Blessings reset) |
| `next` | string/null | next stage id; null = chapter complete |
| `references` | array | stage-level scripture refs not tied to a line |

### 3.1 Win kinds and lose conditions

| `win.kind` | Args |
|---|---|
| `cutscene-end` | none |
| `survive-time` | `seconds`, `minAlive` (sheep) |
| `hits-total` | none in Chapter 1: the hit count is the stage's `params.hitsToFlee` (one source) |
| `timing-hit` | `target`, `windowKey` (param holding window seconds) |
| `reach-exit` | `exit`, `carry` (state keys passed to next stage) |
| `reach-goal` | `goal`, `requireItems` |
| `interact-once` | `target` |
| `count-reached` | `key`, `target` |
| `count-at-end` | `key`, `min`, `topUpTo?` |
| `all-freed` | `key` |
| `duration-elapsed` | `seconds` |
| `gather-sheep` | `count` (Lamb replacements) |

| `lose.cond` | Meaning |
|---|---|
| `hearts-zero` | David out of hearts (Normal only) |
| `sheep-below-min` | alive sheep < `min` |
| `loaves-zero` | basket empty |
| `stones-out` | no stones left, fight not won |
| `timeout` | `timeLimitSec` elapsed |
| `spear-hits` | `count` hits |
| `men-below-goal-at-end` | `key`, `min` |

### 3.2 Params by type (Normal defaults; global defaults in `balance.json`)

| Type | Params |
|---|---|
| `cutscene` | `cutsceneId`, `lineSec` (default line hold) |
| `protect-flock` | `durationSec` (the one night length), `sheepTotal`, `maxPredators`, `predators[{kind,spawnIntervalSec,speed}]`, `sheepDriftToThreat`. The sheep minimum lives in `win.minAlive` only (also the mid-night lose threshold). No `eventLimits`: every scripted event line plays every time. |
| `boss` | `variant` (`chase-hits` lion, `charge-lanes` bear, `weak-point` Goliath, `rescue` Ziklag: `timeLimitSec`, `families`, `raiders`, `raiderSpeed`, `raiderStunSec` (or `raiderReturnSec`), `raiderStaggerSec`, `helperPerFamily`, `helperSpeed`, `obstacles`); lion/bear: `hitsToDrop` (lion), `hitsToFlee` (the total hit count; `win` is just `{kind: hits-total}`), `stunSec`, `contactDamage`; lion: `circleRadius`, `circleSpeed`; bear: `slipDoubleHit`, `lanes`, `windupSec`, `restSec`, `chargeSpeed`, `slipSec`, `rockEvery`; events `drop` (hitsToDrop reached), `flee` (hitsToFlee reached), `win`; Goliath (weak-point, 2.6): `walkSpeed`, `stones{source,refillOnMiss}` (`source: carry` = the stones carried from 2.5), `phase1{shieldBearer,spearLanes,spearSpeed,spearIntervalSec}` (`spearLanes 0` = no spears), `phase2{laughSec,glowSec}` (laugh then a glow of `glowSec` at the end of `laughSec`; OK in the glow always wins, a press that began in the glow counts even when released after it; an OK press otherwise is a miss), `win.windowKey`/`win.target` are informational; the stage holds phase timers until the host line queue has shown the `enter` lines and the first laugh (`StageBase.on_lines_drained`); rescue: `timeLimitSec`, `families`, `raiders`, `helperPerFamily` |
| `rhythm` | `durationSec` (one source; no `win.seconds`), `inputs` (`ok` or `arrows`), `notesPerMinute`, `noteSpeed`, `hitWindowSec`, `missEndsStage:false`, `spearDodge{count,glowSec,lanes}` (3.2), `hitAddsDancers` (4.5) |
| `stealth` | `actors`, `hidingSpots{kind,count}`, `sightSec`, `onSeen` (`pushback`/`reset-position`/`return-to-path-start`), `actions` (3.6 `ok: cut-corner-of-robe`: the stage's only action; there is no attack key), `pickups{kind}` (2.5) or `pickups{items}` (3.8), `darkPath{widthPx}`, `sleepers`, `obstacles`; 3.6 events: `enter`, `in-reach` (the `ui` prompt line shown above Saul while David can cut), `spare`, `win`; collect variant (2.5): `walkSpeed`, `stoneSpots.count` (the one source of the number of stones to collect; `pickups` only names the kind), `scouts{count,speed,sightRangePx}` (a mode block writes the mode speed, the stage does not apply `enemy-speed` again) |
| `survival-camp` | `day`, `dayDurationSec`, `minMenAtDayStart` (the day starts with at least this many men; topped up, so a day-3 replay is winnable), `goalMen`, `followersPerDay`, `arrivalsPerDay`, `mealBonusMen`, `unwelcomedJoinFraction` (share of a group's men that join when nobody welcomes them; no meal bonus), `patrol{enabled,intervalSec,scatterFraction,noticeSec,speed,sightPx,turnX,pauseSec}`, `foodWaterTasks`, `foodSpots`, `waterSpots`, `hidingSpots{count}` |
| `maze` | `grid{w,h}`, `rockTiles`, `rockDropEnabled`, `rockSpeed`, `hintArrows`, `goal` |
| `patience` | `rustleDelaySecRange`, `rustleWindowSec`, `earlyLine` |
| `search` | `villagers`, `hints`, `goal` |
| `delivery` | `timeLimitSec` (Normal only), `loavesStart`, `loavesFloor`, `lossPerDrop`, `halfwayAt`, `walkSpeed`, `hazards[{kind,speed,count}]` (kinds `cart`, `goat`, `rolling-rock`); `win.minLoaves` |

### 3.3 Global defaults and modes (`data/balance.json`)

```json
{ "schemaVersion": 1,
  "hearts": { "max": 3, "lossPerHit": 1, "invulnerableSec": 1.5 },
  "input": { "harpHoldSec": 2.0, "tapIsMainAction": true },
  "feel": { "walkSpeed": 320, "stoneSpeed": 900, "throwCooldownSec": 0.35, "stoneHitRadius": 40, "...": "see data/balance.json" },
  "modes": {
    "normal":   { "enemySpeedMult": 1.0, "sheepWanderMult": 1.0, "canFall": true,  "enemiesEnabled": true,  "loseEnabled": true,  "timeLimitEnabled": true,  "stonesRefill": false },
    "shepherd": { "enemySpeedMult": 0.6, "sheepWanderMult": 0.5, "canFall": false, "enemiesEnabled": true,  "loseEnabled": false, "timeLimitEnabled": false, "stonesRefill": true, "tiredRestSec": 3.0 },
    "lamb":     { "enemySpeedMult": 0.0, "sheepWanderMult": 0.5, "canFall": false, "enemiesEnabled": false, "loseEnabled": false, "timeLimitEnabled": false, "stonesRefill": true } },
  "profile": { "lambCompletionUnlocksNextChapter": true } }
```

`feel` holds the shared feel numbers the stages read (walk and stone speed, throw cooldown, hit, catch, rescue and gather radii, sheep speed, margins, tutorial distances, gold-light hold and fade). A stage may override `walkSpeed`, `stoneSpeed` and `throwCooldownSec` in its `params`. Code holds no fallback copies; a test asserts every key the code reads is present. Per-stage numbers (lion `circleSpeed`, bear `chargeSpeed`, harp `noteSpeed`) live in that stage's `params`.

Other data files read by the UI: `recurring-lines.json` `screens.modes.items` (`[{id, name}]` in cycle order; ids are the save keys; the names are the ones in the scripted pause item), `screens.run-summary.continue` (the Continue label: a non-script UI string, approved as an operational label), and `data/audio.json` (below).

### 3.4 Audio (`data/audio.json`)

```json
{ "schemaVersion": 1,
  "buses": { "Music": { "baseDb": -10.0 }, "Narration": { "baseDb": 0.0 }, "Sfx": { "baseDb": -6.0 } },
  "duckDb": -9.0,
  "narration": { "dir": "res://audio/narration/", "ext": "ogg", "bus": "Narration" },
  "cues": { "music-main": { "paths": ["res://audio/music/a-new-town.mp3"], "bus": "Music", "loop": true },
            "stone-hit": { "paths": ["res://audio/effects/impactWood-medium-000.ogg", "..."], "bus": "Sfx", "loop": false } } }
```
Cues used by code: `music-main`, `sheep-baa`, `stone-throw`, `stone-hit`, `hurt`, `harp`, `win`. A cue may list several `paths` (one is picked at random); `.ogg` and `.mp3` both load. Narration for a line id plays `<dir><line-id>.<ext>` when that file exists (see `docs/narration-sheet-ch1.md`).

Mode semantics (human decisions):
- **Normal**: as written. Timeouts (`timeLimitSec`) restart the stage.
- **Shepherd**: enemies at `enemySpeedMult`; David never falls: `hearts-zero` becomes a `tiredRestSec` rest, then play continues. `loseEnabled:false` ignores every `lose` entry; thresholds inside `win` are relaxed in the stage `modes.shepherd` block. `timeLimitEnabled:false` ignores `timeLimitSec` (stage durations such as `durationSec` still apply). Goliath: stones refill.
- **Lamb**: same stages, hostile actors, hazards and attacks removed (`enemiesEnabled:false`), no failure, no time limit, stones refill. Story actors (Goliath, Saul, Jesse, etc.) and all cutscenes remain, non-hostile.

## 4. Recurring-lines pools and chapter definition

File `data/recurring-lines.json`:
```json
{ "schemaVersion": 1,
  "pools": {
    "david-falls": { "pick": "random-no-immediate-repeat", "lines": [
      { "id": "rec-falls-1", "speaker": "ui", "text": "The LORD lifts up those who fall. Try again!", "reference": "Ps 145:14" },
      { "id": "rec-falls-2", "speaker": "ui", "text": "Be strong and of good courage. One more time!" },
      { "id": "rec-falls-3", "speaker": "ui", "text": "Even David had hard days. Let's go again." } ] },
    "encouragement-low-hearts": { "pick": "random-no-immediate-repeat", "lines": [
      { "id": "rec-enc-1", "speaker": "ui", "text": "Don't give up, David!" },
      { "id": "rec-enc-2", "speaker": "ui", "text": "The LORD is with you." },
      { "id": "rec-enc-3", "speaker": "ui", "text": "You can do it. Stay close to the flock." } ] },
    "stage-cleared": { "pick": "random-no-immediate-repeat", "lines": [
      { "id": "rec-clear-1", "speaker": "ui", "text": "Well done! Pick a blessing." },
      { "id": "rec-clear-2", "speaker": "ui", "text": "Safe for now. What will help you next?" } ] } },
  "screens": {
    "run-summary": { "template": "Sheep saved: {sheepSaved} · Stones thrown: {stonesThrown} · Blessings: {blessings}" },
    "pause-menu": { "items": ["Resume", "Restart stage", "Change mode (Lamb / Shepherd / Normal)", "Quit to title"] },
    "title": { "text": "Shepherd King — Press OK to begin.", "decoration": "bouncing-sheep-beside-OK" } } }
```

Chapter definition (`data/chapters/chN.json`):

| Field | Notes |
|---|---|
| `id`, `number`, `title`, `davidIs`, `loop`, `boss`, `scripture`, `mainAction` | descriptive, verbatim from the script table |
| `stages` | ordered stage ids (also the `next` chain) |
| `restartStage` | first playable stage; target of `chapter-start` (opening cutscene is not replayed) |
| `resetBlessingsOnStart` | true |
| `blessingPool` | blessing ids that can appear in this chapter |
| `unlock` | `{ "default": bool, "requires": { "chapterComplete": n }, "anyMode": true }` |
| `completeCard` | line id, speaker `ui` |

## 5. Blessing card

File `data/blessings.json`: `{ "schemaVersion": 1, "offerCount": 3, "cards": [ ...card ] }`.

| Field | Notes |
|---|---|
| `id`, `name`, `effect` (one-line text), `chapters[]`, `reference` | verbatim from the script |
| `modifiers` | `{ key: value }`, keys only from the registry below |
| `availableAfterStage` | optional stage id; card enters the pool only once that stage is cleared in the run |
| `unlock` | optional `{ stage, scope }` (Goliath's Sword) |
| `modeRelevance` | `{normal, shepherd, lamb}` bools; in Lamb mode relevant cards are offered first, other eligible cards fill up to three |

Modifier registry (suffix `Mult` = multiplied, `Add` = added, `Sec` = seconds, bare = bool/count):

| Key | Type | Default effect value | Read by |
|---|---|---|---|
| `stoneSpeedMult` | float | 1.25 | sling projectile |
| `followRadiusMult` | float | 0.7 **[A]** | sheep/follower follow logic |
| `walkSpeedMult` | float | 1.2 | David movement |
| `harpFrightenEnabled` | bool | true | harp (hold OK `harpHoldSec`) |
| `harpFrightenRadiusPx` | int | 400 **[A]** | harp |
| `harpFrightenSec` | float | 3.0 **[A]** | harp |
| `enemyTelegraphSec` | float | 1.0 **[A]** | enemy spawner |
| `heartsRestoreOnStageStart` | int | 1 | stage start |
| `bossStunBonusSec` | float | 1.0 | boss hit handler |
| `patrolNoticeTimeMult` | float | 1.5 **[A]** | stealth/camp patrols |
| `arrowHintPerStage` | int | 1 | Jonathan arrow hint |
| `actionClearsObstacles` | array | `["thorns","ropes"]` | OK action |
| `companionCount` | int | 1 | follower that throws stones |
| `companionThrowsStones` | bool | true | follower |
| `startFoodAdd` | int | 3 **[A]** | stage start |
| `heartOnSpare` | int | 1 | spare event |

Example (unlocked card with an availability rule):
```json
{ "id": "goliaths-sword", "name": "Goliath's Sword",
  "effect": "Unlocked at Nob; OK also clears thorns and ropes",
  "chapters": [3, 4], "reference": "1 Sam 21:9",
  "modifiers": { "actionClearsObstacles": ["thorns", "ropes"] },
  "unlock": { "stage": "3-4-nob", "scope": "run" },
  "modeRelevance": { "normal": true, "shepherd": true, "lamb": true } }
```

All 13 cards are listed in section 8.

## 6. Chapter 1 as data

### 6.1 Chapter definition
```json
{ "schemaVersion": 1, "id": "ch1", "number": 1, "title": "The Shepherd",
  "davidIs": "A boy keeping his father's sheep", "loop": "Protect the flock through 5 nights",
  "boss": "The Lion, then the Bear", "scripture": "1 Sam 16; 17:34–37",
  "mainAction": "OK slings a stone at the nearest predator.",
  "stages": ["1-1-opening","1-2-night-1","1-2-night-2","1-2-night-3","1-3-lion","1-4-bear","1-5-samuel","1-6-harp"],
  "restartStage": "1-2-night-1", "resetBlessingsOnStart": true,
  "blessingPool": ["smooth-stones","shepherds-staff","quick-feet","song-of-courage","watchful-eyes","still-waters","strength-of-the-lord"],
  "unlock": { "default": true }, "completeCard": "c1-6-card-complete" }
```

### 6.2 Dialogue (`data/dialogue/ch1.json`, every Chapter 1 line verbatim)
```json
{ "schemaVersion": 1, "lines": [
  { "id": "c1-1-narr-long-ago", "speaker": "narrator", "text": "Long ago, in Bethlehem, lived a shepherd boy named David." },
  { "id": "c1-1-narr-eight-brothers", "speaker": "narrator", "text": "He was the youngest of eight brothers." },
  { "id": "c1-1-jesse-keep-safe", "speaker": "jesse", "text": "David! Keep the sheep safe tonight. Bring them all home." },
  { "id": "c1-1-david-i-will", "speaker": "david", "text": "I will, Father. The LORD is my shepherd too!", "caption": "The LORD is my shepherd; I shall not want.", "reference": "Psalm 23:1" },
  { "id": "c1-1-tut-walk", "speaker": "ui", "text": "Use the arrows to walk." },
  { "id": "c1-1-tut-sheep", "speaker": "ui", "text": "Walk near a lost sheep to bring it back." },
  { "id": "c1-1-tut-stone", "speaker": "ui", "text": "Press OK to throw a stone." },
  { "id": "c1-2-n1-start", "speaker": "narrator", "text": "The sun goes down. Something moves in the grass." },
  { "id": "c1-2-n2-start", "speaker": "david", "text": "Stay close, little ones. I'm here." },
  { "id": "c1-2-n3-start", "speaker": "narrator", "text": "The wolves are hungry tonight. Be brave, David." },
  { "id": "c1-2-sheep-saved", "speaker": "david", "text": "Got you! Back to the flock." },
  { "id": "c1-2-sunrise", "speaker": "narrator", "text": "Morning comes. The sheep are safe." },
  { "id": "c1-3-lion-hey", "speaker": "david", "text": "Hey! That lamb belongs to my father!" },
  { "id": "c1-3-lion-narr", "speaker": "narrator", "text": "David chased the lion and saved the lamb from its mouth.", "reference": "1 Samuel 17:35" },
  { "id": "c1-4-bear-help", "speaker": "david", "text": "LORD, help me again!" },
  { "id": "c1-4-bear-narr", "speaker": "narrator", "text": "The lion and the bear could not beat the LORD's shepherd." },
  { "id": "c1-5-samuel-not-this-one", "speaker": "samuel", "text": "Is this one the king? No. Not this one either." },
  { "id": "c1-5-narr-eliab", "speaker": "narrator", "text": "Samuel looked at tall Eliab, but God had not chosen him." },
  { "id": "c1-5-lord-heart", "speaker": "caption", "text": "The LORD looketh on the heart.", "reference": "1 Samuel 16:7" },
  { "id": "c1-5-samuel-all-sons", "speaker": "samuel", "text": "Are these all your sons, Jesse?" },
  { "id": "c1-5-jesse-youngest", "speaker": "jesse", "text": "There is the youngest. He is out with the sheep." },
  { "id": "c1-5-samuel-this-one", "speaker": "samuel", "text": "This is the one." },
  { "id": "c1-5-narr-spirit", "speaker": "narrator", "text": "The Spirit of the LORD came upon David from that day on.", "reference": "1 Sam 16:13" },
  { "id": "c1-6-narr-troubled", "speaker": "narrator", "text": "King Saul was troubled, and his heart was dark." },
  { "id": "c1-6-servant-harp", "speaker": "servant", "text": "Find a boy who plays the harp well. Jesse's son David!" },
  { "id": "c1-6-saul-better", "speaker": "saul", "text": "I feel better. Stay, young David. Stay and play.", "direction": "at the end" },
  { "id": "c1-6-narr-refreshed", "speaker": "narrator", "text": "When David played, Saul was refreshed.", "reference": "1 Sam 16:23" },
  { "id": "c1-6-card-complete", "speaker": "ui", "text": "Chapter 1 complete — The Shepherd. Next: The Hero." } ] }
```

### 6.3 Cutscenes (`data/cutscenes/ch1.json`: 1.1 shown in section 2; 1.5 here)
```json
{ "id": "1-5-samuel", "scriptRef": "1.5", "chapter": 1, "skippable": true, "beats": [
  { "type": "visual", "cue": "jesse-house-seven-brothers", "note": "Inside Jesse's house. Seven brothers stand in a row. Samuel walks past each one." },
  { "type": "dialogue", "line": "c1-5-samuel-not-this-one" },
  { "type": "narration", "line": "c1-5-narr-eliab" },
  { "type": "gold-light", "line": "c1-5-lord-heart", "seconds": 4 },
  { "type": "dialogue", "line": "c1-5-samuel-all-sons" },
  { "type": "dialogue", "line": "c1-5-jesse-youngest" },
  { "type": "visual", "cue": "david-runs-in-with-staff", "note": "David runs in, out of breath, holding his staff." },
  { "type": "dialogue", "line": "c1-5-samuel-this-one" },
  { "type": "visual", "cue": "samuel-pours-oil-gold-sparkles", "note": "Samuel pours oil on David's head. Gold sparkles." },
  { "type": "narration", "line": "c1-5-narr-spirit" } ] }
```

### 6.4 Stage list (`data/stages/ch1.json`)

Night 1, full:
```json
{ "id": "1-2-night-1", "scriptRef": "1.2", "chapter": 1, "type": "protect-flock", "title": "Night 1",
  "params": {
    "durationSec": 90, "sheepTotal": 10,
    "predators": [ { "kind": "jackal", "spawnIntervalSec": 12, "speed": 90 },
                   { "kind": "wolf",   "spawnIntervalSec": 18, "speed": 100 } ],
    "sheepDriftToThreat": 0.3,
    "maxPredators": 6 },
  "events": {
    "start": [ { "type": "visual", "cue": "dusk-field-dark-edges", "note": "Wolves and jackals creep in from the dark edges" },
               { "type": "narration", "line": "c1-2-n1-start" } ],
    "sheep-saved": [ { "type": "dialogue", "line": "c1-2-sheep-saved" } ],
    "win": [ { "type": "narration", "line": "c1-2-sunrise" } ] },
  "win": { "kind": "survive-time", "minAlive": 3 },
  "lose": [ { "cond": "sheep-below-min" }, { "cond": "hearts-zero" } ],
  "onLose": { "target": "chapter-start", "message": "pool:david-falls" },
  "modes": {
    "shepherd": { "params": { "predators": [ { "kind": "jackal", "spawnIntervalSec": 12, "speed": 54 }, { "kind": "wolf", "spawnIntervalSec": 18, "speed": 60 } ] },
                  "win": { "kind": "survive-time", "minAlive": 0 } },
    "lamb":     { "params": { "predators": [] },
                  "win": { "kind": "survive-time", "minAlive": 0 } } },
  "blessingAfter": true, "next": "1-2-night-2" }
```
(Shepherd speeds are Normal x0.6 written out; the engine may instead apply `enemySpeedMult` and omit the override. Pick one in implementation, not both.)

Lion boss, full:
```json
{ "id": "1-3-lion", "scriptRef": "1.3", "chapter": 1, "type": "boss", "title": "Night 4: the Lion",
  "references": ["1 Samuel 17:35"],
  "params": { "variant": "chase-hits", "hitsToDrop": 3, "hitsToFlee": 6, "stunSec": 1.0,
              "circleRadius": 300, "circleSpeed": 280,
              "contactDamage": 1, "movement": "circle-holding-lamb", "stones": { "refillOnMiss": true } },
  "events": {
    "enter": [ { "type": "visual", "cue": "lion-grabs-lamb", "note": "A roar. The other animals scatter. A lion grabs a lamb and runs." },
               { "type": "dialogue", "line": "c1-3-lion-hey" } ],
    "drop": [ { "type": "visual", "cue": "lion-drops-lamb", "note": "Three stone hits make it drop the lamb" } ],
    "flee": [ { "type": "visual", "cue": "lion-flees-hills", "note": "three more send it running into the hills" } ],
    "win": [ { "type": "narration", "line": "c1-3-lion-narr" } ] },
  "win": { "kind": "hits-total" },
  "lose": [ { "cond": "hearts-zero" } ],
  "onLose": { "target": "chapter-start", "message": "pool:david-falls" },
  "modes": {
    "shepherd": { },
    "lamb": { "params": { "movement": "absent", "lostLambOnGround": true },
              "win": { "kind": "gather-sheep", "count": 1 } } },
  "blessingAfter": true, "next": "1-4-bear" }
```

Remaining Chapter 1 stages (same shape; full values in section 7):

| Stage id | Type | next | Notes |
|---|---|---|---|
| `1-1-opening` | cutscene | `1-2-night-1` | section 2 |
| `1-2-night-2` | protect-flock | `1-2-night-3` | like Night 1; spawn intervals 9 / 14 s; event `start` = `c1-2-n2-start` |
| `1-2-night-3` | protect-flock | `1-3-lion` | spawn intervals 7 / 11 s; event `start` = `c1-2-n3-start` |
| `1-4-bear` | boss | `1-5-samuel` | variant `charge-lanes`, `hitsToFlee` 6, `slipDoubleHit` true; enter `c1-4-bear-help`; win `c1-4-bear-narr` |
| `1-5-samuel` | cutscene | `1-6-harp` | section 6.3 |
| `1-6-harp` | rhythm | null | `durationSec` 60, `inputs` ok, `missEndsStage` false; enter `c1-6-narr-troubled`, `c1-6-servant-harp`; win `c1-6-saul-better`, `c1-6-narr-refreshed`, end-card `c1-6-card-complete`; `lose` []; `blessingAfter` false |

## 7. Stage-id and script mapping (all 34 stage entries, 1.1 to 4.8)

Notation: `p.` = `params`, `w` = `win`, `l` = `lose`, `onLose` default is `chapter-start` + `pool:david-falls` unless noted. "S" = Shepherd, "L" = Lamb overrides on top of the global mode defaults. Blessing (B) = `blessingAfter`. Cutscene stages: type `cutscene`, `params.cutsceneId` = stage id, `lose` [], B false.

### Chapter 1
| Script | Stage id | Type | Normal | S | L |
|---|---|---|---|---|---|
| 1.1 | `1-1-opening` | cutscene | beats incl. `tutorial` x3 | same | same |
| 1.2 N1 | `1-2-night-1` | protect-flock | section 6.4; B true | slower predators, `minAlive` 0 | `predators` [], `minAlive` 0 |
| 1.2 N2 | `1-2-night-2` | protect-flock | as N1, faster spawns; B true | as N1 | as N1 |
| 1.2 N3 | `1-2-night-3` | protect-flock | as N1, fastest; B true | as N1 | as N1 |
| 1.3 | `1-3-lion` | boss | section 6.4; B true | `enemySpeedMult` 0.6; hearts-zero = rest | `gather-sheep` 1 |
| 1.4 | `1-4-bear` | boss | w hits-total (`hitsToFlee` 6); l hearts-zero | slower charge; rest | `gather-sheep` 3 [A] |
| 1.5 | `1-5-samuel` | cutscene | section 6.3 | same | same |
| 1.6 | `1-6-harp` | rhythm | duration-elapsed 60 | same | same |

### Chapter 2 (restartStage `2-2-road`)
| Script | Stage id | Type | Normal | S | L |
|---|---|---|---|---|---|
| 2.1 | `2-1-errand` | cutscene | lines `c2-1-*` | same | same |
| 2.2 | `2-2-road` | delivery | p.timeLimitSec 120, loavesStart 3 [A], loavesFloor 1, lossPerDrop 1, hazards [cart, goat, rolling-rock], halfwayAt 0.5; events halfway `c2-2-halfway`, win `c2-2-arrival`; w reach-goal `camp` with loaves >= 1; l loaves-zero, timeout; both `onLose` target `restart-stage` (timeout) / `chapter-start` (loaves); B true | time limit ignored; loaves never below floor | same as S, hazards remain (not enemies) |
| 2.3 | `2-3-challenge` | cutscene | lines `c2-3-*` | same | same |
| 2.4 | `2-4-saul` | cutscene | lines `c2-4-*`; caption on David line | same | same |
| 2.5 | `2-5-brook` | stealth | p.pickups {kind stones}, stoneSpots {count 5}, scouts on far bank, hidingSpots rocks, sightSec 1.5 [A], onSeen `pushback`; events each-stone `c2-5-each-stone`, stones-complete `c2-5-five`; w reach-exit carry {stones: collected}; l []; B true | scout speed x0.6, sightSec x2 | scouts removed |
| 2.6 | `2-6-goliath` | boss | variant weak-point; p.stones {source carry, refillOnMiss false}, phase1 {shieldBearer, spearLanes 4, spearSpeed 320 [A]}, phase2 {laughSec 6 [A], glowSec 2}; w timing-hit `goliath-forehead` / `phase2.glowSec`; l stones-out `onLose` {target `stage:2-5-brook`, message `line:c2-6-go-back`, keepBlessings true}, hearts-zero; events enter `c2-6-*`, laugh `c2-6-laugh`, miss `c2-6-miss`; B false | spear x0.6; stones refill (`refillOnMiss` true); never lose | spear/shield removed; Goliath stands and laughs; stones refill; forehead hit still ends fight |
| 2.7 | `2-7-victory` | cutscene | beats: slow-mo cue, soldiers-eyes cue, `sfx` thud + screen shake, `c2-7-*`, end-card `c2-7-card-complete` | same | same |

### Chapter 3 (restartStage `3-2-spear`)
| Script | Stage id | Type | Normal | S | L |
|---|---|---|---|---|---|
| 3.1 | `3-1-song` | cutscene | `c3-1-*` | same | same |
| 3.2 | `3-2-spear` | rhythm | p.durationSec 90 [A], inputs ok, spearDodge {count 3, glowSec 1.2 [A], lanes [left,right]}; events spear-1 `c3-2-saul`, win `c3-2-david`; w count-reached dodges 3; l spear-hits 3, `onLose` `restart-stage`; B true | glowSec x1.67; no lose | spearDodge removed; w duration-elapsed 60 |
| 3.3 | `3-3-arrows` | cutscene | beats include `interactive` kind `watch-then-ok` target `arrow-landing`; B false | same | same |
| 3.4 | `3-4-nob` | cutscene | beats end with `unlock` id `goliaths-sword` | same | same |
| 3.5 d1 | `3-5-day-1` | survival-camp | p.day 1, dayDurationSec 90 [A], minMenAtDayStart 0 / 140 / 280 (days 1 / 2 / 3) [A], goalMen 400, followersPerDay 135 [A], unwelcomedJoinFraction 0.5 [A], patrol {intervalSec 25, scatterFraction 0.15, noticeSec 4} [A], foodWaterTasks true; events enter `c3-5-narr-cave`, new-follower `c3-5-follower` + `c3-5-david-come`; w duration-elapsed; B true | patrol slower, noticeSec x2 | patrol removed |
| 3.5 d2 | `3-5-day-2` | survival-camp | p.day 2; as d1; B true | same | same |
| 3.5 d3 | `3-5-day-3` | survival-camp | p.day 3; w count-at-end men min 400; l men-below-goal-at-end, `onLose` `restart-stage`; win event `c3-5-day3-end`; B true | w topUpTo 400 | w topUpTo 400 |
| 3.6 | `3-6-en-gedi` | stealth | p.actions {ok: cut-corner-of-robe}, attackEnabled false, onSeen `reset-position`; events enter `c3-6-men`, win `c3-6-david`, `c3-6-saul`; w interact-once `saul-robe`; spare event on win; l []; B true | notice time x2 | no sight |
| 3.7 | `3-7-abigail` | cutscene | beats end with `grant` resource food amount 3 [A] appliesTo next-stage | same | same |
| 3.8 | `3-8-camp` | stealth | p.pickups [spear, water-jug], darkPath, sleepers, noticeSec 2 [A], onSeen `return-to-path-start`, startFoodAdd from grant; events `c3-8-abishai`, `c3-8-david-no`, win `c3-8-david-hill`; w reach-goal `far-hill` requireItems both; spare event on pickup; l []; B true | notice x2 | soldiers do not wake |
| 3.9 | `3-9-ziklag` | boss | variant rescue; p.timeLimitSec 180, families 8 [A], raiders 6 [A], helperPerFamily 1; enter-events `c3-9-*`, win `c3-9-end`, end-card `c3-9-card-complete`; w all-freed `families`; l timeout (`restart-stage`), hearts-zero (`restart-stage`, `pool:david-falls`; a deliberate [A] for the last boss, not `chapter-start`); raiders: `raiderSpeed` 110, `raiderStunSec` 4, `raiderStaggerSec` 3; B false | no time limit, raiders x0.6, rest | raiders removed |

### Chapter 4 (restartStage `4-3-jerusalem`)
| Script | Stage id | Type | Normal | S | L |
|---|---|---|---|---|---|
| 4.1 | `4-1-sad-news` | cutscene | beats include `quiet-moment` seconds 20, music `slow-harp-song` | same | same |
| 4.2 | `4-2-hebron` | cutscene | `c4-2-*` | same | same |
| 4.3 | `4-3-jerusalem` | maze | p.grid 15x11 [A], rockTiles marked, rockDropEnabled true, hintArrows true, goal `water-shaft`; references [2 Sam 5:8]; events enter `c4-3-guards`, win `c4-3-narr`; w reach-goal `water-shaft`; l hearts-zero, `onLose` `restart-stage`; spare event when passing a guard unhit; B true | rockSpeed x0.6 | rockDropEnabled false |
| 4.4 | `4-4-rephaim` | patience | p.rustleDelaySecRange [8,14] [A], rustleWindowSec 1.5, earlyLine `c4-4-not-yet`; events enter `c4-4-david`, `c4-4-lord`; w timing-hit `rustle` / rustleWindowSec; l []; B true | window 3.0 | same as S |
| 4.5 | `4-5-ark` | rhythm | p.durationSec 60, inputs arrows, hitAddsDancers true, missEndsStage false; event enter `c4-5-narr`; w duration-elapsed 60; l []; B true | same | same |
| 4.6 | `4-6-promise` | cutscene | `c4-6-*`; gold-light `c4-6-lord` | same | same |
| 4.7 | `4-7-lo-debar` | search | p.villagers 4 [A], hints chain, goal `mephibosheth-house`; events enter `c4-7-david-ask`, win `c4-7-meph`, `c4-7-david-table`, visual `long-table-palace`; w reach-goal; l []; B false | same | same |
| 4.8 | `4-8-ending` | cutscene | `c4-8-*`; final visual cue `bethlehem-night-star`; end-card `c4-8-card-end`; next null | same | same |

### Dialogue inventory, chapters 2 to 4 (verbatim; speaker | text | reference)

| Id | Speaker | Text | Ref |
|---|---|---|---|
| `c2-1-narr` | narrator | The Philistines came to fight Israel in the valley of Elah. | |
| `c2-1-jesse` | jesse | Take this grain and bread to your brothers at the camp. | 1 Sam 17:17 |
| `c2-1-david` | david | Yes, Father! I'll run the whole way. | |
| `c2-2-halfway` | david | I can see the tents! | |
| `c2-2-arrival` | narrator | David heard a giant shouting across the valley. | |
| `c2-3-goliath` | goliath | Send me a man! Who will fight me? | |
| `c2-3-david` | david | Who is he, to defy the armies of the living God? | 1 Sam 17:26 |
| `c2-3-eliab` | eliab | Why are you here? Go back to your little sheep! | |
| `c2-3-david-2` | david | What have I done now? I only asked a question. | |
| `c2-4-saul` | saul | You are only a boy. He is a warrior. | |
| `c2-4-david` | david | I fought a lion and a bear. God saved me then. | caption "The LORD that delivered me out of the paw of the lion… he will deliver me." / 1 Samuel 17:37 |
| `c2-4-david-armor` | david | I can't walk in this! I'll take it off. | |
| `c2-5-each-stone` | david | Smooth and round. Just right. | |
| `c2-5-five` | narrator | He chose five smooth stones from the brook. | 1 Sam 17:40 |
| `c2-6-goliath-dog` | goliath | Am I a dog, that you come with sticks? | 1 Sam 17:43 |
| `c2-6-david-sword` | david | You come with a sword and a spear. | |
| `c2-6-david-name` | david | I come in the name of the LORD of hosts! | 1 Sam 17:45 |
| `c2-6-laugh` | goliath | Ha! Ha! A shepherd boy! (direction: laughing) | |
| `c2-6-miss` | david | Again! The battle is the LORD's. | |
| `c2-6-go-back` | ui | Go back to the brook and try again. | |
| `c2-7-narr-fall` | narrator | The stone hit Goliath in the forehead, and he fell on his face. | 1 Sam 17:49 |
| `c2-7-narr-ran` | narrator | David won, and the Philistines ran away. | |
| `c2-7-soldiers` | soldiers | David! David! | |
| `c2-7-card-complete` | ui | Chapter 2 complete — The Hero. Next: The Fugitive. | |
| `c3-1-women` | women | Saul has slain his thousands, and David his ten thousands! (direction: singing) | 1 Sam 18:7 |
| `c3-1-saul` | saul | They give him more than me. (direction: quietly) | |
| `c3-1-narr` | narrator | From that day, Saul watched David with jealous eyes. | |
| `c3-2-saul` | saul | I will pin David to the wall! | 1 Sam 18:11 |
| `c3-2-david` | david | LORD, be my hiding place! (direction: escaping) | |
| `c3-3-jonathan-1` | jonathan | If I shoot past the boy, you must run away. | |
| `c3-3-jonathan-2` | jonathan | Is not the arrow beyond you? Hurry! | 1 Sam 20:37–38 |
| `c3-3-jonathan-3` | jonathan | Go in peace. The LORD is between you and me forever. | 1 Sam 20:42 |
| `c3-4-david-hungry` | david | I am hungry. Do you have any bread? | |
| `c3-4-ahimelech-1` | ahimelech | Only the holy bread. Take it. | |
| `c3-4-ahimelech-2` | ahimelech | And here is Goliath's sword, wrapped in cloth. | 1 Sam 21:9 |
| `c3-4-david-sword` | david | There is none like it. Give it to me. | |
| `c3-5-narr-cave` | narrator | David hid in a cave. People in trouble came to join him. | 1 Sam 22:1–2 |
| `c3-5-follower` | new-follower | I'm in debt and in trouble. Can I follow you? | |
| `c3-5-david-come` | david | Come. We will trust the LORD together. | |
| `c3-5-day3-end` | narrator | About four hundred men followed David. | |
| `c3-6-men` | david-men | This is your chance! The LORD gave him to you! (direction: whispering) | |
| `c3-6-david` | david | My lord the king! I would not harm the LORD's anointed. (direction: later, calling out) | 1 Sam 24:6, 8–11 |
| `c3-6-saul` | saul | You are more righteous than I. | 1 Sam 24:17 |
| `c3-7-narr` | narrator | A rich man named Nabal was rude to David's men. | |
| `c3-7-abigail` | abigail | Please, my lord, don't take revenge. Take this gift. | |
| `c3-7-david` | david | Blessed be the LORD who sent you today. | 1 Sam 25:32 |
| `c3-8-abishai` | abishai | Let me strike him once with the spear! | 1 Sam 26:8 |
| `c3-8-david-no` | david | No. Do not destroy him. | 1 Sam 26:9 |
| `c3-8-david-hill` | david | Here is the king's spear! Send someone to get it. (direction: from the hill) | 1 Sam 26:22 |
| `c3-9-narr-raiders` | narrator | Raiders had taken all the wives and children away. | |
| `c3-9-narr-encouraged` | narrator | But David encouraged himself in the LORD his God. | 1 Sam 30:6 |
| `c3-9-david-chase` | david | Shall I chase them? | |
| `c3-9-lord` | lord | Pursue, for you will recover all. | 1 Sam 30:8 |
| `c3-9-end` | narrator | David got back everything. Nothing was missing. (direction: end) | 1 Sam 30:19 |
| `c3-9-card-complete` | ui | Chapter 3 complete — The Fugitive. Next: The King. | |
| `c4-1-narr` | narrator | Saul and Jonathan died in a battle on Mount Gilboa. | |
| `c4-1-david-1` | david | How are the mighty fallen! | 2 Sam 1:19 |
| `c4-1-david-2` | david | Jonathan, my brother. You were so kind to me. | |
| `c4-2-narr-1` | narrator | The men of Judah anointed David king at Hebron. | 2 Sam 2:4 |
| `c4-2-narr-2` | narrator | Later, all the tribes of Israel came too. | 2 Sam 5:1–3 |
| `c4-2-elders` | elders | We are your bone and your flesh. You will lead us. | |
| `c4-3-guards` | guards | You'll never get in here! | 2 Sam 5:6 |
| `c4-3-narr` | narrator | David took the stronghold of Zion. It became the city of David. | 2 Sam 5:7 |
| `c4-4-david` | david | LORD, shall I go up against them? | |
| `c4-4-lord` | lord | When you hear marching in the treetops, then go. | 2 Sam 5:23–24 |
| `c4-4-not-yet` | david-men | Not yet! | |
| `c4-5-narr` | narrator | David danced before the LORD with all his might. | 2 Sam 6:14 |
| `c4-6-david-1` | david | I live in a house of cedar, but God's ark lives in a tent. | |
| `c4-6-nathan` | nathan | The LORD says: I will build a house for you. | |
| `c4-6-lord` | caption | Thy throne shall be established for ever. | 2 Samuel 7:16 |
| `c4-6-david-2` | david | Who am I, O Lord GOD, that you have brought me this far? | 2 Sam 7:18 |
| `c4-7-david-ask` | david | Is anyone left from Saul's family? I want to be kind for Jonathan's sake. | 2 Sam 9:1 |
| `c4-7-meph` | mephibosheth | Why would the king be kind to someone like me? | |
| `c4-7-david-table` | david | Don't be afraid. You will always eat at my table. | 2 Sam 9:7 |
| `c4-8-narr-1` | narrator | The shepherd boy became the shepherd of all Israel. | |
| `c4-8-narr-2` | narrator | And God kept His promise to David. | |
| `c4-8-narr-3` | narrator | From David's family, God sent a King whose kingdom never ends. | |
| `c4-8-caption` | caption | The Lord God shall give unto him the throne of his father David… and of his kingdom there shall be no end. | Luke 1:32–33 |
| `c4-8-card-end` | ui | The End. Thank you for playing Shepherd King. | |

Chapter pools and unlocks: ch2 `unlock.requires.chapterComplete` 1; ch3 requires 2; ch4 requires 3; `anyMode` true. Pools: ch2 `[smooth-stones, quick-feet, song-of-courage, watchful-eyes, still-waters, strength-of-the-lord]`; ch3 `[smooth-stones, shepherds-staff, quick-feet, song-of-courage, watchful-eyes, still-waters, hidden-in-the-rock, faithful-friend, goliaths-sword, mighty-men, gift-of-abigail, mercy]`; ch4 `[smooth-stones, quick-feet, song-of-courage, watchful-eyes, still-waters, goliaths-sword, mighty-men, mercy]`.

## 8. Blessing mapping (13 cards in the script; Normal / Shepherd / Lamb)

| Card id | Name | Chapters | Reference | Modifier keys (value) | Availability | Normal | S | L relevant |
|---|---|---|---|---|---|---|---|---|
| `smooth-stones` | Smooth Stones | 1-4 | 1 Sam 17:40 | `stoneSpeedMult` 1.25 | pool | yes | yes | no (no enemies; kept for Lamb free-throw only) |
| `shepherds-staff` | Shepherd's Staff | 1, 3 | Ps 23:4 | `followRadiusMult` 0.7 | pool | yes | yes | yes |
| `quick-feet` | Quick Feet | 1-4 | Ps 18:33 | `walkSpeedMult` 1.2 | pool | yes | yes | yes |
| `song-of-courage` | Song of Courage | 1-4 | 1 Sam 16:23 | `harpFrightenEnabled` true, `harpFrightenRadiusPx` 400, `harpFrightenSec` 3.0 (hold OK `input.harpHoldSec` 2) | pool | yes | yes | no |
| `watchful-eyes` | Watchful Eyes | 1-4 | Ps 121:4 | `enemyTelegraphSec` 1.0 | pool | yes | yes | no |
| `still-waters` | Still Waters | 1-4 | Ps 23:2 | `heartsRestoreOnStageStart` 1 | pool | yes | yes | no |
| `strength-of-the-lord` | Strength of the LORD | 1, 2 | 1 Sam 17:37 | `bossStunBonusSec` 1.0 | pool | yes (moot vs Goliath) | yes | no |
| `hidden-in-the-rock` | Hidden in the Rock | 3 | Ps 27:5 | `patrolNoticeTimeMult` 1.5 | pool | yes | yes | no |
| `faithful-friend` | Faithful Friend | 3 | 1 Sam 20:42 | `arrowHintPerStage` 1 | `availableAfterStage` `3-3-arrows` [A] | yes | yes | yes |
| `goliaths-sword` | Goliath's Sword | 3, 4 | 1 Sam 21:9 | `actionClearsObstacles` [thorns, ropes] | `unlock` {stage `3-4-nob`, scope run} | yes | yes | yes |
| `mighty-men` | Mighty Men | 3, 4 | 2 Sam 23:8 | `companionCount` 1, `companionThrowsStones` true | pool | yes | yes | no (throws only matter vs enemies; follows David) |
| `gift-of-abigail` | Gift of Abigail | 3 | 1 Sam 25:18 | `startFoodAdd` 3 | `availableAfterStage` `3-7-abigail` [A] | yes | yes | yes |
| `mercy` | Mercy | 3, 4 | 1 Sam 24:10 | `heartOnSpare` 1 | pool | yes | yes | no |

Card `name`, `effect`, `chapters`, `reference` copy the script table verbatim; card `effect` strings are exactly the script's one-line effect.

Engine handling per mode: Normal applies all modifiers; Shepherd applies all (cards may still be offered, hearts are "energy"); Lamb prefers `modeRelevance` cards and fills the offer up to three with the other eligible cards, and never applies enemy-only keys. Blessings never alter `events`, `win` of cutscenes, or any scripted outcome.

## 9. Stage type by mode matrix

| Type | Normal | Shepherd | Lamb |
|---|---|---|---|
| cutscene | `beats` | same | same |
| protect-flock | `win.minAlive` 3, `lose` active | slower `predators`, `win.minAlive` 0 | `predators` [], `win.minAlive` 0 |
| boss (lion, bear) | `hitsToDrop/Flee`, hearts lose | speed x0.6, rest on hearts-zero | boss absent, `gather-sheep` win |
| boss (weak-point, Goliath) | `stones` carry, `lose` stones-out to `stage:2-5-brook` | `refillOnMiss` true, no lose | spear/shield off, same forehead `timing-hit` win |
| boss (rescue, Ziklag) | `timeLimitSec` 180, timeout restarts stage | limit ignored, slower raiders | raiders removed, `all-freed` win |
| rhythm | `missEndsStage` false everywhere; 3.2 adds `spearDodge` + `spear-hits` lose | longer `glowSec` | `spearDodge` removed, `duration-elapsed` |
| stealth | `onSeen` per stage | longer `sightSec`, slower scouts/patrols | no sight |
| survival-camp | day 3 `count-at-end` 400, scatter | patrol slower, `topUpTo` 400 | patrol removed, `topUpTo` 400 |
| maze | `rockDropEnabled`, hearts lose | `rockSpeed` x0.6 | `rockDropEnabled` false |
| patience | `rustleWindowSec` 1.5 | 3.0 | 3.0 |
| search | no enemies | same | same |
| delivery | `timeLimitSec` 120, `loavesFloor` 1, loaves-zero lose | limit ignored, loaves never below floor | same as S |

## 10. Script ambiguities and assumptions found

Review note (orchestrator): speaker `lord` is reserved for lines the script has God speak in gold light (3.9 "Pursue...", 4.4 "When you hear marching..."). The script labels 1.5 ("The LORD looketh on the heart.") and 4.6 ("Thy throne...") as captions, so they use speaker `caption` (still shown with gold light). Never attribute a verse to God beyond what the script marks as God speaking.

1. The script lists **13** distinct Blessings, not 12 (Smooth Stones, Shepherd's Staff, Quick Feet, Song of Courage, Watchful Eyes, Still Waters, Strength of the LORD, Hidden in the Rock, Faithful Friend, Goliath's Sword, Mighty Men, Gift of Abigail, Mercy). All 13 are mapped.
2. Script says Blessings last "until the run ends"; human decision resets them per chapter, so cards after a chapter's last playable stage are pointless (`blessingAfter` false on 1.6, 2.6, 3.9, 4.7).
3. Goliath's Sword "per-run after Nob" vs chapters 3 and 4: assumed the unlock flag survives into the chapter 4 run and is cleared if a new chapter 3 run starts. Confirm.
4. Gift of Abigail overlaps the scripted "next stage starts with extra food" (3.7). Assumed the scripted grant is a fixed amount via the `grant` beat and the card stacks on top. Stage 3.8 is stealth, so "food" has no stated mechanic; assumed food restores a heart.
5. 3.2 has no stated length; assumed a 90 s ceiling and Lamb 60 s.
6. Mercy ("sparing an enemy") has no enemies to spare in much of chapter 4; assumed spare events at 3.6, 3.8 and guards in 4.3.
7. The chapter-restart rule says "first stage", which would replay the opening cutscene; assumed `restartStage` is the first playable stage.
8. Lines referencing enemies (Goliath, Saul's spear, lion) still play in Lamb; assumed story actors remain non-hostile. The 2.6 and 2.7 Lamb version keeps the forehead-glow fall, so the story outcome is unchanged.
9. Speaker is unspecified for recurring lines (falls, encouragement, stage cleared); stored as `ui`.
10. "Under 12 words" cap is exceeded by 2 Sam 9:1, 2 Sam 7:18 and 17:49 lines (also Q7 in build-log); kept verbatim.
11. 2.7: script says 17:51 is not shown on screen but the narrator says "David won, and the Philistines ran away." The line is stored (`c2-7-narr-ran`); whether the end card also carries a verse reference is optional and not set here.
12. 1.1 mixes a cutscene with tutorial prompts, which need controllable play; modeled as `tutorial` beats inside a cutscene stage.
13. "Stage 1" to "Stage 6" labels in chapter 3 do not match the 3.x numbers (3.2 = Stage 1, 3.6 = Stage 5, 3.8 = Stage 6). Ids follow the 3.x numbers.
14. 3.9 line "David: Shall I chase them? Gold light: Pursue..." is split into two lines (speaker `david`, speaker `lord`).
15. Lamb mode and chapter unlock: assumed a Lamb completion unlocks the next chapter (`anyMode`). Confirm.
