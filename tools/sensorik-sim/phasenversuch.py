"""Retrospective experiment: sensor QA, 6D fusion, variable-duration cycles.

No exercise names, true counts or marked boundaries enter any predictor.
No live/iPhone performance claim: PCA and thresholds use the complete set.
Run with --output DIRECTORY. All parameters fixed before the first replay.
"""
from __future__ import annotations

import argparse
import csv
import json
import time
from pathlib import Path

import numpy as np
from ahrs.filters import EKF
from scipy.signal import butter, sosfilt, sosfilt_zi, lfilter
from scipy.spatial.transform import Rotation
from vqf import VQF

from vergleich import DATA, evaluate, load, metrics, pca


def lowpass(x, rate, hz=2.0):
    sos = butter(2, hz, fs=rate, output="sos")
    return sosfilt(sos, x, zi=sosfilt_zi(sos) * x[0])[0]


def fuse(rows, rate, method):
    """Body -> fixed frame, wxyz quaternion; acceleration in g, gyro deg/s.

    NED in AHRS uses a positive z acceleration reference, matching VQF's
    gravity-aligned acceleration convention for this calculation. No magnetic
    input is available. These are library-default, untuned first candidates.
    """
    acc = np.ascontiguousarray(rows[:, 1:4])
    gyr = np.ascontiguousarray(np.deg2rad(rows[:, 4:7]))
    if method == "vqf":
        q = VQF(1 / rate).updateBatch(gyr, acc * 9.80665)["quat6D"]
    elif method == "ekf":
        q = EKF(gyr=gyr, acc=acc, frequency=rate, frame="NED").Q
    else:
        raise ValueError(method)
    world = Rotation.from_quat(q[:, [1, 2, 3, 0]]).apply(acc)
    world[:, 2] -= 1.0
    out = rows.copy()
    out[:, 1:4] = world
    return out


def movement_evidence(rows, rate):
    """Conservative experiment floor, NOT calibrated hardware noise.

    High-pass vector acceleration is expressed in g; the maximum one-second
    RMS must exceed 0.01 g. Does not classify carrying or setting down.
    """
    acc = rows[:, 1:4]
    sos = butter(2, 0.15, fs=rate, btype="highpass", output="sos")
    hp = np.stack([sosfilt(sos, x, zi=sosfilt_zi(sos) * x[0])[0] for x in acc.T], axis=1)
    n = int(rate)
    energy = np.sum(hp * hp, axis=1)
    rms = np.sqrt(np.convolve(energy, np.ones(n) / n, mode="valid"))
    return float(np.max(rms)) if len(rms) else 0.0


def cycle_events(velocity, rate, floor=0.015):
    """Pair two measured opposite-sign velocity lobes; do not fill pauses.

    Threshold is max(floor m/s, 20% of p90 absolute velocity). Lobes must
    last 0.15..6 s, a cycle 0.6..10 s, and reach at least 10% of its other
    lobe's area. Weak intervening lobes break adjacency. A final lobe that
    has not returned near zero is incomplete. This is not an anatomical
    completeness proof; displacement/range labels are not available.
    """
    v = np.asarray(velocity)
    threshold = max(floor, 0.2 * float(np.quantile(abs(v), 0.9)))
    signs = np.sign(v)
    # Assign exact zeros to the preceding lobe, preserving actual crossings.
    for i in range(1, len(signs)):
        if signs[i] == 0:
            signs[i] = signs[i - 1]
    crossings = np.flatnonzero(signs[1:] * signs[:-1] < 0) + 1
    edges = np.unique(np.r_[0, crossings, len(v)])
    pending = None
    events = []
    for a, b in zip(edges[:-1], edges[1:]):
        segment = v[a:b]
        duration = (b - a) / rate
        closed = b < len(v) or abs(v[-1]) <= 0.15 * threshold
        started = a > 0 or abs(v[0]) <= 0.15 * threshold
        valid = (started and closed and 0.15 <= duration <= 6
                 and np.max(abs(segment)) >= threshold)
        if not valid:
            pending = None
            continue
        current = (int(a), int(b), float(np.sum(segment) / rate))
        if pending is not None:
            length = (b - pending[0]) / rate
            balance = min(abs(pending[2]), abs(current[2])) / max(abs(pending[2]), abs(current[2]))
            if pending[1] == a and pending[2] * current[2] < 0 and 0.6 <= length <= 10 and balance >= 0.1:
                events.append(dict(begin=pending[0] / rate, turn=a / rate,
                                   end=b / rate, area_balance=balance))
                pending = None
                continue
        pending = current
    return dict(count=len(events), events=events, threshold=threshold)


def phases(rows, rate):
    evidence = movement_evidence(rows, rate)
    if evidence < 0.01:
        return dict(count=0, events=[], movement_rms=evidence)
    # Fixed-frame acceleration or raw body acceleration (control). Remove
    # offsets before PCA; causal high pass limits slow integration drift.
    sos = butter(2, 0.15, fs=rate, btype="highpass", output="sos")
    acc = np.stack([sosfilt(sos, x, zi=sosfilt_zi(sos) * x[0])[0]
                    for x in rows[:, 1:4].T], axis=1)
    projected = pca(acc)
    # Leaky integral, time constant 2 s, yields a velocity proxy, not a
    # calibrated physical displacement or range-of-motion measurement.
    velocity = lfilter([9.80665 / rate], [1, -np.exp(-1 / (2 * rate))], projected)
    result = cycle_events(lowpass(velocity, rate), rate)
    return result | dict(movement_rms=evidence)


