"""Decode and report a SkyrimNet_SexLab profiling run (WebUI Profile panel).

The game writes raw events only: <log_directory>/SkyrimNet_SexLab/<run key>/part-NNN.bin plus
part-NNN.note.txt. This script does all decoding, pairing, statistics, joins and overhead
correction. Contract: checkpoints/profile/checkpoint-04.md (binary layout: Decision 10).

  uv run python_scripts/profile_report.py ingest --run <run dir> --checkpoint checkpoints/<name> --logs <timestamp>
  uv run python_scripts/profile_report.py report <profiles dir>/<run key> [--log SkyrimNet_SexLab.log] [--csv]
  uv run python_scripts/profile_report.py compare <checkpoint>/profiles [--keep-all]
"""
import argparse
import bisect
import csv
import math
import os
import re
import shutil
import statistics
import struct
import sys
from collections import defaultdict
from pathlib import Path

HEADER = struct.Struct('<4sHH32sIQQIIII')
EVENT = struct.Struct('<BBHIIiQQI76s')
assert HEADER.size == 76 and EVENT.size == 112

TYPES = {1: 'B', 2: 'E', 3: 'X', 4: 'M'}
SOURCES = {0: 'unused', 1: 'papyrus', 2: 'wait', 3: 'skse', 4: 'trace', 5: 'mark'}
OTHER_KEY = 0xFFFF
CALIB_N = 1000

LOG_LINE = re.compile(r'^\[(\d\d):(\d\d):(\d\d)\.(\d{3})\]')
GAP_START = '[SkyrimNet_SexLab_Scene_Manager.Action_Start] intent:'
GAP_CREATOR = '[SkyrimNet_SexLab_Scene_Manager.CreateCreator] intent:'  # Scene Creator panel (and Action_Start)
GAP_END = '[skyrimnet_sexlab_scene.animationstart]'  # compared lower-case: the log writes the script name lower
POLL_KEYS = ['Scene.OnUpdate', 'Scene.Gate_Poll', 'Scene.Victim_Poll', 'Scene.Ending_Poll',
             'Scene.ActorChange_Poll', 'AnimDb.OnUpdate']
# Minigame (HUD) input: the player as arouse/calm source, a refused HUD input, or taking control of an actor.
# NPC strategy arousal never uses the player (0x14) as the source.
INPUT_PATTERNS = {'player_arouse_calm': re.compile(r'OrgasmEngine: (?:arouse|calm) 0x14->'),
                  'hud_refused': re.compile(r'Hud: (?:arouse|calm) refused'),
                  'take_control': re.compile(r'Hud: took control|player-driven true')}
SCENE_ACTORS = re.compile(r'OrgasmEngine: began scene \d+ actors=(\d+)')
README_LOGS = re.compile(r'\]\(\.\./\.\./logs/([^/)]+)/\)')


class Ev:
    __slots__ = ('type', 'source', 'key', 'id', 'os_tid', 'sl', 't', 'dur', 'stack', 'detail', 'part')

    def end(self):
        return self.t + self.dur


class Span:
    """A B/E pair or an X event: t/end in microseconds from t0."""
    __slots__ = ('source', 'key', 't', 'end', 'stack', 'os_tid', 'sl', 'detail', 'children', 'parent',
                 'n_pairs', 'n_marks', 'n_x', 'anomaly', 'kind')

    def __init__(self, source, key, t, end, stack, os_tid, sl, detail, kind):
        self.source, self.key, self.t, self.end = source, key, t, end
        self.stack, self.os_tid, self.sl, self.detail, self.kind = stack, os_tid, sl, detail, kind
        self.children, self.parent = [], None
        self.n_pairs = self.n_marks = self.n_x = 0
        self.anomaly = False

    @property
    def dur(self):
        return self.end - self.t


# ---------------------------------------------------------------- decode

def read_part(path):
    data = path.read_bytes()
    magic, version, header_bytes, run_key, part, freq, t0, dropped, count, key_count, event_bytes = \
        HEADER.unpack_from(data, 0)
    if magic != b'SLPF' or version != 1 or event_bytes != EVENT.size:
        raise ValueError(f'{path}: not a version 1 SLPF part (magic={magic!r} version={version})')
    off = header_bytes
    keys = []
    for _ in range(key_count):
        (n,) = struct.unpack_from('<H', data, off)
        off += 2
        keys.append(data[off:off + n].decode('utf-8', 'replace'))
        off += n
    events = []
    for i in range(count):
        typ, src, key, eid, tid, sl, qpc, dur, stack, detail = EVENT.unpack_from(data, off + i * EVENT.size)
        e = Ev()
        e.type = TYPES.get(typ, '?')
        e.source = SOURCES.get(src, str(src))
        e.key = 'other' if key == OTHER_KEY else (keys[key] if key < len(keys) else f'?{key}')
        e.id, e.os_tid, e.sl, e.stack, e.part = eid, tid, sl, stack, part
        e.t = (qpc - t0) * 1e6 / freq
        e.dur = dur * 1e6 / freq
        e.detail = detail.split(b'\0', 1)[0].decode('utf-8', 'replace')
        events.append(e)
    return {'path': path, 'run': run_key.split(b'\0', 1)[0].decode(), 'part': part, 'freq': freq, 't0': t0,
            'dropped': dropped, 'count': count, 'events': events}


