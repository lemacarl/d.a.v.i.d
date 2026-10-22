# Build log

## 2026-10-23 — Phase 1/3 environment check
- Working dir `/Users/lema/d.a.v.i.d` is NOT a git repo (has `project.godot`, `.godot`, `icon.svg`, `.gitignore`, `.editorconfig`, `.gitattributes`).
- `gh repo view lemacarl/d.a.v.i.d` fails (not found / no access). No remote.
- Godot 4.7.2 stable at /Applications/Godot.app; project.godot features: 4.7, Mobile renderer.
- Android export templates: none found. JDK 11 installed (Godot Android export needs 17). Android SDK present; debug keystore present.
- `adb devices`: no TV connected.
- Prompt placeholders unfilled: base branch, Godot version, TV model/IP, Asana, notes path, branch prefix, keystore, version scheme, APK output path.

## Blocking questions (script)
- Q1 Lamb mode vs scripted enemies: Lamb has "no enemies", yet Goliath, Saul's spear, Ziklag raiders, Jerusalem guards are story beats. How does Lamb play those stages (skip, cutscene-only, or enemy-free version)? Is Lamb the full story or a free-roam mode?
- Q2 Stage 2.2 (carry basket) fits no listed stage type. OK to add a `delivery` type? Loaf count and what happens on timeout are unspecified.
- Q3 Timeouts: 2.2 (2 min) and 3.9 (3 min) — fail, or extend?
- Q4 Goliath out of stones says "run ends; restart from 2.5", but the global rule restarts at the chapter's first stage. Which? And in Shepherd mode (David cannot end a run) how does running out of stones behave?
- Q5 3.3 Jonathan's arrows: "interactive, watch where the arrow lands" — what input, if any? What does Faithful Friend change?
- Q6 Blessings: does a chapter's last stage offer cards? Do Blessings reset per chapter? Is Goliath's Sword a permanent unlock or per run?
- Q7 Script lines exceed the stated "under 12 words" cap in places (e.g. 2 Sam 9:1 line, 2 Sam 7:18 line, narrator 17:49 line). Treat as exempt (I will not reword)?
- Q8 Mercy Blessing in Ch 4 (few enemies) and Song of Courage "hold OK 2 s" vs tap-to-sling: confirm hold-vs-tap is acceptable on remote.
- Q9 Unspecified numbers (hearts, bear HP, men per day, maze size, villagers, etc.): approve the **[A]** defaults in spec.md or supply values.

## 2026-10-23 — Phase 3 baseline (desktop; TV pending)
- Branch `feature/baseline-hello-tv`. Debug APK exported headlessly: `builds/shepherd-king-debug.apk` (167 MB debug, both ABIs; release will be smaller). First Gradle run took ~35 min (dependency download); later runs are faster.
- Export settings: preset "Google TV" in `export_presets.cfg`; Gradle build with custom template in `android/build` (4.7.2.stable); ABIs armeabi-v7a + arm64-v8a; package `com.lemacarl.shepherdking`; version 0.0.1 (code 1); immersive; no custom permissions.
- Template edits (`android/build/src/main/AndroidManifest.xml`): `LEANBACK_LAUNCHER` category, `android:banner` (320x180 placeholder `res/drawable-xhdpi/banner.png`), touchscreen / leanback / gamepad `required=false`. `config.gradle` buildTools set to 36.0.0 (installed). Landscape forced by template.
- Project: 1920x1080, canvas_items, aspect keep, landscape, ETC2/ASTC import on, `auto_accept_quit=false`. `android/.gdignore` stops Godot importing the template.
- Verified with aapt2: no `uses-permission` entries (no INTERNET), LEANBACK_LAUNCHER present, banner set.
- Toolchain: JDK 17 (openjdk@17) and Android SDK paths set in Godot editor settings; debug keystore ~/.android/debug.keystore.
- Defaults chosen (not provided): branch prefix `feature`, version scheme `0.<milestone>.<build>`, APK output `builds/` (gitignored). Release keystore: to be generated locally, never committed.
- NOT yet verified: install on TV, remote button mapping (incl. Back). Needs a TV.
