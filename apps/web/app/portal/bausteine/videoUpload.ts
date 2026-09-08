import * as tus from "tus-js-client";
// Der Unterpfad statt des Barrels: index.ts zieht ueber tags.ts das
// node:crypto-Modul mit, und das laesst sich nicht in einen Browserbundle
// packen. media.ts haengt nur an errors.ts und ist frei davon.
import { MAX_VIDEO_BYTES } from "@fitretro/domain/media";
import { createBrowserSupabaseClient, storageUrl } from "@/lib/supabase/browser";
import { videoUploadVorbereiten } from "../actions";

/**
 * Vorbereiten + TUS-Uebertragung, extrahiert aus VideoUpload.tsx --
 * gebraucht von dort (synchron, ein Video), von Uploads.tsxs Warteschlange
 * (mehrere Videos nacheinander) und vom kombinierten Anlegeformular fuer
 * Uebungen. `videoBestaetigen` bleibt bei den Aufrufern: es braucht je nach
 * Stelle unterschiedliche Werte (studioId direkt vs. `studioRef.current`),
 * und ist ein einzelner einfacher Aufruf, der sich nicht lohnt zu teilen.
 *
 * `meldungAbbruch` bleibt austauschbar: die Halle vermeidet bewusst das
 * Wort "fehlgeschlagen" (Spec 4, "gespeichert, wird gesendet"), der
 * Schreibtisch nicht -- eine geteilte TUS-Mechanik heisst nicht, dass beide
 * Seiten denselben Satz sagen muessen.
 */
export async function ladeVideoHoch({
  linkId,
  datei,
  onFortschritt,
  meldungAbbruch,
}: {
  linkId: string;
  datei: File;
  onFortschritt?: (anteil: number) => void;
  meldungAbbruch?: (ursache: unknown) => string;
}): Promise<{ ok: true; storagePath: string } | { ok: false; error: string }> {
  if (datei.size > MAX_VIDEO_BYTES) {
    return {
      ok: false,
      error: `Die Datei ist ${(datei.size / 1024 / 1024).toFixed(0)} MiB groß. Mehr als ${MAX_VIDEO_BYTES / 1024 / 1024} MiB nimmt der Upload nicht an.`,
    };
  }

  const ziel = await videoUploadVorbereiten(linkId, datei.size);
  if (!ziel.ok) return ziel;

  const supabase = createBrowserSupabaseClient();
  const {
    data: { session },
  } = await supabase.auth.getSession();
  if (!session) {
    return { ok: false, error: "Die Anmeldung ist abgelaufen. Bitte neu anmelden." };
  }

  try {
    await new Promise<void>((fertig, gescheitert) => {
      const upload = new tus.Upload(datei, {
        endpoint: storageUrl(),
        headers: { authorization: `Bearer ${session.access_token}` },
        // Der Storage-Dienst verlangt genau diese Blockgroesse.
        chunkSize: 6 * 1024 * 1024,
        uploadDataDuringCreation: true,
        removeFingerprintOnSuccess: true,
        metadata: {
          bucketName: ziel.bucket,
          objectName: ziel.storagePath,
          contentType: datei.type || "video/mp4",
        },
        onProgress: (gesendet, gesamt) => onFortschritt?.(gesamt > 0 ? gesendet / gesamt : 0),
        onError: (ursache) => gescheitert(ursache),
        onSuccess: () => fertig(),
      });
      // Ein abgebrochener Upload derselben Datei wird fortgesetzt statt neu
      // begonnen -- genau dafuer ist TUS da.
      upload.findPreviousUploads().then((frueher) => {
        if (frueher.length > 0) upload.resumeFromPreviousUpload(frueher[0]!);
        upload.start();
      });
    });
  } catch (ursache) {
    return {
      ok: false,
      error: meldungAbbruch
        ? meldungAbbruch(ursache)
        : ursache instanceof Error
          ? `Der Upload wurde unterbrochen: ${ursache.message}. Wähle dieselbe Datei noch einmal, er setzt fort.`
          : "Der Upload wurde unterbrochen. Wähle dieselbe Datei noch einmal, er setzt fort.",
    };
  }

  return { ok: true, storagePath: ziel.storagePath };
}
