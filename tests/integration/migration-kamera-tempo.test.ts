import { beforeAll, describe, expect, it } from "vitest";
import { serviceClient } from "./helpers/clients.js";

// Migration 0077: Kameraprofil und Tempo an exercises. Jede abgelehnte Zeile
// verletzt genau eine Regel, damit der Fehler den erwarteten Constraint nennt.
const kennung = crypto.randomUUID();
let studioId: string;

const gueltig = {
  kamera_profil: "oberkoerper",
  kamera_signal: "ellbogen",
  kamera_seite: "beide",
  tempo_senken_s: 2.5,
  tempo_halten_s: 0,
  tempo_heben_s: 1.5,
  tempo_beginnt_mit: "heben",
};

function einfuegen(name: string, felder: Record<string, unknown>, volumeKind = "reps") {
  return serviceClient()
    .from("exercises")
    .insert({ studio_id: studioId, name: `${name} ${kennung}`, volume_kind: volumeKind, target_min: 8, target_max: 12, ...felder })
    .select("*").single();
}

async function lehntAb(name: string, felder: Record<string, unknown>, constraint: string, volumeKind = "reps") {
  const { error } = await einfuegen(name, felder, volumeKind);
  expect(error?.code).toBe("23514");
  expect(error?.message).toContain(constraint);
}

beforeAll(async () => {
  const { data, error } = await serviceClient()
    .from("studios").insert({ name: `Kamera ${kennung}` }).select("id").single();
  if (error) throw error;
  studioId = data.id;
});

describe("exercises Kameraprofil und Tempo", () => {
  it("nimmt Profil, Signal, Seite und Tempo an", async () => {
    const { data, error } = await einfuegen("Gueltig", gueltig);
    expect(error).toBeNull();
    expect(data).toMatchObject(gueltig);
  });

  it("nimmt ohne_kamera mit Tempo, ohne Signal und Seite, an", async () => {
    const { error } = await einfuegen("OhneKamera", {
      kamera_profil: "ohne_kamera",
      tempo_senken_s: 2.5,
      tempo_halten_s: 0,
      tempo_heben_s: 1.5,
      tempo_beginnt_mit: "heben",
    });
    expect(error).toBeNull();
  });

  it("laesst eine Zeile ganz ohne die neuen Felder gelten", async () => {
    const { data, error } = await einfuegen("Ohne", {});
    expect(error).toBeNull();
    expect(data).toMatchObject({
      kamera_profil: null, kamera_signal: null, kamera_seite: null,
      tempo_senken_s: null, tempo_halten_s: null, tempo_heben_s: null, tempo_beginnt_mit: null,
    });
  });

  it("lehnt ein unbekanntes Profil ab", async () => {
    await lehntAb("Unbekannt", { ...gueltig, kamera_profil: "kopfstand" }, "exercises_kamera_profil_wert");
  });

  it("lehnt ein Profil ohne Signal und Seite ab", async () => {
    await lehntAb(
      "OhneSignal",
      { ...gueltig, kamera_signal: null, kamera_seite: null },
      "exercises_kamera_signal_seite_mit_profil",
    );
  });

  it("lehnt ohne_kamera mit Signal ab", async () => {
    await lehntAb(
      "OhneKameraSignal",
      { ...gueltig, kamera_profil: "ohne_kamera", kamera_seite: null },
      "exercises_kamera_signal_seite_mit_profil",
    );
  });

  it("lehnt ein Profil ohne beginnt_mit ab", async () => {
    await lehntAb("OhneBeginnt", { ...gueltig, tempo_beginnt_mit: null }, "exercises_tempo_beginnt_mit_mit_profil");
  });

  it("lehnt ein Tempo mit nur zwei Werten ab", async () => {
    await lehntAb("ZweiWerte", { ...gueltig, tempo_halten_s: null }, "exercises_tempo_vollstaendig");
  });

  it("lehnt ein Tempo ohne Profil ab", async () => {
    await lehntAb(
      "TempoOhneProfil",
      { tempo_senken_s: 2.5, tempo_halten_s: 0, tempo_heben_s: 1.5 },
      "exercises_tempo_nur_mit_profil",
    );
  });

  it("lehnt tempo_senken_s = 2.3 ab (kein Vielfaches von 0,5)", async () => {
    await lehntAb("Raster", { ...gueltig, tempo_senken_s: 2.3 }, "exercises_tempo_werte_raster");
  });

  it("lehnt tempo_halten_s = 3.5 ab (ueber 3,0)", async () => {
    await lehntAb("Halten", { ...gueltig, tempo_halten_s: 3.5 }, "exercises_tempo_werte_raster");
  });

  it("lehnt ein Profil an einer Uebung mit Sekunden ab", async () => {
    await lehntAb(
      "Sekunden",
      { ...gueltig, target_min: 60, target_max: 600 },
      "exercises_kamera_nur_bei_wiederholungen",
      "seconds",
    );
  });
});
