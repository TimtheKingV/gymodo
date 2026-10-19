"""Retrospective sensor experiment; never uses labels to select a prediction.

Run from any directory: python tools/sensorik-sim/vergleich.py --output /tmp/vergleich.json
Python >=3.10, numpy and scipy. Baseline and pause-block candidate also run in
Swift; other channels are Python experiments only.
Old 'blind' sets have already been inspected: all results here are retrospective.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import time

import numpy as np
from scipy.signal import lfilter

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "data/sensoraufnahmen"


def load():
    corrections = json.loads((DATA / "korrekturen.json").read_text())["aufnahmen"]
    out = []
    for name, c in sorted(corrections.items()):
        if not c.get("fuerZaehler") or c.get("repsWahr") is None:
            continue
        path = DATA / name
        meta = json.loads((path / "aufnahme.json").read_text())
        rows = np.loadtxt(path / "messwerte.csv", delimiter=",", skiprows=1, comments="#")
        out.append(dict(id=name, truth=c["repsWahr"], art=c["befestigungsart"],
                        exercise=c.get("was") or meta["kontext"]["exerciseName"],
                        rate=meta["sensor"]["rateSollHz"], rows=rows))
    for art in sorted({s["art"] for s in out}):
        rest = [s for s in out if s["art"] == art and not
                (art == "kurzhantel" and s["id"].startswith("2026-10-16-"))]
        for i, s in enumerate(rest):
            s["group"] = "former-development" if i % 2 == 0 else "former-holdout"
    for s in out:
        s.setdefault("group", "earlier-development")
    return out


def box(x, size):
    cs = np.concatenate(([0.0], np.cumsum(x)))
    i = np.arange(len(x))
    a, b = np.maximum(0, i-size//2), np.minimum(len(x), i+size//2+1)
    return (cs[b]-cs[a])/(b-a)


def pca(x, robust=False):
    centered = x-x.mean(axis=0)
    if robust:
        # Bound each sample's influence before covariance estimation. No
        # exercise name, label, metadata or ground-truth trimming is used.
        norms = np.linalg.norm(centered, axis=1)
        cap = np.sort(norms)[int(0.75 * len(norms))]
        weighted = centered * np.minimum(1, cap/np.maximum(norms, 1e-12))[:, None]
        cov = weighted.T @ weighted / len(x)
    else:
        cov = centered.T @ centered / len(x)
    v = np.ones(3)
    for _ in range(60):
        w = cov @ v
        norm = np.linalg.norm(w)
        if norm == 0:
            break
        v = w/norm
    return centered @ v


def signal(rows, rate, channel="acc"):
    dt = 1/rate
    alpha = dt/(1/(2*np.pi*3)+dt)
    x = rows[:, 4:7] if channel == "gyro" else rows[:, 1:4]
    if channel == "magnitude":
        x = np.linalg.norm(x, axis=1)[:, None]
    low = np.stack([lfilter([alpha], [1, -(1-alpha)], c,
                           zi=[(1-alpha)*c[0]])[0] for c in x.T], axis=1)
    high = low-np.stack([box(c, int(3/dt)) for c in low.T], axis=1)
    s = high[:, 0] if channel == "magnitude" else pca(high, robust=channel == "robust")
    width = int(rate)
    rms = np.sort([np.sqrt(np.mean(s[i:i+width]**2)) for i in range(0, len(s)-width+1, width)])
    cap = 1.5*rms[len(rms)//2 + (len(rms)-len(rms)//2)//2] if len(rms) else 0
    return np.clip(s, -cap, cap) if cap > 0 else s


def tempo(x, rate, lo, hi):
    x = x-x.mean()
    n = len(x)
    var = np.mean(x*x)
    if var <= 1e-9:
        return None
    a, b = int(lo/2*rate), min(int(hi*rate), n//2)
    c = {lag: float(np.dot(x[:-lag], x[lag:])/(n-lag)) for lag in range(a, b+1)}
    peaks = [i for i in range(a+1, b) if c[i] > c[i-1] and c[i] >= c[i+1] and c[i] > 0]
    if not peaks:
        return None
    top = max(c[i] for i in peaks)
    candidates = [i for i in peaks if i/rate >= lo and c[i] >= 0.85*top]
    return (candidates[0], c[candidates[0]]/var) if candidates else None


def chains(x, length, threshold):
    """Same greedy edges as Swift, computed once per start/direction."""
    w = np.lib.stride_tricks.sliding_window_view(x, length)
    w = w-w.mean(axis=1)[:, None]
    energy = np.einsum("ij,ij->i", w, w)
    n = len(w)
    fwd, back = np.full(n, -1, int), np.full(n, -1, int)
    fg, bg = np.full(n, -2.0), np.full(n, -2.0)
    for d in range(int(0.75*length), int(1.3*length)+1):
        if d >= n:
            continue
        ab = np.einsum("ij,ij->i", w[:-d], w[d:])
        den = energy[:-d]+energy[d:]
        g = np.divide(2*ab, den, out=np.zeros_like(ab), where=den > 0)
        ii = np.arange(n-d)
        update = g > fg[:-d]
        fg[ii[update]] = g[update]
        fwd[ii[update]] = ii[update]+d
        update = g > bg[d:]
        bg[ii[update]+d] = g[update]
        back[ii[update]+d] = ii[update]
    fwd[fg < threshold] = -1
    back[bg < threshold] = -1
    result = []
    for seed in range(0, len(x)-length, max(1, length//4)):
        row, cur = [seed], seed
        while fwd[cur] >= 0:
            cur = fwd[cur]
            row.append(int(cur))
        cur, before = seed, []
        while back[cur] >= 0:
            cur = back[cur]
            before.append(int(cur))
        result.append(list(reversed(before))+row)
    return result


def envelope(x, length):
    # Same centered Hann demodulation as Swift, including edge zero-padding.
    half = max(1, int(1.5*length))
    offset = np.arange(-half, half+1)
    kernel = 0.5*(1+np.cos(np.pi*offset/half))
    t = np.arange(len(x))
    mod = x*np.exp(2j*np.pi*t/length)
    full = np.convolve(mod, kernel, mode="full")
    return np.abs(full[half:half+len(x)])/half


def runs(mask):
    edges = np.flatnonzero(np.diff(np.r_[False, mask, False]))
    return list(zip(edges[::2], edges[1::2]))


def evaluate(rows, rate, art, channel="acc", blocks=False):
    if len(rows) <= int(5*rate):
        return None
    x = signal(rows, rate, channel)
    lo, threshold = (1.0, 0.8) if art == "stapel" else (1.2, 0.9)
    for hi in [3.0, 4.5]:
        t = tempo(x, rate, lo, hi)
        if t is None:
            continue
        length, quality = t
        h = envelope(x, length)
        all_chains = chains(x, length, threshold)
        chain = max(all_chains, key=len, default=[])
        active = [(a,b) for a,b in runs(h >= 0.4*h.max()) if b-a >= int(2.5*length)]
        estimate = int(sum(b-a for a,b in active)/length+0.5)
        count = len(chain)
        mode = "chain"
        if blocks == "pause":
            # Require a real quiet interval before adding separate chains.
            # Merely disjoint matches can be fragments of one continuous set.
            reference = np.sort(h)[int(0.75*len(h))]
            pauses = [(a,b) for a,b in runs(h < 0.2*reference)
                      if b-a >= length and a > 0 and b < len(x)]
            edges = [0]+[(a+b)//2 for a,b in pauses]+[len(x)]
            selected = []
            for a,b in zip(edges, edges[1:]):
                c = max((c for c in all_chains if c[0] >= a and c[-1]+length <= b), key=len, default=[])
                if len(c) >= 3:
                    selected.append(c)
            if len(selected) >= 2:
                return dict(count=sum(map(len, selected)), period=length/rate,
                            quality=min(quality, 0.49), mode="pause-blocks",
                            chain=len(chain), estimate=estimate,
                            begin=selected[0][0]/rate, end=(selected[-1][-1]+length)/rate)
        elif blocks:
            # Add only independent, complete motifs; never fill gaps with
            # imaginary equally-spaced reps. Minimum 3 recurring motifs.
            selected = []
            for c in sorted(all_chains, key=len, reverse=True):
                if len(c) < 3:
                    continue
                a, b = c[0], c[-1]+length
                if all(b <= old[0] or a >= old[-1]+length for old in selected):
                    selected.append(c)
            if selected:
                count = sum(map(len, selected))
                mode = "blocks"
        if count < 0.7*estimate:
            count, mode, quality = estimate, "duration", min(quality, 0.49)
        if count <= 0:
            continue
        if hi > 3:
            quality = min(quality, 0.49)
        return dict(count=count, period=length/rate, quality=quality, mode=mode,
                    chain=len(chain), estimate=estimate,
                    begin=chain[0]/rate if chain else None,
                    end=(chain[-1]+length)/rate if chain else None)
    return None


CANDIDATES = {"baseline": ("acc", False), "robust-axis": ("robust", False),
              "magnitude": ("magnitude", False), "gyro": ("gyro", False),
              "blocks": ("acc", True), "robust-blocks": ("robust", True),
              "pause-blocks": ("acc", "pause")}


def metrics(rows, candidate):
    errors = [None if s["predictions"][candidate] is None else
              s["predictions"][candidate]["count"]-s["truth"] for s in rows]
    return dict(n=len(errors), exact=sum(e == 0 for e in errors),
                within_one=sum(e is not None and abs(e) <= 1 for e in errors),
                missing=sum(e is None for e in errors),
                mae=sum(abs(e) for e in errors if e is not None)/max(1,sum(e is not None for e in errors)))


def stationary_diagnostic():
    """Synthetic stress test, NOT measured hardware noise or field accuracy.

    White noise, 0.002 g standard deviation per axis, 20 seconds at 50 Hz.
    No repetitions. Do not treat a random autocorrelation peak as movement.
    """
    out = []
    for seed in range(20):
        rows = np.zeros((1000, 10))
        rows[:, 0] = np.arange(1000)/50
        rows[:, 1:4] = np.random.default_rng(seed).normal(0, 0.002, (1000, 3))
        rows[:, 3] += 1
        p = evaluate(rows, 50, "kurzhantel")
        out.append(dict(seed=seed, truth=0, predicted=None if p is None else p["count"]))
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    out = []
    started = time.perf_counter()
    for i, s in enumerate(load()):
        predictions = {k: evaluate(s["rows"], s["rate"], s["art"], *v) for k,v in CANDIDATES.items()}
        out.append({k:v for k,v in s.items() if k != "rows"} | {"predictions": predictions})
        if (i+1) % 20 == 0:
            print(f"{i+1} recordings", flush=True)
    summary = {group:{k:metrics([s for s in out if group == "all" or s["group"] == group],k)
                      for k in CANDIDATES} for group in ["all", "former-holdout", "former-development", "earlier-development"]}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(dict(summary=summary, rows=out, stationary_diagnostic=stationary_diagnostic()), ensure_ascii=False, indent=2)+"\n")
    print(json.dumps(summary, indent=2))
    print(f"Elapsed {time.perf_counter()-started:.2f}s", flush=True)


if __name__ == "__main__":
    main()