def load_parts(parts_dir):
    parts = sorted((read_part(p) for p in parts_dir.glob('part-*.bin')), key=lambda p: p['part'])
    if not parts:
        sys.exit(f'no part-*.bin in {parts_dir}')
    events = [e for p in parts for e in p['events']]
    events.sort(key=lambda e: e.t)
    return parts, events


# ---------------------------------------------------------------- stats

def pct(sorted_vals, q):
    """Exact nearest-rank percentile."""
    if not sorted_vals:
        return 0.0
    k = max(1, math.ceil(q / 100 * len(sorted_vals)))
    return sorted_vals[k - 1]


def summary(vals):
    s = sorted(vals)
    n = len(s)
    if not n:
        return dict(count=0, total=0, mean=0, min=0, p50=0, p95=0, max=0)
    return dict(count=n, total=sum(s), mean=sum(s) / n, min=s[0], p50=pct(s, 50), p95=pct(s, 95), max=s[-1])


def ms(us):
    return f'{us / 1000:.3f}'


# ---------------------------------------------------------------- analysis

def first_mark(events, key):
    for e in events:
        if e.type == 'M' and e.key == key:
            return e.t
    return None


def calibration(events):
    out = {}
    pairs = {}
    for name in ('off', 'mark.off', 'cpp.off', 'on', 'mark.on', 'cpp.on'):
        a, b = first_mark(events, f'calib.{name}.start'), first_mark(events, f'calib.{name}.end')
        out[name] = None if a is None or b is None else (a, b)
    # number of iterations: count recorded events in the on windows; off windows assume the same n
    n_on = sum(1 for e in events if e.type == 'B' and e.key == 'calib.pair')
    n_mark = sum(1 for e in events if e.type == 'M' and e.key == 'calib.mark')
    n_cpp = sum(1 for e in events if e.type == 'X' and e.key == 'calib.cpp')
    n = {'off': n_on or CALIB_N, 'on': n_on or CALIB_N, 'mark.off': n_mark or CALIB_N,
         'mark.on': n_mark or CALIB_N, 'cpp.off': n_cpp or CALIB_N, 'cpp.on': n_cpp or CALIB_N}
    for name, w in out.items():
        pairs[name] = None if w is None else (w[1] - w[0]) / n[name]
    window = None
    if out['on'] and out['cpp.on']:
        window = (out['on'][0], out['cpp.on'][1])
    return {'windows': out, 'cost': pairs, 'n': n, 'window': window,
            'profiling_start': out['cpp.on'][1] if out['cpp.on'] else None}


def is_bookkeeping(key):
    return key.startswith('calib') or key.startswith('prof.')


def build_spans(events, calib):
    """Pair B/E, collect X. Returns spans and bookkeeping counts."""
    begins, ends = {}, {}
    for e in events:
        if e.type == 'B':
            begins[e.id] = e
        elif e.type == 'E':
            ends[e.id] = e
    spans, orphans, lost_begin, cross_part = [], [], [], 0
    for i, b in begins.items():
        e = ends.get(i)
        if e is None:
            orphans.append(b)
            continue
        if e.part != b.part:
            cross_part += 1
        spans.append(Span(b.source, b.key, b.t, e.t, b.stack, b.os_tid, b.sl, e.detail, 'pair'))
    for i, e in ends.items():
        if i not in begins:
            lost_begin.append(e)
    for e in events:
        if e.type == 'X':
            spans.append(Span(e.source, e.key, e.t, e.end(), e.stack, e.os_tid, e.sl, e.detail, 'x'))
    ids = sorted(set(begins) | set(ends))
    holes = 0
    if ids:
        seen = set(ids)
        holes = sum(1 for i in range(ids[0], ids[-1] + 1) if i not in seen)
    return spans, {'orphans': orphans, 'lost_begin': lost_begin, 'cross_part': cross_part, 'id_holes': holes}


def nest(spans):
    """Papyrus spans (and trace X with a stack id) nest per stack_id; C++ X (stack 0) nest per os_tid."""
    groups = defaultdict(list)
    for s in spans:
        if s.stack:
            groups[('stack', s.stack)].append(s)
        else:
            groups[('tid', s.os_tid)].append(s)
    anomalies = 0
    for group in groups.values():
        group.sort(key=lambda s: (s.t, -s.end))
        open_stack = []
        for s in group:
            while open_stack and open_stack[-1].end <= s.t:
                open_stack.pop()
            if open_stack:
                parent = open_stack[-1]
                if s.end <= parent.end:
                    s.parent = parent
                    parent.children.append(s)
                else:
                    s.anomaly = True
                    anomalies += 1
            open_stack.append(s)
    return anomalies


