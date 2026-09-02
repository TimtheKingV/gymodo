"use server";

import { revalidatePath } from "next/cache";
import {
  DomainError,
  attachExerciseToModel,
  confirmInstructionVideo,
  createEquipmentModel,
  createExercise,
  createMachine,
  createSettingDefinition,
  deactivateMachine,
  deleteSettingDefinition,
  detachExercise,
  prepareInstructionVideoUpload,
  reactivateMachine,
  regenerateStudioJoinCode,
  removeMembership,
  reorderModelExercises,
  revokeTag,
  setMembershipRole,
  setStudioJoinCodeActive,
  updateEquipmentModel,
  uploadEquipmentPhoto,
} from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";

/**
 * Die Trainerfunktionen als Server Actions -- kein HTTP, keine Endpoints.
 *
 * Das Web ruft die Domain-Schicht direkt auf (Spec 6.1): eine REST-Flaeche
 * waere ein Vertrag nach aussen, den ausser dieser Oberflaeche niemand
 * braucht. Der Client ist immer der nutzergebundene aus dem Cookie, nie
 * Service-Role -- die Studio-Konsistenz lebt in den Policies.
 */

export type ActionResult = { ok: true } | { ok: false; error: string };

/** Genau ein Ergebnisformat fuer alle Formulare: entweder ok oder ein Satz. */
async function fuehreAus(
  pfad: string,
  arbeit: (client: Awaited<ReturnType<typeof createServerSupabaseClient>>) => Promise<void>,
): Promise<ActionResult> {
  const client = await createServerSupabaseClient();
  try {
    await arbeit(client);
  } catch (fehler) {
    if (fehler instanceof DomainError) return { ok: false, error: fehler.message };
    // Ein unerwarteter Fehler wird geloggt, aber nie im Wortlaut angezeigt:
    // seine Meldung kann Spaltennamen oder IDs fremder Zeilen enthalten.
    console.error("Portal-Aktion fehlgeschlagen:", fehler);
    return { ok: false, error: "Das hat nicht geklappt. Bitte noch einmal." };
  }
  revalidatePath(pfad);
  return { ok: true };
}

function text(formData: FormData, name: string): string {
  return String(formData.get(name) ?? "").trim();
}

/** Leeres Feld heisst "nicht gesetzt", nicht "leerer Text". */
function optionalerText(formData: FormData, name: string): string | null {
  const wert = text(formData, name);
  return wert.length > 0 ? wert : null;
}

/** Deutsche Eingabe: 2,5 ist dasselbe wie 2.5. */
function zahl(formData: FormData, name: string): number | undefined {
  const roh = text(formData, name).replace(",", ".");
  if (roh.length === 0) return undefined;
  const wert = Number(roh);
  return Number.isFinite(wert) ? wert : Number.NaN;
}

export async function modellAnlegen(
  studioId: string,
  _prev: unknown,
  formData: FormData,
): Promise<ActionResult> {
  return fuehreAus(`/portal/${studioId}`, async (client) => {
    await createEquipmentModel(client, {
      studioId,
      name: text(formData, "name"),
      manufacturer: optionalerText(formData, "manufacturer"),
      weightStepKg: zahl(formData, "weightStepKg") ?? Number.NaN,
      minWeightKg: zahl(formData, "minWeightKg") ?? 0,
      maxWeightKg: zahl(formData, "maxWeightKg") ?? null,
    });
  });
}

export async function modellAendern(
  studioId: string,
  modelId: string,
  _prev: unknown,
  formData: FormData,
): Promise<ActionResult> {
  return fuehreAus(`/portal/${studioId}/modelle/${modelId}`, async (client) => {
    await updateEquipmentModel(client, modelId, {
      name: text(formData, "name"),
      manufacturer: optionalerText(formData, "manufacturer"),
      weightStepKg: zahl(formData, "weightStepKg"),
      minWeightKg: zahl(formData, "minWeightKg"),
      maxWeightKg: zahl(formData, "maxWeightKg") ?? null,
    });
  });
}

