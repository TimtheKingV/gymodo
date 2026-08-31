import type { SupabaseClient } from "@supabase/supabase-js";
import { requireUserId } from "./auth.js";
import { DomainError } from "./errors.js";
import {
  MAX_PHOTO_BYTES,
  MAX_VIDEO_BYTES,
  MAX_VIDEO_SECONDS,
  PHOTO_BUCKET,
  VIDEO_BUCKET,
  readVideoDurationSeconds,
  sniffMediaType,
  stripImageMetadata,
} from "./media.js";

/**
 * Medien anlegen und ausliefern -- immer mit dem nutzergebundenen Client.
 *
 * Nie der Service-Role-Schluessel: die Studio-Konsistenz lebt in den Policies
 * aus 0020, nicht im Schema. Mit Service-Role fiele sie ersatzlos weg und
 * jeder Trainer koennte in jeden Studio-Ordner schreiben.
 */

/** Der Ordner, in dem ein Studio seine Medien hat -- siehe storage_studio_id. */
function studioFolder(storagePath: string): string {
  return storagePath.split("/")[0] ?? "";
}

/**
 * Rolle des Aufrufers im Studio. memberships_select_own laesst jeden seine
 * eigene Mitgliedschaft lesen, also kommt die Antwort ohne Service-Role aus.
 *
 * Das ersetzt die Policy nicht -- sie bleibt die Instanz, die entscheidet.
 * Es erspart nur, 25 MiB hochzuladen, bevor die Ablehnung kommt.
 */
async function requireStudioStaff(
  client: SupabaseClient,
  studioId: string,
  userId: string,
): Promise<void> {
  const { data } = await client
    .from("studio_memberships")
    .select("role")
    .eq("studio_id", studioId)
    .eq("user_id", userId)
    .maybeSingle<{ role: string }>();

  if (!data || (data.role !== "trainer" && data.role !== "owner")) {
    throw new DomainError(
      "unauthorized",
      "Nur Trainer und Inhaber pflegen den Geraetekatalog.",
    );
  }
}

/** Studio eines Geraetemodells. RLS blendet fremde Modelle aus. */
async function studioOfModel(
  client: SupabaseClient,
  equipmentModelId: string,
): Promise<{ studioId: string; photoPath: string | null }> {
  const { data } = await client
    .from("equipment_models")
    .select("studio_id, photo_path")
    .eq("id", equipmentModelId)
    .maybeSingle<{ studio_id: string; photo_path: string | null }>();

  // Ein fremdes Modell liefert not_found, nicht forbidden -- sonst liesse
  // sich durch Ausprobieren feststellen, welche IDs es anderswo gibt.
  if (!data) {
    throw new DomainError("not_found", "Dieses Geraetemodell gibt es nicht.");
  }
  return { studioId: data.studio_id, photoPath: data.photo_path };
}

/** Studio hinter einer Modell-Uebung-Verknuepfung. */
async function studioOfLink(
  client: SupabaseClient,
  equipmentModelExerciseId: string,
): Promise<string> {
  const { data } = await client
    .from("equipment_model_exercises")
    .select("id, equipment_models (studio_id)")
    .eq("id", equipmentModelExerciseId)
    .maybeSingle();

  const row = data as unknown as {
    equipment_models: { studio_id: string } | null;
  } | null;
  if (!row?.equipment_models) {
    throw new DomainError("not_found", "Diese Uebung gibt es an dem Geraet nicht.");
  }
  return row.equipment_models.studio_id;
}

/**
 * Geraetefoto hochladen, Aufnahmedaten entfernen, Pfad am Modell eintragen.
 *
 * Die Bytes werden vor dem Upload angesehen: der Bucket prueft nur den
 * behaupteten Content-Type (Spec 6.8 verlangt die Pruefung am Inhalt).
 */