def count_descendants(spans, events):
    """Probe events inside each span on the same stack: used for overhead correction."""
    marks_by_stack = defaultdict(list)
    for e in events:
        if e.type == 'M' and e.stack:
            marks_by_stack[e.stack].append(e.t)
    for v in marks_by_stack.values():
        v.sort()

    def walk(s):
        pairs = x = 0
        for c in s.children:
            cp, cx = walk(c)
            pairs += cp + (1 if c.kind == 'pair' else 0)
            x += cx + (1 if c.kind == 'x' else 0)
        s.n_pairs, s.n_x = pairs, x
        return pairs, x

    for s in spans:
        if s.parent is None:
            walk(s)
    for s in spans:
        if s.kind == 'pair' and s.stack in marks_by_stack:
            v = marks_by_stack[s.stack]
            s.n_marks = bisect.bisect_right(v, s.end) - bisect.bisect_left(v, s.t)


def exclusive(s):
    child = sum(c.dur for c in s.children if not c.anomaly)
    return max(0.0, s.dur - child)


def corrected(s, cost):
    """Raw minus the recording cost of the probes nested inside it."""
    on_pair = cost.get('on') or 0.0
    on_mark = cost.get('mark.on') or 0.0
    x_cost = max(0.0, (cost.get('cpp.on') or 0.0) - (cost.get('cpp.off') or 0.0))
    return max(0.0, s.dur - s.n_pairs * on_pair - s.n_marks * on_mark - s.n_x * x_cost)


# ---------------------------------------------------------------- log

def log_ms(line):
    m = LOG_LINE.match(line)
    if not m:
        return None
    h, mi, se, mss = map(int, m.groups())
    return ((h * 60 + mi) * 60 + se) * 1000 + mss


def read_log(log_path, run):
    """Lines of the matched SkyrimNet_SexLab.log with a monotonic ms clock (midnight wrap)."""
    out, last, day = [], None, 0
    if not log_path or not log_path.exists():
        return out
    with open(log_path, encoding='utf-8', errors='replace') as f:
        for line in f:
            t = log_ms(line)
            if t is None:
                continue
            if last is not None and t + day < last - 12 * 3600 * 1000:
                day += 24 * 3600 * 1000
            t += day
            last = t
            out.append((t, line.rstrip('\n')))
    return out


def run_markers(lines, run):
    tag = f'[Profiler] run:{run} '
    marks = []
    for t, line in lines:
        i = line.find(tag)
        if i >= 0:
            marks.append((t, line[i + len(tag):]))
    return marks


def gaps(lines, lo, hi):
    """Action_Start intent (or CreateCreator when no Action_Start is open) -> next Scene AnimationStart before
    the following start, in [lo, hi)."""
    res, unpaired, start = [], [], None
    for t, line in lines:
        if t < lo or t >= hi:
            continue
        if GAP_START in line:
            if start is not None:
                unpaired.append(start)
            start = t
        elif GAP_CREATOR in line and start is None:
            start = t
        elif start is not None and GAP_END in line.lower():
            res.append((start, t, t - start))
            start = None
    if start is not None:
        unpaired.append(start)
    return res, unpaired


def player_input(lines, lo, hi):
    """Minigame input counts and OrgasmEngine scene actor counts in [lo, hi)."""
    counts = {k: 0 for k in INPUT_PATTERNS}
    actors = []
    for t, line in lines:
        if t < lo or t >= hi:
            continue
        for k, rx in INPUT_PATTERNS.items():
            if rx.search(line):
                counts[k] += 1
        m = SCENE_ACTORS.search(line)
        if m:
            actors.append(int(m.group(1)))
    return counts, actors


def mean_sd(v):
    if not v:
        return 0.0, 0.0
    return statistics.fmean(v), (statistics.stdev(v) if len(v) > 1 else 0.0)


# ---------------------------------------------------------------- report

