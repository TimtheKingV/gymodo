"use client";

import { useActionState, useState } from "react";
import { useRouter } from "next/navigation";
import { MAX_PHOTO_BYTES } from "@fitretro/domain/media";
import { modellAnlegen } from "../../actions";
import { FotoFeld } from "../../../../bausteine/FotoFeld";
import { ModellVorlageFelder } from "../../../../bausteine/ModellVorlageFelder";
import type { TypVorlage } from "../../../../bausteine/typVorlage";
import styles from "../../halle.module.css";
import portalStyles from "../../../../portal.module.css";

/**
 * Bewusst knapp: Foto, Name, Hersteller, Schrittweite, Spanne. Alles Weitere
 * bleibt Schreibtisch (Entscheidung 6).
 *
 * Kategorie, Belastung, Rastung und Nebenbelastung kommen aus
 * ModellBelastungRad (gross) -- ersetzt die vormalige Chip-Reihe fuer die
 * Schrittweite und die getippten Ab/Bis-Felder, gleicher Stil wie bei den
 * Einstellungen. Ein Kraftgeraet braucht das Kategoriefeld nicht
 * anzufassen; Belastung und Nebenbelastung erscheinen erst bei Cardio
 * (Testnotiz 03.10., #1).
 *
 * Das Foto kommt ueber den Dateidialog des Systems (Kamera oder Mediathek)
 * und nicht aus einem eigenen Sucher: dieselbe Bedienung, vom
 * Betriebssystem gestellt, und
 * getUserMedia bleibt dem Tag-Sucher vorbehalten, wo es keine Alternative
 * gibt. Spec 5 nennt "Foto am Telefon" ausdruecklich vollstaendig vorhanden.
 *
 * Ohne eigenes Foto geht es nur weiter, wenn der Gymtavo-Typ eine Zeichnung
 * hat (Spec 2026-10-10-gymtavo-katalog-geraeteeinrichtung-design.md, 5.2);
 * die kopiert copyTypeDefaults nach dem Anlegen.
 */
export function ModellNeuFormular({
  studioId,
  typen,
}: {
  studioId: string;
  typen: TypVorlage[];
}) {
  const router = useRouter();
  const [hatFoto, setHatFoto] = useState(false);
  const [typ, setTyp] = useState<TypVorlage | null>(null);
  const fotoNoetig = !typ?.hatFoto;
  const [dateiFehler, setDateiFehler] = useState<string | null>(null);

  const [ergebnis, formAction, laeuft] = useActionState(
    async (_prev: unknown, formData: FormData) => {
      const antwort = await modellAnlegen(studioId, null, formData);
      if (antwort.ok) {
        router.push(
          `/portal/${studioId}/einrichten/modell/${antwort.modelId}/einstellungen`,
        );
      }
      return antwort;
    },
    null,
  );

  return (
    <form action={formAction} style={{ display: "grid", gap: 16 }}>
      <FotoFeld
        name="photo"
        gross
        ausloeserText="Foto des Modells auswählen"
        ariaLabel="Foto des Modells"
        hinweis={
          fotoNoetig
            ? "Das ganze Gerät ins Bild. Ein Foto je Modell, nicht je Gerät — zwei baugleiche Kabelzüge zeigen dasselbe Bild."
            : "Ohne eigenes Foto zeigt das Gerät die Gymtavo-Zeichnung. Ein echtes Foto hilft Mitgliedern, das Gerät zu erkennen."
        }
        onDatei={(datei) => {
          if (!datei) {
            setHatFoto(false);
            setDateiFehler(null);
            return;
          }
          if (datei.size > MAX_PHOTO_BYTES) {
            setHatFoto(false);
            setDateiFehler(
              `Das Foto ist ${(datei.size / 1024 / 1024).toFixed(0)} MiB groß. Mehr als ${MAX_PHOTO_BYTES / 1024 / 1024} MiB nimmt der Upload nicht an.`,
            );
            return;
          }
          setDateiFehler(null);
          setHatFoto(true);
        }}
      />
      {dateiFehler ? (
        <p className={styles.fehler} role="alert">
          {dateiFehler}
        </p>
      ) : null}

      <ModellVorlageFelder gross typen={typen} onTyp={setTyp} />
      <p className={styles.notiz}>
        Die Schrittweite kommt von den Platten am Gerät. Sie rastet später das
        Rad des Mitglieds — ein Wert, den das Gerät nicht kann, wird damit
        unmöglich.
      </p>

      {ergebnis && !ergebnis.ok ? (
        <p className={styles.fehler} role="alert">
          {ergebnis.error}
        </p>
      ) : null}

      <button
        type="submit"
        className={portalStyles.primaryGross}
        // Ein zu grosses Foto haelt auch dann zurueck, wenn keins noetig
        // waere: hochgeladen wuerde es trotzdem und scheiterte am Server.
        disabled={(fotoNoetig && !hatFoto) || laeuft || dateiFehler !== null}
      >
        {laeuft ? "Wird angelegt …" : "Weiter zu den Einstellungen"}
      </button>
    </form>
  );
}