export async function fotoHochladen(
  studioId: string,
  modelId: string,
  _prev: unknown,
  formData: FormData,
): Promise<ActionResult> {
  return fuehreAus(`/portal/${studioId}/modelle/${modelId}`, async (client) => {
    const datei = formData.get("photo");
    if (!(datei instanceof File) || datei.size === 0) {
      throw new DomainError("validation_failed", "Es ist keine Datei ausgewaehlt.");
    }
    // Das Foto laeuft bewusst durch den Server: nur hier lassen sich die
    // Aufnahmedaten entfernen, bevor die Datei im Bucket landet.
    await uploadEquipmentPhoto(client, {
      equipmentModelId: modelId,
      bytes: new Uint8Array(await datei.arrayBuffer()),
    });
  });
}

export async function parameterAnlegen(
  studioId: string,
  modelId: string,
  _prev: unknown,
  formData: FormData,
): Promise<ActionResult> {
  return fuehreAus(`/portal/${studioId}/modelle/${modelId}`, async (client) => {
    const kind = text(formData, "kind") === "enum" ? "enum" : "number";
    await createSettingDefinition(client, {
      equipmentModelId: modelId,
      key: text(formData, "key"),
      label: text(formData, "label"),
      kind,
      minValue: kind === "number" ? (zahl(formData, "minValue") ?? null) : null,
      maxValue: kind === "number" ? (zahl(formData, "maxValue") ?? null) : null,
      stepValue: kind === "number" ? (zahl(formData, "stepValue") ?? null) : null,
      unit: optionalerText(formData, "unit"),
      allowedValues:
        kind === "enum"
          ? text(formData, "allowedValues")
              .split("\n")
              .map((zeile) => zeile.trim())
              .filter((zeile) => zeile.length > 0)
          : null,
    });
  });
}

export async function parameterLoeschen(
  studioId: string,
  modelId: string,
  settingId: string,
): Promise<ActionResult> {
  return fuehreAus(`/portal/${studioId}/modelle/${modelId}`, async (client) => {
    await deleteSettingDefinition(client, settingId);
  });
}

export async function uebungAnlegen(
  studioId: string,
  modelId: string,
  _prev: unknown,
  formData: FormData,
): Promise<ActionResult> {
  return fuehreAus(`/portal/${studioId}/modelle/${modelId}`, async (client) => {
    const uebung = await createExercise(client, {
      studioId,
      name: text(formData, "name"),
      description: optionalerText(formData, "description"),
      targetRepsMin: zahl(formData, "targetRepsMin") ?? Number.NaN,
      targetRepsMax: zahl(formData, "targetRepsMax") ?? Number.NaN,
    });
    // Anlegen und zuordnen in einem Schritt: eine Uebung, die an keinem
    // Geraet haengt, taucht nirgends auf und waere ein stiller Fehlschlag.
    await attachExerciseToModel(client, {
      equipmentModelId: modelId,
      exerciseId: uebung.id,
    });
  });
}

export async function uebungLoesen(
  studioId: string,
  modelId: string,
  linkId: string,
): Promise<ActionResult> {
  return fuehreAus(`/portal/${studioId}/modelle/${modelId}`, async (client) => {
    await detachExercise(client, linkId);
  });
}

export async function uebungVerschieben(
  studioId: string,
  modelId: string,
  linkIds: string[],
): Promise<ActionResult> {
  return fuehreAus(`/portal/${studioId}/modelle/${modelId}`, async (client) => {
    await reorderModelExercises(client, {
      equipmentModelId: modelId,
      orderedLinkIds: linkIds,
    });
  });
}

/**
 * Zielpfad fuer den Videoupload. Der Upload selbst laeuft aus dem Browser
 * direkt gegen den Storage-Dienst -- nur so gibt es Fortschritt und
 * Wiederaufnahme nach Abbruch. Ein 50-MiB-Upload durch eine Server Action
 * haette beides nicht.
 */
export async function videoUploadVorbereiten(
  linkId: string,
  sizeBytes: number,
): Promise<{ ok: true; bucket: string; storagePath: string } | { ok: false; error: string }> {
  const client = await createServerSupabaseClient();
  try {
    const ziel = await prepareInstructionVideoUpload(client, {
      equipmentModelExerciseId: linkId,
      sizeBytes,
    });
    return { ok: true, ...ziel };
  } catch (fehler) {
    if (fehler instanceof DomainError) return { ok: false, error: fehler.message };
    console.error("Videoupload nicht vorbereitet:", fehler);
    return { ok: false, error: "Der Upload liess sich nicht starten." };
  }
}