def report(profiles_dir, log_path=None, want_csv=False):
    profiles_dir = Path(profiles_dir)
    parts_dir = profiles_dir / 'parts' if (profiles_dir / 'parts').is_dir() else profiles_dir
    parts, events = load_parts(parts_dir)
    run = parts[0]['run']
    if log_path is None:
        names = [profiles_dir.name]
        readme = profiles_dir / 'README.md'
        if readme.exists():
            names[:0] = README_LOGS.findall(readme.read_text(encoding='utf-8', errors='replace'))
        cands = [profiles_dir.parent.parent / 'logs' / n / 'SkyrimNet_SexLab.log' for n in names]
        log_path = next((c for c in cands if c.exists()), None)
    log_path = Path(log_path) if log_path else None

    calib = calibration(events)
    cost = calib['cost']
    spans, book = build_spans(events, calib)
    anomalies = nest(spans)
    count_descendants(spans, events)

    # part-write windows
    pw, open_w = [], None
    for e in events:
        if e.type == 'M' and e.key == 'prof.part_write.start':
            open_w = e.t
        elif e.type == 'M' and e.key == 'prof.part_write.end' and open_w is not None:
            pw.append((open_w, e.t))
            open_w = None
    if open_w is not None:
        pw.append((open_w, events[-1].t))

    cw = calib['window']
    prof_start = calib['profiling_start'] or 0.0
    t_last = max((s.end for s in spans), default=events[-1].t)
    t_last = max(t_last, events[-1].t)
    prof_secs = max(1e-9, (t_last - prof_start) / 1e6)

    def in_calib(t):
        return cw is not None and cw[0] <= t <= cw[1]

    game = [s for s in spans if not is_bookkeeping(s.key)]
    during_calib = [s for s in game if in_calib(s.t)]
    game = [s for s in game if not in_calib(s.t)]
    game_marks = [e for e in events if e.type == 'M' and not is_bookkeeping(e.key)]
    during_calib_marks = [e for e in game_marks if in_calib(e.t)]
    game_marks = [e for e in game_marks if not in_calib(e.t)]
    overlap_pw = defaultdict(int)
    for s in game:
        if any(s.t < b and s.end > a for a, b in pw):
            overlap_pw[(s.source, s.key)] += 1

    out = []
    w = out.append
    w(f'# Profile report: run {run}\n')
    w(f'Parts dir: `{scrub(parts_dir)}`  ')
    w(f'Log: `{scrub(log_path)}`\n' if log_path else 'Log: none found (gap table skipped)\n')

    # --- parts
    lines = read_log(log_path, run)
    markers = run_markers(lines, run)
    w('## Parts\n')
    w('| part | events | dropped | note |')
    w('|---|---|---|---|')
    for p in parts:
        name = f"{p['part']:03}"
        note = parts_dir / f'part-{name}.note.txt'
        text = note.read_text(encoding='utf-8', errors='replace').strip().replace('\n', ' ') if note.exists() \
            else '**missing**'
        w(f"| {name} | {p['count']} | {p['dropped']} | {text or '(empty)'} |")
    failed = [m for _, m in markers if m.endswith('write_failed')]
    w('')
    w(f'- write_failed markers: {", ".join(failed) if failed else "none"}')
    w(f"- orphans (B without E): {len(book['orphans'])}"
      + (f" ({', '.join(sorted({e.key for e in book['orphans']}))})" if book['orphans'] else ''))
    w(f"- E without B (lost begin): {len(book['lost_begin'])}")
    w(f"- spans crossing a part boundary: {book['cross_part']}")
    w(f"- id holes (lost events): {book['id_holes']}")
    w(f'- nesting anomalies (child ends after parent): {anomalies}')
    w(f'- part-write windows: {len(pw)}; gameplay spans overlapping one: {sum(overlap_pw.values())}')
    w(f'- during_calibration: {len(during_calib)} spans, {len(during_calib_marks)} marks (left out below)')
    w(f'- profiling phase length: {prof_secs:.1f} s\n')

    # --- player input (minigame) and scene shape per phase, from the log
    mk = dict()
    for t, m in markers:
        mk.setdefault(m, t)
    c_start, p_start, p_end = mk.get('calibration_start'), mk.get('profiling_start'), mk.get('profiling_end')
    if lines and p_start is not None and p_end is None:
        p_end = lines[-1][0] + 1
    phases = {}
    w('## Player input and scenes\n')
    if not lines or c_start is None or p_start is None:
        w('Run markers not found in the log; skipped.\n')
    else:
        w('Minigame input: player (0x14) as arouse/calm source, refused HUD arouse/calm, or HUD take control.\n')
        w('| phase | scenes (actors) | player arouse/calm | HUD refused | take control | minigame |')
        w('|---|---|---|---|---|---|')
        for phase, a, b in (('calibration', c_start, p_start), ('profiling', p_start, p_end)):
            counts, actors = player_input(lines, a, b)
            played = any(counts.values())
            phases[phase] = {'input': counts, 'actors': actors, 'minigame': played}
            w(f"| {phase} | {len(actors)} ({', '.join(map(str, actors)) or '-'}) | {counts['player_arouse_calm']} | "
              f"{counts['hud_refused']} | {counts['take_control']} | {'yes' if played else 'no'} |")
        w('')

    # --- probe costs
    w('## Probe costs (from the calibration windows)\n')
    w('| cost | window | per call µs |')
    w('|---|---|---|')
    labels = [('disabled pair', 'off'), ('recording pair', 'on'), ('disabled mark', 'mark.off'),
              ('recording mark', 'mark.on'), ('C++ off scope', 'cpp.off'), ('C++ on scope', 'cpp.on')]
    for label, name in labels:
        c = cost.get(name)
        w(f"| {label} | calib.{name} (n={calib['n'][name]}) | {'missing' if c is None else f'{c:.3f}'} |")
    w('')

    # --- main table
    w('## Spans by source + key (profiling phase)\n')
    w('Times in ms. `excl` = duration minus direct children. `corr` = raw minus nested probe recording cost.\n')
    w('| source | key | count | total | mean | min | p50 | p95 | max | excl total | corr mean | part-write overlap |')
    w('|---|---|---|---|---|---|---|---|---|---|---|---|')
    by = defaultdict(list)
    for s in game:
        by[(s.source, s.key)].append(s)
    rows = []
    for k, ss in by.items():
        st = summary([s.dur for s in ss])
        rows.append((k, st, sum(exclusive(s) for s in ss), statistics.fmean(corrected(s, cost) for s in ss)))
    rows.sort(key=lambda r: -r[1]['total'])
    for (src, key), st, ex, cm in rows:
        w(f"| {src} | {key} | {st['count']} | {ms(st['total'])} | {ms(st['mean'])} | {ms(st['min'])} | "
          f"{ms(st['p50'])} | {ms(st['p95'])} | {ms(st['max'])} | {ms(ex)} | {ms(cm)} | {overlap_pw.get((src, key), 0)} |")
    w('')

    # --- papyrus vs wait
    pap = sum(s.dur for s in game if s.source == 'papyrus' and s.parent is None)
    wai = sum(s.dur for s in game if s.source == 'wait')
    w('## Papyrus vs wait\n')
    w(f'- papyrus (top-level spans): {ms(pap)} ms')
    w(f'- wait: {ms(wai)} ms (no Prof_Wait call sites yet)\n')

    # --- calls per second
    w('## Calls per second\n')
    w('| key | calls | per second |')
    w('|---|---|---|')
    for k in POLL_KEYS:
        n = len(by.get(('papyrus', k), []))
        w(f'| {k} | {n} | {n / prof_secs:.2f} |')
    w('')

    # --- trace keys
    w('## Trace keys (TraceLog) by count\n')
    w('| key | count | total ms |')
    w('|---|---|---|')
    tr = sorted(((k[1], v) for k, v in by.items() if k[0] == 'trace'), key=lambda kv: -len(kv[1]))
    for key, ss in tr[:40]:
        w(f'| {key} | {len(ss)} | {ms(sum(s.dur for s in ss))} |')
    if len(tr) > 40:
        w(f'| ({len(tr) - 40} more) | | |')
    w('')

    # --- mark joins on sl_thread
    w('## Mark joins (sl_thread > -1)\n')
    anim_start = [e for e in game_marks if e.key == 'scene.animation_start']
    ends_by_sl = defaultdict(list)
    stage_by_sl = defaultdict(list)
    for s in game:
        if s.key == 'Scene_Manager.AnimationEnd' and s.sl > -1:
            ends_by_sl[s.sl].append(s.t)
        if s.key == 'Scene_Manager.StageStart' and s.sl > -1:
            stage_by_sl[s.sl].append(s.t)
    joined, not_joined = [], 0
    w('| sl_thread | animation_start → first StageStart ms | animation_start → AnimationEnd s |')
    w('|---|---|---|')
    for m in anim_start:
        if m.sl < 0:
            not_joined += 1
            continue
        st = next((t for t in sorted(stage_by_sl[m.sl]) if t >= m.t), None)
        en = next((t for t in sorted(ends_by_sl[m.sl]) if t >= m.t), None)
        if st is None and en is None:
            not_joined += 1
            continue
        joined.append(m)
        to_stage = ms(st - m.t) if st is not None else '-'
        to_end = f'{(en - m.t) / 1e6:.1f}' if en is not None else '-'
        w(f'| {m.sl} | {to_stage} | {to_end} |')
    w('')
    w(f'- scene.animation_start marks joined: {len(joined)}, not joined: {not_joined}')
    w('- action.received / scene.action_start carry sl_thread -1 (detail = intent) and are not joined.\n')

    # --- narration joins
    w('## Narration\n')
    sent = [e for e in game_marks if e.key == 'narration.sent']
    queued = [e for e in game_marks if e.key == 'narration.queue' and e.detail == 'queued']
    immediate = [e for e in game_marks if e.key == 'narration.queue' and e.detail == 'immediate']
    w(f'- narration.queue: {len(immediate)} immediate, {len(queued)} queued')
    w(f"- narration.sent: {sum(1 for e in sent if e.detail == 'immediate')} immediate, "
      f"{sum(1 for e in sent if e.detail == 'flush')} flush")
    flushes = sorted(e.t for e in sent if e.detail == 'flush')
    unflushed = [q for q in queued if not any(f >= q.t for f in flushes)]
    w(f'- unflushed queued narrations: {len(unflushed)}'
      + (' (a save load clears the queue)' if unflushed else ''))
    nj, nn = [], 0
    for e in sent:
        cands = [m for m in anim_start if m.t <= e.t and m.sl > -1
                 and not any(m.t <= t <= e.t for t in ends_by_sl[m.sl])]
        if len(cands) == 1:
            nj.append((cands[0].sl, e.detail, e.t - cands[0].t))
        else:
            nn += 1
    w(f'- narration.sent joined to one open scene: {len(nj)}; not joined (0 or several candidates): {nn}')
    if nj:
        w('\n| sl_thread | sent | since animation_start s |')
        w('|---|---|---|')
        for sl, d, dt in nj:
            w(f'| {sl} | {d} | {dt / 1e6:.2f} |')
    w('')

    # --- overhead: gap table, estimate, cross-check
    w('## Overhead (Decision 20)\n')
    overhead = None
    if not lines or c_start is None or p_start is None:
        w('Run markers not found in the log; gap table skipped.\n')
    else:
        cg, cu = gaps(lines, c_start, p_start)
        pg, pu = gaps(lines, p_start, p_end)
        # event wall time ~ calibration_start log time + t (t0 is QPC at calibration_start)
        on_pair, off_pair = cost.get('on') or 0, cost.get('off') or 0
        on_mark, off_mark = cost.get('mark.on') or 0, cost.get('mark.off') or 0
        cpp_d = (cost.get('cpp.on') or 0) - (cost.get('cpp.off') or 0)
        n_b = sorted(c_start + e.t / 1000 for e in events if e.type == 'B' and not is_bookkeeping(e.key))
        n_m = sorted(c_start + e.t / 1000 for e in events if e.type == 'M' and not is_bookkeeping(e.key))
        n_x = sorted(c_start + e.t / 1000 for e in events if e.type == 'X' and not is_bookkeeping(e.key))
        def cnt(v, a, b):
            return bisect.bisect_right(v, b) - bisect.bisect_left(v, a)

        w('| phase | start | gap ms | pairs | marks | X | estimate ms |')
        w('|---|---|---|---|---|---|---|')
        ests = []
        for phase, gl in (('calibration', cg), ('profiling', pg)):
            for a, b, g in gl:
                p, m, x = cnt(n_b, a, b), cnt(n_m, a, b), cnt(n_x, a, b)
                est = (p * (on_pair - off_pair) + m * (on_mark - off_mark) + x * cpp_d) / 1000
                if phase == 'profiling':
                    ests.append(est)
                w(f'| {phase} | {fmt_clock(a)} | {g} | {p} | {m} | {x} | {est:.3f} |')
        w('')
        w(f'- unpaired Action_Start (excluded): calibration {len(cu)}, profiling {len(pu)}')
        cm, cs = mean_sd([g for _, _, g in cg])
        pm, ps = mean_sd([g for _, _, g in pg])
        est_mean = statistics.fmean(ests) if ests else 0.0
        w(f'- calibration-phase gap: mean {cm:.1f} ms, sd {cs:.1f} (n={len(cg)})')
        w(f'- profiling-phase gap: mean {pm:.1f} ms, sd {ps:.1f} (n={len(pg)})')
        w(f'- estimate (mean per profiling gap): {est_mean:.3f} ms')
        flag_est = cm > 0 and est_mean > 0.05 * cm
        w(f"- estimate vs 5% of calibration mean ({0.05 * cm:.1f} ms): {'**FLAG**' if flag_est else 'ok'}")
        diff = pm - cm
        spread = math.sqrt(cs * cs + ps * ps)
        if len(cg) < 2 or len(pg) < 2:
            flag_x = None  # no spread from fewer than two gaps per phase
        else:
            flag_x = abs(diff) > spread and diff > est_mean
        w(f'- cross-check: measured difference {diff:.1f} ms, combined spread {spread:.1f} ms → '
          + ('skipped (n < 2 in a phase)' if flag_x is None
             else '**FLAG** (tight-loop costs understate in-scene cost)' if flag_x else 'ok'))
        w('- Neither check passes or fails the run.\n')
        overhead = {'calib_gap': (cm, cs, len(cg)), 'prof_gap': (pm, ps, len(pg)), 'estimate': est_mean,
                    'flag_est': flag_est, 'flag_x': flag_x, 'diff': diff, 'spread': spread}

    # --- notes
    w('## Notes\n')
    for p in parts:
        name = f"{p['part']:03}"
        note = parts_dir / f'part-{name}.note.txt'
        if note.exists():
            w(f"### part {name}\n\n{note.read_text(encoding='utf-8', errors='replace').strip() or '(empty)'}\n")
        else:
            w(f'### part {name}\n\n**no note file**\n')

    (profiles_dir / 'report.md').write_text('\n'.join(out) + '\n', encoding='utf-8')
    print(f"wrote {profiles_dir / 'report.md'}")
    if want_csv:
        with open(profiles_dir / 'events.csv', 'w', newline='', encoding='utf-8') as f:
            cw_ = csv.writer(f)
            cw_.writerow(['part', 'type', 'source', 'key', 'id', 'os_tid', 'sl_thread', 't_us', 'dur_us',
                          'stack_id', 'detail'])
            for e in events:
                cw_.writerow([e.part, e.type, e.source, e.key, e.id, e.os_tid, e.sl, f'{e.t:.3f}',
                              f'{e.dur:.3f}', e.stack, e.detail])
        print(f"wrote {profiles_dir / 'events.csv'}")
    notes = [parts_dir / f"part-{p['part']:03}.note.txt" for p in parts]
    return {'run': run, 'dir': profiles_dir, 'phases': phases, 'cost': cost, 'rows': rows, 'overhead': overhead,
            'events': sum(p['count'] for p in parts), 'dropped': sum(p['dropped'] for p in parts),
            'prof_secs': prof_secs, 'pap': pap, 'calls': {k: len(by.get(('papyrus', k), [])) for k in POLL_KEYS},
            'note': ' / '.join(n.read_text(encoding='utf-8', errors='replace').strip() for n in notes if n.exists())}


