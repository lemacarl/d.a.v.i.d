# Shepherd King

A kids' adventure game for Google TV about the young David, from shepherd boy to king. It is played with the TV remote only (no touch, no keyboard needed), is built with Godot 4.7.2 (GDScript, Compatibility renderer) and targets low-end Android TV boxes (32-bit armeabi-v7a is supported; arm64-v8a too).

Four chapters, four modes (Lamb, Shepherd, Normal, Hard): **Normal**, **Shepherd** (gentler) and **Lamb** (no enemies, no failure; for the youngest players).

## Requirements

- Godot 4.7.2 (standard build, not .NET)
- Android export templates for 4.7.2 (Editor > Manage Export Templates)
- JDK 17 and the Android SDK (build-tools, platform tools) for APK export
- `adb` for installing on a TV

## Run and test

```sh
# open the project in the editor, or run it
godot --path .

# import once, then run the whole test suite headless
godot --headless --path . --import
godot --headless --path . -s res://tests/runner.gd

# the data fidelity check (script text against the source documents)
python3 -I tests/check-data-fidelity.py
```

The runner prints `passed / failed / skipped`; the exit code is non-zero on any failure.

## Build, sign and install

Export presets are in `export_presets.cfg` (preset "Google TV"; versions `version/code` and `version/name` live there). Signing uses environment variables, so no secret is stored in the repo:

```sh
export JAVA_HOME=/path/to/jdk-17
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/path/to/release.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=<key alias>
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=<password>
godot --headless --path . --export-release "Google TV" builds/shepherd-king-0.4.0.apk
adb connect <tv-ip>:<port>
adb -s <tv-serial> install -r builds/shepherd-king-0.4.0.apk
```

Use `install -r` (replace) and never uninstall: saved progress lives in the app's data. Keystores, passwords and `builds/` are git-ignored.

## Controls (remote only)

- D-pad: walk, choose, steer, dodge lanes, pick menu items
- OK: act (tap) or play the harp (hold); in Lamb mode OK acts at once
- Back: pause menu

Every stage can be completed with the D-pad, OK and Back alone.

## Offline and child safety

The game is fully offline: the exported app requests no permissions (no INTERNET), has no ads, no analytics, no accounts, no purchases and no links out. Progress is saved only on the device. There is no gore; the story is told gently with a narrator and subtitles.

## Layout

| Folder | What is in it |
|---|---|
| `actors/` | Drawn characters, hazards and props (code-drawn placeholder art) |
| `stages/` | Stage logic per type (play, boss, stealth, rhythm, maze, camp, cutscene) |
| `screens/`, `ui/`, `theme/` | Title, chapter select, stage host, menus, HUD, shared theme |
| `autoload/` | RunState, SaveData, Settings, Audio singletons |
| `model/`, `modifiers/` | Run model and Blessing / mode modifiers |
| `data/` | All story, stage, balance, audio and Blessing data (JSON) |
| `audio/` | Music and sound effects (CC0); narration goes in `audio/narration/` |
| `tests/` | Headless test suite and data fidelity check |
| `tools/` | Icon generator |
| `docs/` | Design and engineering documents |

## Documents

- [docs/spec.md](docs/spec.md): product spec and acceptance criteria
- [docs/architecture.md](docs/architecture.md), [docs/contracts.md](docs/contracts.md), [docs/data-schema.md](docs/data-schema.md): engineering
- [docs/milestone-plan.md](docs/milestone-plan.md), [docs/build-log.md](docs/build-log.md): plan and history
- [docs/hard-mode.md](docs/hard-mode.md), [docs/script-source.md](docs/script-source.md), [docs/narration-sheet-ch1.md](docs/narration-sheet-ch1.md): modes, script, narration
- [docs/playtest-template.md](docs/playtest-template.md): notes template for family playtests
- Test and review reports: `docs/test-report-*.md`, `docs/review-*.md`

## Credits and licences

See [CREDITS.md](CREDITS.md). Godot Engine is MIT licensed; music and effects are CC0.