export async function uploadEquipmentPhoto(
  client: SupabaseClient,
  input: { equipmentModelId: string; bytes: Uint8Array },
): Promise<{ storagePath: string }> {
  const userId = await requireUserId(client);

  if (input.bytes.byteLength > MAX_PHOTO_BYTES) {
    throw new DomainError(
      "validation_failed",
      `Das Foto ist groesser als ${MAX_PHOTO_BYTES / 1024 / 1024} MiB.`,
    );
  }

  const kind = sniffMediaType(input.bytes);
  if (kind !== "image/jpeg" && kind !== "image/png") {
    throw new DomainError(
      "validation_failed",
      "Nur JPEG und PNG sind als Geraetefoto moeglich.",
    );
  }

  const { studioId, photoPath: bisher } = await studioOfModel(
    client,
    input.equipmentModelId,
  );
  await requireStudioStaff(client, studioId, userId);

  const bereinigt = stripImageMetadata(input.bytes);
  const endung = kind === "image/jpeg" ? "jpg" : "png";
  // Neuer Name je Upload: ein ersetztes Foto darf nicht aus einem Cache
  // oder einer noch gueltigen signierten URL zurueckkommen.
  const storagePath = `${studioId}/models/${input.equipmentModelId}/${crypto.randomUUID()}.${endung}`;

  const { error: uploadError } = await client.storage
    .from(PHOTO_BUCKET)
    .upload(storagePath, new Blob([bereinigt], { type: kind }), {
      contentType: kind,
    });
  if (uploadError) {
    throw new DomainError("internal", uploadError.message);
  }

  const { error: updateError } = await client
    .from("equipment_models")
    .update({ photo_path: storagePath })
    .eq("id", input.equipmentModelId);
  if (updateError) {
    // Der Eintrag ist das, was zaehlt. Ohne ihn ist das Objekt unerreichbar,
    // also geht es gleich wieder weg.
    await client.storage.from(PHOTO_BUCKET).remove([storagePath]);
    throw new DomainError("internal", updateError.message);
  }

  if (bisher && bisher !== storagePath) {
    await client.storage.from(PHOTO_BUCKET).remove([bisher]);
  }

  return { storagePath };
}

/**
 * Zielpfad fuer ein Einweisungsvideo vergeben, bevor der Browser hochlaedt.
 *
 * Der Upload selbst laeuft direkt gegen den Storage-Dienst -- nur so gibt es
 * Fortschritt und Wiederaufnahme nach Abbruch (Spec 6.8, Studio-WLAN). Die
 * Policy aus 0020 haelt ihn im Ordner des eigenen Studios; geprueft wird der
 * Inhalt danach in confirmInstructionVideo.
 */
export async function prepareInstructionVideoUpload(
  client: SupabaseClient,
  input: { equipmentModelExerciseId: string; sizeBytes: number },
): Promise<{ bucket: string; storagePath: string }> {
  const userId = await requireUserId(client);

  if (!Number.isFinite(input.sizeBytes) || input.sizeBytes <= 0) {
    throw new DomainError("validation_failed", "Die Datei ist leer.");
  }
  if (input.sizeBytes > MAX_VIDEO_BYTES) {
    throw new DomainError(
      "validation_failed",
      `Das Video ist groesser als ${MAX_VIDEO_BYTES / 1024 / 1024} MiB.`,
    );
  }

  const studioId = await studioOfLink(client, input.equipmentModelExerciseId);
  await requireStudioStaff(client, studioId, userId);

  return {
    bucket: VIDEO_BUCKET,
    storagePath: `${studioId}/exercises/${input.equipmentModelExerciseId}/${crypto.randomUUID()}.mp4`,
  };
}

/**
 * Das hochgeladene Video pruefen und eintragen -- oder wegraeumen.
 *
 * Erst hier faellt die Entscheidung, denn erst hier gibt es Bytes. Was die
 * Pruefung nicht besteht, wird geloescht: ein Objekt ohne Zeile in
 * instruction_assets ist unerreichbar und waere fuer immer Ballast.
 */
