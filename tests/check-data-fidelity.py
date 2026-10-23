#!/usr/bin/env python3
"""Data fidelity checker: run with `python3 -I tests/check-data-fidelity.py`."""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FILES = ["data/chapters/ch1.json", "data/stages/ch1.json", "data/cutscenes/ch1.json",
         "data/dialogue/ch1.json", "data/recurring-lines.json"]
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
add_lines("dialogue", data["data/dialogue/ch1.json"]["lines"])
rec = data["data/recurring-lines.json"]
pools = rec["pools"]
for pid, p in pools.items(): add_lines(f"pool {pid}", p["lines"])
for s in ("pause-menu",):
    for it in rec["screens"][s]["items"]:
        if norm(it) not in script: err(f"pause-menu item not verbatim: {it!r}")
if norm(rec["screens"]["title"]["text"]) not in script: err("title text not verbatim")
tmpl = rec["screens"]["run-summary"]["template"]
for part in re.split(r"\{[a-zA-Z]+\}", tmpl):
    if part.strip() and norm(part) not in script: err(f"run-summary fragment not verbatim: {part!r}")

# beats
def check_beats(src, beats):
    for b in beats:
        if "line" in b and b["line"] not in lines: err(f"{src}: beat references missing line {b['line']}")
cut = {c["id"]: c for c in data["data/cutscenes/ch1.json"]["cutscenes"]}
for cid, c in cut.items(): check_beats(f"cutscene {cid}", c["beats"])

stages = {s["id"]: s for s in data["data/stages/ch1.json"]["stages"]}
for sid, s in stages.items():
    if "_" in sid: err(f"underscore in stage id {sid}")
    for trig, beats in s.get("events", {}).items(): check_beats(f"stage {sid}.{trig}", beats)
    for m, mv in s.get("modes", {}).items():
        for trig, beats in mv.get("events", {}).items(): check_beats(f"stage {sid}.{m}.{trig}", beats)
    if s["type"] == "cutscene" and s["params"]["cutsceneId"] not in cut:
        err(f"stage {sid}: cutscene {s['params']['cutsceneId']} missing")
    n = s["next"]
    if n is not None and n not in stages: err(f"stage {sid}: next {n} does not resolve")
    ol = s.get("onLose")
    if ol:
        msg = ol["message"]
        if msg.startswith("pool:") and msg[5:] not in pools: err(f"stage {sid}: pool {msg} missing")
        if msg.startswith("line:") and msg[5:] not in lines: err(f"stage {sid}: {msg} missing")

ch = data["data/chapters/ch1.json"]
order = ch["stages"]
for sid in order:
    if sid not in stages: err(f"chapter stage {sid} missing")
if not errors:
    chain, cur = [], order[0]
    while cur is not None:
        chain.append(cur); cur = stages[cur]["next"]
    if chain != order: err(f"chapter stages {order} do not match next chain {chain}")
if ch["restartStage"] != "1-2-night-1": err("restartStage must be 1-2-night-1")
if ch["completeCard"] not in lines: err("completeCard line missing")
for k in ("scripture", "mainAction", "title", "davidIs", "loop", "boss"):
    if norm(ch[k]) not in script: err(f"chapter.{k} not verbatim in script: {ch[k]!r}")

if errors:
    for e in errors: print("FAIL", e)
    print(f"{len(errors)} problem(s)")
    sys.exit(1)
print(f"OK: {len(lines)} lines, {len(stages)} stages, {len(cut)} cutscenes; all checks passed")
