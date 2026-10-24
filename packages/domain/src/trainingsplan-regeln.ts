// Regeln des Trainingsplans (Spec 2026-10-21, Abschnitte 2 und 3): Ziele, Zielprofile,
// Wochenstruktur. Reine Tabellen und Funktionen, damit der Generator deterministisch bleibt.
import type { Baustein, Erfahrung, FokusBereich } from "./trainingsplan-typen.js";
import { PFLICHT_BAUSTEINE } from "./trainingsplan-typen.js";

/** Aendert sich eine Regel, steigt die Version, damit alte Plaene erkennbar bleiben. */
export const PLAN_REGEL_VERSION = "1.0.0";

export type Ziel = "muskelaufbau" | "fitness" | "abnehmen";

export function zielAusTrainingGoal(goal: string | null): Ziel | null {
  switch (goal) {
    case "build_muscle":
    case "get_stronger":
      return "muskelaufbau";
    case "stay_fit":
      return "fitness";
    case "lose_weight":
      return "abnehmen";
    default:
      return null;
  }
}

export type Zielprofil = {
  saetze: 2 | 3;
  wdh: { mehrgelenk: [number, number]; isolation: [number, number] };
  reserve: [number, number];
};

export function zielprofil(ziel: Ziel, erfahrung: Erfahrung): Zielprofil {
  const wdh: Zielprofil["wdh"] =
    ziel === "muskelaufbau"
      ? { mehrgelenk: [8, 12], isolation: [10, 15] }
      : { mehrgelenk: [10, 15], isolation: [10, 15] };
  // Anfaenger starten mit weniger Saetzen und mehr Reserve, um Technik vor Belastung zu stellen.
  if (erfahrung === "neu") return { saetze: 2, wdh, reserve: [3, 4] };
  return { saetze: 3, wdh, reserve: ziel === "muskelaufbau" ? [1, 3] : [2, 3] };
}

export type Struktur = {
  key: "gk_eine" | "gk_ab" | "gk_abc" | "ober_unter";
  einheiten: { key: string; bausteine: { pflicht: Baustein[]; ergaenzung: Baustein[] } }[];
};

const GK_ERGAENZUNG: Baustein[] = ["schulter", "rumpf", "arme", "beine_ergaenzung"];

function gk(key: string): Struktur["einheiten"][number] {
  return { key, bausteine: { pflicht: [...PFLICHT_BAUSTEINE], ergaenzung: [...GK_ERGAENZUNG] } };
}

function oberUnter(suffix: "A" | "B"): Struktur["einheiten"] {
  return [
    {
      key: `OK_${suffix}`,
      bausteine: { pflicht: ["druecken", "ziehen"], ergaenzung: ["schulter", "arme"] },
    },
    {
      key: `UK_${suffix}`,
      bausteine: { pflicht: ["beine_knie", "beine_huefte"], ergaenzung: ["beine_ergaenzung", "rumpf"] },
    },
  ];
}

/** Mehr als 6 Tage behandeln wir wie 6; die Oberkante der Spec ist 6 Tage je Woche. */
export function strukturFuerTage(tage: number): Struktur {
  if (tage <= 1) return { key: "gk_eine", einheiten: [gk("A")] };
  if (tage <= 3) return { key: "gk_ab", einheiten: [gk("A"), gk("B")] };
  if (tage === 4) return { key: "ober_unter", einheiten: [...oberUnter("A"), ...oberUnter("B")] };
  return { key: "gk_abc", einheiten: [gk("A"), gk("B"), gk("C")] };
}

/** Katalog-Muskelkeys je Fokusbereich; die Uebung muss einen davon als Hauptmuskel haben. */
export const FOKUS_MUSKELN: Record<FokusBereich, string[]> = {
  brust: ["pectorals"],
  ruecken: ["lats", "upper_back"],
  schultern: ["deltoid_lateral", "deltoid_anterior", "deltoid_posterior"],
  arme: ["biceps", "triceps"],
  po: ["glutes"],
  beine: ["quads", "hamstrings", "calves"],
  bauch: ["abs", "obliques"],
};
