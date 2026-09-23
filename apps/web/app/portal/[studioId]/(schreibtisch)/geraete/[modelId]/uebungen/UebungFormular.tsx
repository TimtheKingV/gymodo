"use client";

import { useActionState, useRef, useState } from "react";
import { Feld } from "../../../../../Form";
import { DateiKnopf } from "../../../../../bausteine/DateiKnopf";
import { MedienVorschau } from "../../../../../bausteine/MedienVorschau";
import { UebungRepsRad } from "../../../../../bausteine/UebungRepsRad";
import { ladeVideoHoch } from "../../../../../bausteine/videoUpload";
import { videoBestaetigen, type Ergebnis } from "../../../../../actions";
import styles from "../../../../../portal.module.css";

/**
 * Wiederholungen ab/bis kommen als Rad (UebungRepsRad), gleicher Stil wie
 * bei den Einstellungen. Das Einweisungsvideo laesst sich gleich hier mit
 * anhaengen -- Trainer-Wunsch: "Upload ins Anlege-Formular integrieren",
 * ein Schritt statt zwei.
 *
 * Kein AktionsFormular: das kann nur einen einzelnen Aktionsaufruf, hier
 * braucht es zwei nacheinander. `action` legt die Uebung an und liefert
 * ihre `linkId`; erst danach, mit dieser id, kann das Video ueberhaupt sein
 * Ziel bekommen (videoUploadVorbereiten braucht eine bestehende
 * Verknuepfung). Die Datei selbst waehlt der Trainer schon VOR dem Absenden
 * -- ein Dateidialog laesst sich nach einem asynchronen Schritt ohnehin
 * nicht mehr automatisch oeffnen, das verlangt eine eigene Nutzergeste.
 *
 * Schlaegt nur der Video-Teil fehl, bleibt die Uebung trotzdem angelegt
 * (gleiches Muster wie beim Modell-Foto in actions.ts) -- eine Fehlermeldung
 * dazu, aber kein Rueckabwickeln. Ein Video laesst sich an der Zeile
 * jederzeit nachtragen oder ersetzen (VideoUpload.tsx).
 */
export function UebungFormular({
  studioId,
  modelId,
  action,
}: {
  studioId: string;
  modelId: string;
  action: (prev: unknown, formData: FormData) => Promise<Ergebnis<{ linkId: string }>>;
}) {
  const formRef = useRef<HTMLFormElement>(null);
  const [datei, setDatei] = useState<File | null>(null);
  const [objektUrl, setObjektUrl] = useState<string | null>(null);
  const [fortschritt, setFortschritt] = useState<number | null>(null);

  function aufDatei(neu: File | null) {
    setDatei(neu);
    setObjektUrl((bisherige) => {
      if (bisherige) URL.revokeObjectURL(bisherige);
      return neu ? URL.createObjectURL(neu) : null;
    });
  }

  const [ergebnis, formAction, laeuft] = useActionState(
    async (_prev: unknown, formData: FormData) => {
      const antwort = await action(null, formData);
      if (!antwort.ok) return antwort;

      if (datei) {
        setFortschritt(0);
        const hochgeladen = await ladeVideoHoch({
          linkId: antwort.linkId,
          datei,
          onFortschritt: setFortschritt,
        });
        if (!hochgeladen.ok) {
          setFortschritt(null);
          return { ok: false as const, error: `Übung angelegt, aber ${hochgeladen.error}` };
        }
        const bestaetigt = await videoBestaetigen(
          studioId,
          modelId,
          antwort.linkId,
          hochgeladen.storagePath,
        );
        setFortschritt(null);
        if (!bestaetigt.ok) {
          return { ok: false as const, error: `Übung angelegt, aber ${bestaetigt.error}` };
        }
      }

      aufDatei(null);
      // Wie AktionsFormular mit leertNachErfolg: Uebungen legt man
      // mehrere hintereinander an, und das Namensfeld ist das erste, in
      // das jemand dann tippt.
      formRef.current?.reset();
      formRef.current?.querySelector<HTMLInputElement>("input:not([type=hidden])")?.focus();
      return { ok: true as const };
    },
    null,
  );

  return (
    <form ref={formRef} action={formAction} className={styles.sectionBody}>
      <Feld name="name" label="Name" required placeholder="Latzug breit" />
      <UebungRepsRad />

      <div className={styles.field}>
        <span className={styles.label}>Einweisungsvideo</span>
        <div className={styles.mediaRow}>
          <MedienVorschau url={objektUrl} art="video" leerText="Kein Video" groesse="mini" />
          <DateiKnopf
            label="Video hinzufügen"
            accept="video/mp4,video/quicktime"
            disabled={laeuft}
            onDatei={aufDatei}
          />
        </div>
        <span className={styles.hint}>
          Optional — lässt sich auch später an der Zeile nachtragen oder
          ersetzen.
        </span>
      </div>

      {fortschritt !== null ? (
        <div
          className={styles.progressTrack}
          role="progressbar"
          aria-valuemin={0}
          aria-valuemax={100}
          aria-valuenow={Math.round(fortschritt * 100)}
          aria-label="Video-Upload"
        >
          <div
            className={styles.progressBar}
            style={{ width: `${Math.round(fortschritt * 100)}%` }}
          />
        </div>
      ) : null}

      {ergebnis && !ergebnis.ok ? (
        <p className={styles.error} role="alert">
          {ergebnis.error}
        </p>
      ) : null}

      <div className={styles.actions}>
        <button type="submit" className={styles.primary} disabled={laeuft}>
          {laeuft ? "Wird angelegt …" : "Übung anlegen"}
        </button>
        <span className={styles.erfolg} role="status">
          {ergebnis?.ok ? "Angelegt — sie steht jetzt unten in der Liste." : ""}
        </span>
      </div>
    </form>
  );
}