export async function confirmInstructionVideo(
  client: SupabaseClient,
  input: { equipmentModelExerciseId: string; storagePath: string },
): Promise<{ instructionAssetId: string; durationS: number }> {
  const userId = await requireUserId(client);
  const studioId = await studioOfLink(client, input.equipmentModelExerciseId);
  await requireStudioStaff(client, studioId, userId);

  if (studioFolder(input.storagePath) !== studioId) {
    throw new DomainError(
      "validation_failed",
      "Dieser Pfad gehoert nicht zu diesem Studio.",
    );
  }

  const { data: blob } = await client.storage
    .from(VIDEO_BUCKET)
    .download(input.storagePath);
  if (!blob) {
    throw new DomainError("not_found", "Zu diesem Upload liegt keine Datei.");
  }
  const bytes = new Uint8Array(await blob.arrayBuffer());

  /** Was die Pruefung nicht besteht, hinterlaesst kein Objekt. */
  async function verwerfen(message: string): Promise<never> {
    await client.storage.from(VIDEO_BUCKET).remove([input.storagePath]);
    throw new DomainError("validation_failed", message);
  }

  if (bytes.byteLength > MAX_VIDEO_BYTES) {
    await verwerfen(
      `Das Video ist groesser als ${MAX_VIDEO_BYTES / 1024 / 1024} MiB.`,
    );
  }

  const kind = sniffMediaType(bytes);
  if (kind !== "video/mp4" && kind !== "video/quicktime") {
    await verwerfen("Das ist keine abspielbare Videodatei.");
  }

  // Aus der Datei gelesen, nicht vom Browser gemeldet. Eine mvhd-Box ist in
  // jeder gueltigen Aufnahme vorgeschrieben -- fehlt sie, stimmt etwas nicht.
  const durationS = readVideoDurationSeconds(bytes);
  if (durationS === null || durationS <= 0) {
    await verwerfen("Die Laufzeit des Videos liess sich nicht bestimmen.");
  }
  if (durationS! > MAX_VIDEO_SECONDS) {
    await verwerfen(`Das Video ist laenger als ${MAX_VIDEO_SECONDS} Sekunden.`);
  }

  // upsert statt insert: der zweite Anlauf nach einem Abbruch landet auf
  // derselben Zeile (unique aus 0018), statt eine zweite anzulegen.
  const { data: row, error } = await client
    .from("instruction_assets")
    .upsert(
      {
        equipment_model_exercise_id: input.equipmentModelExerciseId,
        kind: "video",
        storage_path: input.storagePath,
        duration_s: durationS,
      },
      { onConflict: "equipment_model_exercise_id,storage_path" },
    )
    .select("id")
    .single<{ id: string }>();

  if (error || !row) {
    throw new DomainError(
      "internal",
      error?.message ?? "Das Video konnte nicht eingetragen werden.",
    );
  }

  return { instructionAssetId: row.id, durationS: durationS! };
}

/**
 * Kurzlebige signierte URL. Private Buckets (Spec 6.8): ein Einweisungsvideo
 * zeigt einen Menschen, das ist kein oeffentlicher Inhalt.
 */
export async function signMediaUrl(
  client: SupabaseClient,
  bucket: string,
  storagePath: string,
  expiresInSeconds: number,
): Promise<string | null> {
  const { data } = await client.storage
    .from(bucket)
    .createSignedUrl(storagePath, expiresInSeconds);
  return data?.signedUrl ?? null;
}

/**
 * Mehrere Pfade in einem Aufruf signieren. Der Geraete-Screen zeigt bis zu
 * einem halben Dutzend Uebungen -- einzeln signiert waeren das ebenso viele
 * Roundtrips, und Spec 6.3 verlangt ausdruecklich eine Anfrage statt fuenf.
 *
 * Ein Pfad, der sich nicht signieren laesst, fehlt in der Antwort und wird
 * beim Aufrufer zu null: ein fehlendes Video macht ein Geraet nicht unbenutzbar.
 */
export async function signMediaUrls(
  client: SupabaseClient,
  bucket: string,
  storagePaths: string[],
  expiresInSeconds: number,
): Promise<Map<string, string>> {
  const signiert = new Map<string, string>();
  if (storagePaths.length === 0) return signiert;

  const { data } = await client.storage
    .from(bucket)
    .createSignedUrls(storagePaths, expiresInSeconds);

  for (const eintrag of data ?? []) {
    if (eintrag.signedUrl && eintrag.path) {
      signiert.set(eintrag.path, eintrag.signedUrl);
    }
  }
  return signiert;
}