def scrub(path):
    """Path text with the user profile folder written as %USERPROFILE% (never commit the username)."""
    text = str(path)
    home = os.environ.get('USERPROFILE') or str(Path.home())
    for h in (home, home.replace('\\', '/')):
        if h and text.lower().startswith(h.lower()):
            return '%USERPROFILE%' + text[len(h):]
    return text


def fmt_clock(t_ms):
    t = int(t_ms) % (24 * 3600 * 1000)
    return f'{t // 3600000:02}:{t // 60000 % 60:02}:{t // 1000 % 60:02}.{t % 1000:03}'


def ingest(run_dir, checkpoint, logs, want_csv):
    run_dir, checkpoint = Path(run_dir), Path(checkpoint)
    dest = checkpoint / 'profiles' / run_dir.name
    parts = dest / 'parts'
    parts.mkdir(parents=True, exist_ok=True)
    copied = []
    for p in sorted(run_dir.glob('part-*')):
        shutil.copy2(p, parts / p.name)
        copied.append(p.name)
    if not any(n.endswith('.bin') for n in copied):
        sys.exit(f'no part-*.bin in {run_dir}')
    notes = []
    for n in sorted(c for c in copied if c.endswith('.bin')):
        stem = n[:-4]
        note = parts / f'{stem}.note.txt'
        text = note.read_text(encoding='utf-8', errors='replace').strip() if note.exists() else '**missing**'
        notes.append(f'- `{stem}`: {text or "(empty)"}')
    cmd = (f'uv run python_scripts/profile_report.py ingest --run "{scrub(run_dir)}" '
           f'--checkpoint {scrub(checkpoint.as_posix())} --logs {logs}')
    readme = [f'# Profile run {run_dir.name}', '',
              f'- Run key: `{run_dir.name}`',
              f'- Logs: [../../logs/{logs}/](../../logs/{logs}/)',
              f'- Source: `{scrub(run_dir)}`', '', '## Parts', ''] + notes + [
              '', '## Commands', '', '```', cmd,
              f'uv run python_scripts/profile_report.py report {scrub(dest.as_posix())} '
              f'--log {scrub(checkpoint.as_posix())}/logs/{logs}/SkyrimNet_SexLab.log', '```', '',
              'Report: [report.md](report.md)', '']
    (dest / 'README.md').write_text('\n'.join(readme), encoding='utf-8')
    print(f"wrote {dest / 'README.md'}")
    log = checkpoint / 'logs' / logs / 'SkyrimNet_SexLab.log'
    report(dest, log if log.exists() else None, want_csv)


