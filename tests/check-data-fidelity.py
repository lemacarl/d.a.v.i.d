#!/usr/bin/env python3
"""Data fidelity checker: run with `python3 -I tests/check-data-fidelity.py`."""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
import glob
CHAPTER_NUMS = sorted(int(re.search(r"ch(\d+)\.json$", p).group(1))
                      for p in glob.glob(os.path.join(ROOT, "data/chapters/ch*.json")))
FILES = ["data/recurring-lines.json"]
for n in CHAPTER_NUMS:
    FILES += [f"data/{k}/ch{n}.json" for k in ("chapters", "stages", "cutscenes", "dialogue")]
errors = []

def err(m): errors.append(m)
def norm(s): return re.sub(r"\s+", " ", s).strip()

data = {}
for f in FILES:
    try:
        with open(os.path.join(ROOT, f), encoding="utf-8") as fh:
            data[f] = json.load(fh)
    except Exception as e:
        err(f"{f}: invalid JSON or unreadable: {e}")

if errors:
    for e in errors: print("FAIL", e)
    sys.exit(1)

with open(os.path.join(ROOT, "docs/script-source.md"), encoding="utf-8") as fh:
    script = norm(fh.read())

for f, d in data.items():
    if d.get("schemaVersion") != 1: err(f"{f}: schemaVersion must be 1")

def walk(o, path, f):
    if isinstance(o, dict):
        for k, v in o.items():
            if "_" in k: err(f"{f}: key with underscore at {path}.{k}")
            walk(v, f"{path}.{k}", f)
    elif isinstance(o, list):
        for i, v in enumerate(o): walk(v, f"{path}[{i}]", f)
for f, d in data.items(): walk(d, "$", f)

# collect lines
lines = {}
def add_lines(src, items):
    for l in items:
        if l["id"] in lines: err(f"{src}: duplicate line id {l['id']}")
        if "_" in l["id"]: err(f"{src}: underscore in id {l['id']}")
        lines[l["id"]] = l
        for key in ("text", "caption", "reference"):
            if key in l and norm(l[key]) not in script:
                err(f"{src}: {l['id']}.{key} not verbatim in script: {l[key]!r}")
for n in CHAPTER_NUMS: add_lines(f"dialogue ch{n}", data[f"data/dialogue/ch{n}.json"]["lines"])
rec = data["data/recurring-lines.json"]
pools = rec["pools"]
for pid, p in pools.items(): add_lines(f"pool {pid}", p["lines"])
for s in ("pause-menu",):
    for it in rec["screens"][s]["items"]:
        if it == "Change mode ({modes})": continue  # template, checked below against the script wording
        if norm(it) not in script: err(f"pause-menu item not verbatim: {it!r}")
if norm(rec["screens"]["title"]["text"]) not in script: err("title text not verbatim")
# Approved deviation from the script wording (Andrew, issue #41): the pause item lists a fourth mode, Hard.
# The data item is the template "Change mode ({modes})", composed from screens.modes.items.
APPROVED_MODE_EXTENSIONS = ["Hard"]
SCRIPT_MODES = ["Lamb", "Shepherd", "Normal"]
mode_item = rec["screens"]["pause-menu"]["items"][2]
mode_ids = []
mode_names = []
for m in rec["screens"]["modes"]["items"]:
    mode_ids.append(m["id"])
    mode_names.append(m["name"])
    if m["id"] != m["name"].lower(): err(f"mode id {m['id']!r} must be the lower-case name")
if mode_names != SCRIPT_MODES + APPROVED_MODE_EXTENSIONS: err(f"mode names must be the scripted three then the approved extension, got {mode_names}")
if mode_item != "Change mode ({modes})": err(f"pause mode item must be the template, got {mode_item!r}")
scripted = "Change mode (" + " / ".join(SCRIPT_MODES) + ")"
if norm(scripted) not in script: err("scripted pause mode item missing from the script")
with open(os.path.join(ROOT, "data/balance.json"), encoding="utf-8") as fh:
    balance_modes = list(json.load(fh)["modes"].keys())
if sorted(balance_modes) != sorted(mode_ids): err(f"balance.json modes {balance_modes} must match the mode list {mode_ids}")
if len(mode_ids) != 4: err("modes list must have four entries (three scripted, one approved extension)")
if not rec["screens"]["run-summary"].get("continue"): err("run-summary.continue label missing")
tmpl = rec["screens"]["run-summary"]["template"]
for part in re.split(r"\{[a-zA-Z]+\}", tmpl):
    if part.strip() and norm(part) not in script: err(f"run-summary fragment not verbatim: {part!r}")

# beats
def check_beats(src, beats):
    for b in beats:
        if "line" in b and b["line"] not in lines: err(f"{src}: beat references missing line {b['line']}")