def angular_phases(rows, rate):
    """Second-round hypothesis: retain useful rotation on free weights.

    Same lobe pairing, but degrees/s rather than the linear velocity proxy.
    Fixed 3 deg/s floor. No exercise-specific or truth-dependent selection.
    """
    gyro = rows[:, 4:7]
    centered = gyro - np.median(gyro, axis=0)
    projected = pca(centered)
    return cycle_events(lowpass(projected, rate), rate, floor=3.0)


def quality(s):
    rows, rate = s["rows"], s["rate"]
    dt = np.diff(rows[:, 0])
    meta = json.loads((DATA / s["id"] / "aufnahme.json").read_text())
    comments = [l.strip() for l in (DATA / s["id"] / "messwerte.csv").read_text().splitlines() if l.startswith("#")]
    # Quiet-like windows are inferred, not independently labelled rest.
    quiet = []
    for a in range(0, len(rows) - int(rate) + 1, int(rate)):
        w = rows[a:a + int(rate)]
        ast = float(np.linalg.norm(np.std(w[:, 1:4], axis=0)))
        grms = float(np.sqrt(np.mean(np.sum(w[:, 4:7] ** 2, axis=1))))
        if ast < 0.005 and grms < 3 and abs(np.mean(np.linalg.norm(w[:, 1:4], axis=1)) - 1) < 0.05:
            quiet.append(ast)
    return dict(samples=len(rows), finite=bool(np.isfinite(rows).all()),
                rate_nominal=rate, rate_over_receive_span=(len(rows) - 1) / (rows[-1, 0] - rows[0, 0]),
                same_timestamp_fraction=float(np.mean(dt == 0)),
                sub_ms_fraction=float(np.mean(dt < 0.001)),
                negative_time_steps=int(np.sum(dt < 0)), max_receive_gap_s=float(max(dt)),
                adjacent_identical_values=int(np.sum(np.all(np.diff(rows[:, 1:], axis=0) == 0, axis=1))),
                max_abs_acc_g=float(abs(rows[:, 1:4]).max()),
                max_abs_gyro_dps=float(abs(rows[:, 4:7]).max()),
                near_acc_fullscale=int(np.sum(np.any(abs(rows[:, 1:4]) >= 15.9, axis=1))),
                near_gyro_fullscale=int(np.sum(np.any(abs(rows[:, 4:7]) >= 1990, axis=1))),
                quiet_like_windows=len(quiet),
                quiet_like_std_g_median=float(np.median(quiet)) if quiet else None,
                explicit_gap_events=sum(l.startswith("# luecke") for l in comments),
                explicit_rate_events=sum("rate" in l.lower() for l in comments),
                metadata=meta.get("statistik"), sensor=meta.get("sensor"))


def run(output):
    output.mkdir(parents=True, exist_ok=True)
    results = []
    for i, s in enumerate(load()):
        raw, rate, art = s["rows"], s["rate"], s["art"]
        variants = {}
        timings = {}
        for method in ("raw", "ekf", "vqf"):
            start = time.perf_counter()
            values = raw if method == "raw" else fuse(raw, rate, method)
            timings[method + "_fusion_ms"] = 1000 * (time.perf_counter() - start)
            start = time.perf_counter()
            variants[method + "_baseline"] = evaluate(values, rate, art)
            timings[method + "_baseline_ms"] = 1000 * (time.perf_counter() - start)
            start = time.perf_counter()
            variants[method + "_phases"] = phases(values, rate)
            timings[method + "_phases_ms"] = 1000 * (time.perf_counter() - start)
        variants["raw_pause"] = evaluate(raw, rate, art, blocks="pause")
        variants["raw_gated"] = (variants["raw_pause"] if movement_evidence(raw, rate) >= 0.01 else dict(count=0))
        results.append({k: v for k, v in s.items() if k != "rows"} |
                       dict(predictions=variants, quality=quality(s), host_timings=timings))
        if (i + 1) % 10 == 0:
            print(f"{i + 1}/97 recordings", flush=True)
    keys = list(results[0]["predictions"])
    summary = {group: {k: metrics([r for r in results if group == "all" or r["art"] == group], k)
                       for k in keys} for group in ("all", "kurzhantel", "langhantel", "stapel")}
    payload = dict(protocol="retrospective, default fusion settings, no tuning sweep, no independent holdout",
                   summary=summary, rows=results)
    (output / "phasen-ergebnisse.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
    with (output / "phasen-vergleich.csv").open("w", newline="") as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerow(["recording", "mount", "truth"] + keys)
        for r in results:
            writer.writerow([r["id"], r["art"], r["truth"]] + [None if r["predictions"][k] is None else r["predictions"][k]["count"] for k in keys])
    print(json.dumps(summary, indent=2), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    run(parser.parse_args().output)