export async function videoBestaetigen(
  studioId: string,
  modelId: string,
  linkId: string,
  storagePath: string,
): Promise<ActionResult> {
  return fuehreAus(`/portal/${studioId}/modelle/${modelId}`, async (client) => {
    await confirmInstructionVideo(client, {
      equipmentModelExerciseId: linkId,
      storagePath,
    });
  });
}

export async function geraetAnlegen(
  studioId: string,
  modelId: string,
  _prev: unknown,
  formData: FormData,
): Promise<ActionResult> {
  return fuehreAus(`/portal/${studioId}/modelle/${modelId}`, async (client) => {
    await createMachine(client, {
      studioId,
      equipmentModelId: modelId,
      label: text(formData, "label"),
      locationNote: optionalerText(formData, "locationNote"),
    });
  });
}

export async function geraetStilllegen(
  studioId: string,
  pfad: string,
  machineId: string,
): Promise<ActionResult> {
  // Stilllegen, nie loeschen: ein Geraet, das je einen Tag getragen hat, hat
  // keinen Loeschpfad -- und die Sprache im Portal traegt das mit.
  return fuehreAus(pfad, async (client) => {
    await deactivateMachine(client, machineId);
  });
}

export async function geraetWiederInBetrieb(
  studioId: string,
  pfad: string,
  machineId: string,
): Promise<ActionResult> {
  return fuehreAus(pfad, async (client) => {
    await reactivateMachine(client, machineId);
  });
}

const BINDE_TEXT: Record<string, string> = {
  vergeben: "Dieser Tag hängt schon an einem Gerät.",
  gesperrt: "Gesperrt bleibt gesperrt.",
  aushangschild: "Das ist ein Aushangschild — es gehört an die Wand, nicht an ein Gerät.",
  unbekannt: "Neue Lieferung? Melde dich beim Betreiber.",
};

/**
 * Einen gelieferten Tag an ein Geraet binden. Das Studio kommt aus dem Geraet,
 * nicht von hier -- die Funktion in 0028 leitet es selbst ab und prueft den
 * Aufrufer dagegen.
 */
export async function tagBinden(
  studioId: string,
  pfad: string,
  token: string,
  machineId: string,
): Promise<{ ok: true } | { ok: false; error: string }> {
  const client = await createServerSupabaseClient();
  const { data, error } = await client.rpc("bind_tag_to_machine", {
    p_token: token.trim(),
    p_machine_id: machineId,
  });

  if (error) {
    console.error("Tag nicht gebunden:", error);
    return { ok: false, error: "Der Tag liess sich nicht binden." };
  }

  const verdict = (data as Array<{ verdict: string }> | null)?.[0]?.verdict ?? "unbekannt";
  if (verdict === "gebunden") {
    revalidatePath(pfad);
    return { ok: true };
  }
  return { ok: false, error: BINDE_TEXT[verdict] ?? BINDE_TEXT["unbekannt"]! };
}

export async function tagSperren(
  studioId: string,
  pfad: string,
  tagId: string,
): Promise<ActionResult> {
  return fuehreAus(pfad, async (client) => {
    await revokeTag(client, tagId);
  });
}

export async function mitgliedRolleAendern(
  studioId: string,
  pfad: string,
  userId: string,
  role: "member" | "trainer",
): Promise<ActionResult> {
  return fuehreAus(pfad, async (client) => {
    await setMembershipRole(client, studioId, userId, role);
  });
}

export async function mitgliedEntfernen(
  studioId: string,
  pfad: string,
  userId: string,
): Promise<ActionResult> {
  return fuehreAus(pfad, async (client) => {
    await removeMembership(client, studioId, userId);
  });
}

export async function beitrittscodeErneuern(
  studioId: string,
  pfad: string,
): Promise<{ ok: true; code: string } | { ok: false; error: string }> {
  const client = await createServerSupabaseClient();
  try {
    const code = await regenerateStudioJoinCode(client, studioId);
    revalidatePath(pfad);
    return { ok: true, code };
  } catch (fehler) {
    if (fehler instanceof DomainError) return { ok: false, error: fehler.message };
    console.error("Code nicht erneuert:", fehler);
    return { ok: false, error: "Der Code liess sich nicht erneuern." };
  }
}

export async function beitrittscodeAktivSetzen(
  studioId: string,
  pfad: string,
  active: boolean,
): Promise<ActionResult> {
  return fuehreAus(pfad, async (client) => {
    await setStudioJoinCodeActive(client, studioId, active);
  });
}