cut = {c["id"]: c for n in CHAPTER_NUMS for c in data[f"data/cutscenes/ch{n}.json"]["cutscenes"]}
for cid, c in cut.items(): check_beats(f"cutscene {cid}", c["beats"])

stages = {s["id"]: s for n in CHAPTER_NUMS for s in data[f"data/stages/ch{n}.json"]["stages"]}
for sid, s in stages.items():
    if "_" in sid: err(f"underscore in stage id {sid}")
    for trig, beats in s.get("events", {}).items(): check_beats(f"stage {sid}.{trig}", beats)
    for m, mv in s.get("modes", {}).items():
        for trig, beats in mv.get("events", {}).items(): check_beats(f"stage {sid}.{m}.{trig}", beats)
    if s["type"] == "cutscene" and s["params"]["cutsceneId"] not in cut:
        err(f"stage {sid}: cutscene {s['params']['cutsceneId']} missing")
    n = s["next"]
    if n is not None and n not in stages: err(f"stage {sid}: next {n} does not resolve")
    for ol in [s.get("onLose")] + [l.get("onLose") for l in s.get("lose", [])] + [m.get("onLose") for m in s.get("modes", {}).values()]:
      if ol:
        msg = ol["message"]
        if msg.startswith("pool:") and msg[5:] not in pools: err(f"stage {sid}: pool {msg} missing")
        if msg.startswith("line:") and msg[5:] not in lines: err(f"stage {sid}: {msg} missing")
        tgt = ol["target"]
        if tgt.startswith("stage:") and tgt[6:] not in stages: err(f"stage {sid}: onLose target {tgt} missing")

# stage-level scripture references must be verbatim script references
for sid, s in stages.items():
    for ref in s.get("references", []):
        if norm(ref) not in script: err(f"stage {sid}: reference not verbatim in script: {ref!r}")
# cutscene beat notes are script stage directions: each must appear in the script, or be listed here
# as a documented visual cue note (a note that describes a drawing, not script text).
DOCUMENTED_NOTES = set()
for cid, c in cut.items():
    for b in c["beats"]:
        note = b.get("note")
        if note is None: continue
        if norm(note) in script or note in DOCUMENTED_NOTES: continue
        err(f"cutscene {cid}: beat note not in script and not documented: {note!r}")

RESTART = {1: "1-2-night-1", 2: "2-2-road", 3: "3-2-spear", 4: "4-3-jerusalem"}
for n in CHAPTER_NUMS:
    ch = data[f"data/chapters/ch{n}.json"]
    order = ch["stages"]
    for sid in order:
        if sid not in stages: err(f"ch{n}: chapter stage {sid} missing")
        elif stages[sid]["chapter"] != n: err(f"ch{n}: stage {sid} has wrong chapter")
    if all(sid in stages for sid in order):
        chain, cur = [], order[0]
        while cur is not None and cur in stages and stages[cur]["chapter"] == n:
            chain.append(cur); cur = stages[cur]["next"]
        if chain != order: err(f"ch{n}: chapter stages {order} do not match next chain {chain}")
    if ch["number"] != n or ch["id"] != f"ch{n}": err(f"ch{n}: id/number mismatch")
    if n in RESTART and ch["restartStage"] != RESTART[n]: err(f"ch{n}: restartStage must be {RESTART[n]}")
    if ch["restartStage"] not in order: err(f"ch{n}: restartStage not in stages")
    if ch["completeCard"] not in lines: err(f"ch{n}: completeCard line missing")
    for k in ("scripture", "mainAction", "title", "davidIs", "loop", "boss"):
        if norm(ch[k]) not in script: err(f"ch{n}.{k} not verbatim in script: {ch[k]!r}")

# Every script line that ends in a parenthesised reference must carry that reference in data
# (the verbatim checks above cannot notice an omitted reference).
_REF_LINE = re.compile(r'^[A-Za-z][A-Za-z \(\)\-]*?: (.+?) \(((?:[1-3] )?[A-Z][a-z]+\.? [\d:–, ]+)\)\s*$')
_by_text = {l["text"]: l for l in lines.values()}
for _raw in open(os.path.join(ROOT, "docs/script-source.md"), encoding="utf-8").read().splitlines():
    _m = _REF_LINE.match(_raw.strip())
    if not _m:
        continue
    _l = _by_text.get(_m.group(1).strip())
    if _l is not None and not _l.get("reference"):
        err(f"line {_l['id']} is missing its script reference ({_m.group(2).strip()})")

if errors:
    for e in errors: print("FAIL", e)
    print(f"{len(errors)} problem(s)")
    sys.exit(1)
print(f"OK: {len(lines)} lines, {len(stages)} stages, {len(cut)} cutscenes, {len(CHAPTER_NUMS)} chapters; all checks passed")
