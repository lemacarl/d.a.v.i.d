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

## 2026-10-23 — Phase 3 on Android TV emulator (sdk_google_atv64_amati_arm64, arm64)
- Renderer switched to GL Compatibility: the Mobile (Vulkan) renderer showed a black screen on the emulator's SwiftShader GPU, and Compatibility is the safer choice for low-end TV SoCs.
- `application/config/quit_on_go_back=false` added: without it Back exited the app. With it, Back arrives as `NOTIFICATION_WM_GO_BACK_REQUEST` and the app stays open.
- Launch: appears under the TV launcher (`monkey -c LEANBACK_LAUNCHER`); activity `com.godot.game.GodotAppLauncher`.
- Remote keys verified via `adb input keyevent`: DPAD up/down/left/right -> ui_up/down/left/right; DPAD_CENTER and ENTER -> Enter -> ui_accept; BACK -> go-back request (app stays). No crashes in logcat.
- Still to confirm on real hardware: physical remote, 60 fps, sleep/resume. Emulator is software-rendered so it says nothing about performance.
- Release keystore generated outside the repo at ~/.shepherd-king-signing (keystore + password file, chmod 600). Never commit.
- Removed an unrelated app `com.lema.tv` (LemaTV) from the emulator at the user's request; its Android Studio project was not touched.

## 2026-10-23 — PAUSED (resume here)
State: branch `feature/milestone-1-core-chapter-1`, HEAD ffa66f4 pushed. 926/926 headless tests, data checker OK, debug APK runs on ATV emulator (emulator-5554 / 127.0.0.1:5555).
Done: phases 1-4, M1 build, tester round 1 + re-test (docs/test-report-m1*.md), reviewer round 1 + round 2 (docs/review-m1*.md), fix rounds 1-2.
Open before the M1 PR:
1. Final device smoke by the tester on HEAD: report expected at docs/test-report-m1-final.md (agent was still running at pause; if the file is missing, rerun a tester on HEAD).
2. Link the final report from docs/test-report-m1.md (reviewer H-4: stale report). Quick device check of the gold-light queue change in cutscene 1.5.
3. Re-review verdict must become APPROVED (only H-4 was NOT RESOLVED in docs/review-m1-round2.md).
4. Open PR vs main (branch also carries the baseline commits), build signed release APK (keystore ~/.shepherd-king-signing, version 0.1.x), verify manifest has no permissions, write the playtest handoff for Andrew.
Deferred: D5, D12, P-2, P-5, S-1, A-4, T-2/T-3, R2-4 (118 unused CC0 audio files packed; trim in M4).
Still needs a physical TV (#9): fps, real remote, audio loudness.
Do NOT start M2 until Andrew has playtested and approved M1. GitHub: issues/milestones/project board "Shepherd King" (project 3) track status.

## 2026-10-23 — Resumed: proceed to M2 (human instruction)
Andrew said: do not rerun the tester (the final M1 smoke test produced no report); proceed to M2. This waives the 'wait for M1 playtest approval' gate by explicit instruction. M1 remains un-PR'd: branch `feature/milestone-2-chapter-2` is cut from M1 HEAD; M1 PR/APK and the review sign-off (H-4 link) are still owed and tracked on #8 and #1. Physical-TV checks stay open (#9).

## 2026-10-23 — PAUSED again (M2 just started)
Branch `feature/milestone-2-chapter-2` (cut from M1 HEAD). Units E (data, issue #23) and F (stages, issue #24) were launched then stopped at pause before writing any file; working tree clean. To resume: relaunch E and F with the briefs in this log's M2 entry/issues #23 and #24 (E: data/*/ch2.json + checker; F: delivery, stealth, Goliath weak-point boss, cutscene extras, stone carry, tests), then tester (#25), reviewer (#26), PR + APK (#27).
Still owed from M1 (waived-gate, human said proceed): M1 PR vs main, signed release APK, reviewer H-4 link (docs/test-report-m1.md -> test-report-m1-retest.md), no final M1 device smoke report exists.

## 2026-10-23 — Real Google TV connected (wireless debugging)
Device: EcoTV1 Plus (product FPD_4KEI1), Android 14, 1920x1080, **32-bit only (armeabi-v7a)**, over adb at 192.168.11.4 (paired; connect port changes, find it with `adb mdns services`). Release 0.2.0 installed and launches from the TV launcher; renders the chapter-select screen at 1080p with no SCRIPT/USER errors in logcat. Both ABIs must stay in the export (the TV cannot run arm64). Not yet measured on the TV: fps, physical-remote key mapping, audio loudness, sleep/resume (issue #9).

## 2026-10-23 — Standing authorization (human)
Andrew: "If M3 passes reviews and tests, proceed to M4 without my approval." So M4 may start once M3 has an APPROVED reviewer verdict and a passing tester report (no open High defects). A forked session is fixing playtest notes #36-#41 on branch `feature/playtest-1-fixes` (worktree /Users/lema/d.a.v.i.d-playtest, cut from M2): those fixes must be merged into M3/M4 before the final release.

## 2026-10-23 — Playtest notes round 1 (Andrew, 0.2.0 on the TV)
Issues #36-#41 on branch `feature/playtest-1-fixes` (git worktree /Users/lema/d.a.v.i.d-playtest, cut from M2; the M3 session owns /Users/lema/d.a.v.i.d). Items: 1 stone throw tutorial broken (#36), 2 hit sound (#37), 3 harder mode (#41: Andrew chose a fourth mode `Hard`; approved deviation: pause-menu mode list now reads 'Lamb / Shepherd / Normal / Hard'), 4 lost sheep not returning (#38), 5 bear and harp clarity (#39), 6 Samuel scene visuals (#40). Builders A (field/bear/sound/sheep), B (harp), C (cutscenes/tutorial), D (Hard mode).

## 2026-10-24 - M3 fix round (Builder H)
Reviewer R3-1..R3-4 and tester D-1..D-5 addressed on `feature/milestone-3-chapter-3`: Watchful Eyes acts in 3.2, 3.5, 3.8, 3.9; Gift of Abigail's food is eaten in 3.9 (and shown on the HUD); 3.9 hearts-zero restarts the stage (spec note, [A]) and the raiders are gentler (staggered start, 110 px/s, one hit then sent away for 4 s); the camp gets `minMenAtDayStart` (0 / 140 / 280) and `unwelcomedJoinFraction` 0.5 (idle David ends at 346, a welcoming David at 415); En-gedi shows the script prompt "cut a corner of his robe" and flashes a reach ring for a too-early OK; 3.3 shows a plain OK button shape; scatter has its own `followers_scattered` signal; camp difficulty keys moved from `balance.json` `feel` into the day params; dead ch3 data keys removed; HUD hearts pulse on gain. Skipped Lows/Minors: R3-6 (Lamb families do not gather), R3-8 (Faithful Friend 3.3 trail stays dead in a real run), R3-17 test-hook API names, R3-19 unlock/grant double path, R3-21, R3-22, D-8, D-9, D-10, parameter-key checker (R3-11).

