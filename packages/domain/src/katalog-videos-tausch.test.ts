import { describe, expect, it } from "vitest";
import { readVideoDurationSeconds } from "./media.js";
import { plane, setzeVideos, type Datei } from "./katalog-videos-tausch.js";

function box(type: string, payload: number[]): number[] {
  const size = payload.length + 8;
  const kopf = [(size >>> 24) & 0xff, (size >>> 16) & 0xff, (size >>> 8) & 0xff, size & 0xff];
  return [...kopf, ...[...type].map((c) => c.charCodeAt(0)), ...payload];
}
function uint32(v: number): number[] {
  return [(v >>> 24) & 0xff, (v >>> 16) & 0xff, (v >>> 8) & 0xff, v & 0xff];
}
/** MP4 mit ftyp und moov/mvhd (Zeitbasis 1000, Dauer in ms). */
function mp4(ms: number): Uint8Array {
  const ftyp = box("ftyp", [...[..."isom"].map((c) => c.charCodeAt(0)), ...uint32(512)]);
  const mvhd = box("mvhd", [0, 0, 0, 0, ...uint32(0), ...uint32(0), ...uint32(1000), ...uint32(ms), ...new Array(80).fill(0)]);
  return new Uint8Array([...ftyp, ...box("moov", mvhd)]);
}
const datei = (key: string, ms: number): Datei => ({ key, bytes: mp4(ms) });

const uebung = (key: string, volume_kind: "reps" | "seconds", video: { file: string; duration_s: number } | null) => ({
  key,
  volume_kind,
  video,
});

describe("plane", () => {
  it("nimmt die Laenge wie der Import (aufgerundet aus der Datei)", () => {
    const u = [uebung("a", "reps", null), uebung("b", "reps", null)];
    const d = [datei("a", 3010), datei("b", 3000)];
    const plan = plane(u, d);
    if (!plan.ok) throw new Error(plan.fehler.join());
    expect(plan.eintraege.get("a")?.duration_s).toBe(4);
    expect(plan.eintraege.get("b")?.duration_s).toBe(3);
    for (const x of d) expect(plan.eintraege.get(x.key)?.duration_s).toBe(readVideoDurationSeconds(x.bytes));
  });

  it("trennt neue und ersetzte Videos und setzt den Pfad", () => {
    const u = [uebung("neu", "reps", null), uebung("alt", "reps", { file: "media/videos/alt.mp4", duration_s: 6 })];
    const plan = plane(u, [datei("neu", 3500), datei("alt", 4200)]);
    if (!plan.ok) throw new Error(plan.fehler.join());
    expect(plan.neu).toEqual(["neu"]);
    expect(plan.ersetzt).toEqual(["alt"]);
    expect(plan.eintraege.get("neu")).toEqual({ file: "media/videos/neu.mp4", duration_s: 4 });
  });

  it("bricht bei einer Datei ohne Uebung ab und nennt den Schluessel", () => {
    const plan = plane([uebung("a", "reps", null)], [datei("a", 3000), datei("geist", 3000)]);
    expect(plan.ok).toBe(false);
    if (!plan.ok) expect(plan.fehler.join()).toContain("geist");
  });

  it("bricht bei einer Zeituebung ab", () => {
    const plan = plane([uebung("lauf", "seconds", null)], [datei("lauf", 3000)]);
    expect(plan.ok).toBe(false);
    if (!plan.ok) expect(plan.fehler.join()).toContain("lauf");
  });

  it("nimmt eine Zeituebung nur mit auchZeit", () => {
    const u = [uebung("lauf", "seconds", null)];
    const plan = plane(u, [datei("lauf", 3000)], { auchZeit: true });
    if (!plan.ok) throw new Error(plan.fehler.join());
    expect(plan.eintraege.get("lauf")).toEqual({ file: "media/videos/lauf.mp4", duration_s: 3 });
    expect(plan.neu).toEqual(["lauf"]);
  });

  it("bricht ab, wenn die Laenge nicht lesbar ist", () => {
    const plan = plane([uebung("a", "reps", null)], [{ key: "a", bytes: new Uint8Array([1, 2, 3]) }]);
    expect(plan.ok).toBe(false);
  });

  it("bricht ab, wenn die Laenge ueber 45 s liegt", () => {
    const plan = plane([uebung("a", "reps", null)], [datei("a", 45_500)]);
    expect(plan.ok).toBe(false);
  });

  it("nimmt Uebungen ohne Datei nicht in den Plan auf", () => {
    const plan = plane([uebung("a", "reps", null), uebung("b", "reps", { file: "media/videos/b.mp4", duration_s: 6 })], [datei("a", 3000)]);
    if (!plan.ok) throw new Error(plan.fehler.join());
    expect([...plan.eintraege.keys()]).toEqual(["a"]);
  });
});

describe("setzeVideos", () => {
  const text = [
    "{",
    '  "equipment": [',
    '    {',
    '      "key": "gerät",',
    '      "photo": null',
    "    }",
    "  ],",
    '  "exercises": [',
    "    {",
    '      "key": "a",',
    '      "tags": ["x", "y"],',
    '      "video": null,',
    '      "grip": null',
    "    },",
    "    {",
    '      "key": "b",',
    '      "video": {',
    '        "file": "media/videos/b.mp4",',
    '        "duration_s": 6',
    "      },",
    '      "grip": null',
    "    },",
    "    {",
    '      "key": "c",',
    '      "video": {',
    '        "file": "media/videos/c.mp4",',
    '        "duration_s": 6',
    "      },",
    '      "grip": null',
    "    }",
    "  ]",
    "}",
    "",
  ].join("\n");

  it("setzt nur die genannten Videos und laesst den Rest zeichengleich", () => {
    const neu = setzeVideos(text, new Map([
      ["a", { file: "media/videos/a.mp4", duration_s: 4 }],
      ["b", { file: "media/videos/b.mp4", duration_s: 3 }],
    ]));
    const erwartet = text
      .replace('"video": null,', '"video": {\n        "file": "media/videos/a.mp4",\n        "duration_s": 4\n      },')
      .replace('"duration_s": 6\n      },\n      "grip": null\n    },\n    {\n      "key": "c"', '"duration_s": 3\n      },\n      "grip": null\n    },\n    {\n      "key": "c"');
    expect(neu).toBe(erwartet);
    expect(JSON.parse(neu).exercises[2].video.duration_s).toBe(6);
  });

  it("aendert nichts, wenn alles schon stimmt", () => {
    const eins = setzeVideos(text, new Map([["a", { file: "media/videos/a.mp4", duration_s: 4 }]]));
    expect(setzeVideos(eins, new Map([["a", { file: "media/videos/a.mp4", duration_s: 4 }]]))).toBe(eins);
  });

  it("meldet eine Uebung, die im Text fehlt", () => {
    expect(() => setzeVideos(text, new Map([["zz", { file: "media/videos/zz.mp4", duration_s: 4 }]]))).toThrow(/zz/);
  });
});