def excluded(s):
    """Reason the run is left out of the comparison, or None. Minigame played only while profiling makes the
    profiling phase incomparable with the calibration phase."""
    c, p = s['phases'].get('calibration'), s['phases'].get('profiling')
    if c is None or p is None:
        return None
    if not c['minigame'] and p['minigame']:
        return 'minigame in profiling only (' + ', '.join(f'{k} {v}' for k, v in p['input'].items() if v) + ')'
    return None


def compare(profiles_dir, keep_all=False, top=25):
    profiles_dir = Path(profiles_dir)
    runs = [report(d) for d in sorted(profiles_dir.iterdir()) if (d / 'parts').is_dir()]
    if not runs:
        sys.exit(f'no <run>/parts in {profiles_dir}')
    kept, dropped = [], []
    for s in runs:
        why = None if keep_all else excluded(s)
        (dropped if why else kept).append((s, why))
    kept = [s for s, _ in kept]

    def shape(s, phase):
        p = s['phases'].get(phase)
        if p is None:
            return '?'
        actors = '/'.join(map(str, sorted(set(p['actors'])))) or '-'
        return f"{actors} actors, minigame {'yes' if p['minigame'] else 'no'}"

    out = []
    w = out.append
    w('# Profile comparison\n')
    w('Rule: a run is excluded when the minigame was not played during calibration but was played during '
      'profiling (`--keep-all` disables it).\n')
    w('## Included\n')
    w('| run | calibration | profiling | events | dropped | note |')
    w('|---|---|---|---|---|---|')
    for s in kept:
        w(f"| [{s['run']}]({s['run']}/report.md) | {shape(s, 'calibration')} | {shape(s, 'profiling')} | "
          f"{s['events']} | {s['dropped']} | {s['note'].replace(chr(10), ' ')} |")
    w('\n## Excluded\n')
    w('| run | calibration | profiling | reason | note |')
    w('|---|---|---|---|---|')
    for s, why in dropped:
        w(f"| [{s['run']}]({s['run']}/report.md) | {shape(s, 'calibration')} | {shape(s, 'profiling')} | "
          f"{why} | {s['note'].replace(chr(10), ' ')} |")
    w('')

    w('## Probe costs (µs per call)\n')
    w('| cost | ' + ' | '.join(s['run'] for s in kept) + ' |')
    w('|---|' + '---|' * len(kept))
    for name in ('off', 'on', 'mark.off', 'mark.on', 'cpp.off', 'cpp.on'):
        w(f'| calib.{name} | ' + ' | '.join('missing' if s['cost'].get(name) is None
                                            else f"{s['cost'][name]:.3f}" for s in kept) + ' |')
    w('')

    w('## Top keys by total profiled ms\n')
    w('Ranked by the largest per-run total. Each cell: count / mean ms / total ms. Runs are not pooled '
      '(scene shapes differ).\n')
    cells, best = defaultdict(dict), defaultdict(float)
    for s in kept:
        for (k, st, _ex, _cm) in s['rows']:
            cells[k][s['run']] = st
            best[k] = max(best[k], st['total'])
    w('| source | key | ' + ' | '.join(s['run'] for s in kept) + ' |')
    w('|---|---|' + '---|' * len(kept))
    for k in sorted(best, key=lambda k: -best[k])[:top]:
        row = []
        for s in kept:
            st = cells[k].get(s['run'])
            row.append('-' if st is None else f"{st['count']} / {ms(st['mean'])} / {ms(st['total'])}")
        w(f'| {k[0]} | {k[1]} | ' + ' | '.join(row) + ' |')
    w('')

    w('## Profiling phase\n')
    w('| run | length s | papyrus top-level ms | ' + ' | '.join(f'{k} /s' for k in POLL_KEYS) + ' |')
    w('|---|---|---|' + '---|' * len(POLL_KEYS))
    for s in kept:
        w(f"| {s['run']} | {s['prof_secs']:.1f} | {ms(s['pap'])} | "
          + ' | '.join(f"{s['calls'][k] / s['prof_secs']:.2f}" for k in POLL_KEYS) + ' |')
    w('')

    w('## Overhead (Decision 20)\n')
    w('| run | calibration gap ms (sd, n) | profiling gap ms (sd, n) | difference | spread | estimate ms | '
      'estimate > 5% | cross-check |')
    w('|---|---|---|---|---|---|---|---|')
    for s in kept:
        o = s['overhead']
        if o is None:
            w(f"| {s['run']} | no log markers | | | | | | |")
            continue
        (cm, cs, cn), (pm, ps, pn) = o['calib_gap'], o['prof_gap']
        w(f"| {s['run']} | {cm:.1f} ({cs:.1f}, {cn}) | {pm:.1f} ({ps:.1f}, {pn}) | {o['diff']:.1f} | "
          f"{o['spread']:.1f} | {o['estimate']:.3f} | {'**FLAG**' if o['flag_est'] else 'ok'} | "
          f"{'n < 2' if o['flag_x'] is None else '**FLAG**' if o['flag_x'] else 'ok'} |")
    w('')
    (profiles_dir / 'compare.md').write_text('\n'.join(out) + '\n', encoding='utf-8')
    print(f"wrote {profiles_dir / 'compare.md'}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest='cmd', required=True)
    a = sub.add_parser('ingest', help='copy a run into checkpoints/<name>/profiles/<logs>/ and report it')
    a.add_argument('--run', required=True, help='<log_directory>/SkyrimNet_SexLab/<run key>')
    a.add_argument('--checkpoint', required=True, help='checkpoints/<name>')
    a.add_argument('--logs', required=True, help='logs/<timestamp> folder name in the checkpoint')
    a.add_argument('--csv', action='store_true', help='also write events.csv')
    r = sub.add_parser('report', help='write report.md for a profiles dir (or a raw run dir)')
    r.add_argument('dir')
    r.add_argument('--log', help='SkyrimNet_SexLab.log covering the run')
    r.add_argument('--csv', action='store_true', help='also write events.csv')
    c = sub.add_parser('compare', help='report every <run>/ under a profiles dir and write compare.md')
    c.add_argument('dir')
    c.add_argument('--keep-all', action='store_true', help='do not exclude minigame-in-profiling-only runs')
    args = ap.parse_args()
    if args.cmd == 'ingest':
        ingest(args.run, args.checkpoint, args.logs, args.csv)
    elif args.cmd == 'compare':
        compare(args.dir, args.keep_all)
    else:
        report(args.dir, args.log, args.csv)


if __name__ == '__main__':
    main()
