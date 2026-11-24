import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { kameraDateiSchema, kameraFehler, tempoDateiSchema } from "./kamera.js";

/** Prueft den Zuordnungsvorschlag (tools/kamera-zuordnung/vorschlag.py) gegen Katalog und Domain-Regeln. */
const wurzel = fileURLToPath(new URL("../../../", import.meta.url));
const lies = (pfad: string) => JSON.parse(readFileSync(wurzel + pfad, "utf8"));
const zuordnung = lies("data/koerperbild/zuordnung.json");
const katalog = lies("catalog/gymtavo.json");

describe("Kamera-Zuordnung", () => {
  it("deckt genau die Uebungen mit Wiederholungen ab", () => {
    const reps = katalog.exercises.filter((u: any) => u.volume_kind === "reps").map((u: any) => u.key).sort();
    expect(Object.keys(zuordnung).sort()).toEqual(reps);
  });
  it("jeder Eintrag besteht Schema und Regeln (ohne Freischalt-Liste)", () => {
    for (const [key, e] of Object.entries<any>(zuordnung)) {
      const k = kameraDateiSchema.parse(e.kamera);
      const t = tempoDateiSchema.parse(e.tempo);
      expect(kameraFehler(k, t, "reps", { nurFreigeschaltet: false }), key).toEqual([]);
      expect(e.grund.length, key).toBeGreaterThan(0);
    }
  });
  it("was der Versuch nicht richtig zaehlte, startet ohne Kamera", () => {
    expect(zuordnung["leg_press_45"].kamera.profil).toBe("ohne_kamera");
  });
});
