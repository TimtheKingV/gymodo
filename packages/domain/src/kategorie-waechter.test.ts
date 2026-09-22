import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

/**
 * Die Kategorie (kraft/cardio) ist Anzeige, keine Logik -- Cardio-Spec
 * Abschnitt 3.5. Sie darf Listen gruppieren, Filter treiben und Kennzahlen
 * trennen, aber nie eine Entscheidung im Satzpfad oder in der Regel
 * beeinflussen. Sonst waere sie in einem Jahr der `if (cardio)`-Schalter,
 * den die Spec in Abschnitt 10 verwirft.
 *
 * Dieser Test ist die einzige Stelle, die das Versprechen haelt. Er liest
 * die vier Dateien als Text; ein Typ-Import wuerde ihn nicht ausloesen,
 * eine Abfrage, die die Spalte mitliest, schon -- und genau die soll es
 * dort nicht geben.
 */
const REGELDATEIEN = [
  "progression.ts",
  "abschluss.ts",
  "workout.ts",
  "machine-context.ts",
];

describe("category bleibt aus der Regel draussen", () => {
  it.each(REGELDATEIEN)("%s kennt das Wort category nicht", (datei) => {
    const pfad = fileURLToPath(new URL(`./${datei}`, import.meta.url));
    const quelle = readFileSync(pfad, "utf8");
    expect(quelle).not.toMatch(/\bcategory\b/);
  });
});
