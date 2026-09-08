"use client";

import { useActionState, useId, useState, useTransition } from "react";
import type { StudioExercise } from "@fitretro/domain";
import {
  uebungAnlegen,
  uebungHinzufuegen,
  uebungVerschieben,
} from "../../../actions";
import { useUploads } from "../../../Uploads";
import { DateiKnopf } from "../../../../../bausteine/DateiKnopf";
import { MedienVorschau } from "../../../../../bausteine/MedienVorschau";
import { UebungRepsRad } from "../../../../../bausteine/UebungRepsRad";
import styles from "../../../halle.module.css";

type Ansicht = "zu" | "waehlen" | "neu";

/**
 * Eine Auswahl statt eines leeren Namensfelds (Spec 2). "Neue Uebung anlegen"
 * traegt hier bewusst keinen Akzent: der Bildschirm soll zum Waehlen
 * einladen, nicht zum Doppeln.
 */
export function UebungSheet({
  studioId,
  machineId,
  modelId,
  titelPraefix,
  waehlbar,
}: {
  studioId: string;
  machineId: string;
  modelId: string;
  /** Fuer die Warteschlange, wenn gleich ein Video mitgewaehlt wird --
      dieselbe Form wie bei VideoAufnehmen in page.tsx. */
  titelPraefix: string;
  waehlbar: StudioExercise[];
}) {
  const [ansicht, setAnsicht] = useState<Ansicht>("zu");
  const [fehler, setFehler] = useState<string | null>(null);
  const [laeuft, starte] = useTransition();
  const { einreihen } = useUploads();
  const [datei, setDatei] = useState<File | null>(null);
  const [objektUrl, setObjektUrl] = useState<string | null>(null);

  function aufDatei(neu: File | null) {
    setDatei(neu);
    setObjektUrl((bisherige) => {
      if (bisherige) URL.revokeObjectURL(bisherige);
      return neu ? URL.createObjectURL(neu) : null;
    });
  }

  const [ergebnis, formAction, legtAn] = useActionState(
    async (_prev: unknown, formData: FormData) => {
      const antwort = await uebungAnlegen(
        studioId,
        machineId,
        modelId,
        null,
        formData,
      );
      if (!antwort.ok) return antwort;
      // Die Datei geht in dieselbe Hintergrund-Warteschlange wie ein
      // nachtraeglich an einer Zeile gewaehltes Video -- der Trainer geht
      // sofort weiter, ohne den Upload abzuwarten (Spec 6.8).
      if (datei) {
        const name = String(formData.get("name") ?? "").trim();
        einreihen({
          titel: `${titelPraefix} · ${name}`,
          modelId,
          linkId: antwort.linkId,
          datei,
        });
      }
      setAnsicht("zu");
      aufDatei(null);
      return antwort;
    },
    null,
  );

  if (ansicht === "zu") {
    return (
      <div className={styles.karteGestrichelt}>
        <div className={styles.karteTitel}>Noch eine Übung</div>
        <button
          type="button"
          className={styles.neben}
          onClick={() => setAnsicht("waehlen")}
        >
          Aus dem Studio wählen
        </button>
        <button
          type="button"
          className={styles.neben}
          onClick={() => setAnsicht("neu")}
        >
          Neue Übung anlegen
        </button>
      </div>
    );
  }

  if (ansicht === "neu") {
    return (
      <form action={formAction} className={styles.karte}>
        <div className={styles.karteTitel}>Neue Übung</div>
        <Feld
          name="name"
          label="Name"
          required
          placeholder="Latzug · Neutralgriff"
        />
        <UebungRepsRad gross />
        <p className={styles.notiz}>
          Die Spanne ist ein Ziel, kein Vorschlag. gymodo rechnet daraus nichts
          aus — sie steht dem Mitglied unter dem Rad.
        </p>

        <div className={styles.feld}>
          <span className={styles.label}>Einweisungsvideo</span>
          <div style={{ display: "flex", gap: 12, alignItems: "flex-start" }}>
            <MedienVorschau url={objektUrl} art="video" leerText="Kein Video" mini />
            <DateiKnopf
              label="Video auswählen"
              accept="video/mp4,video/quicktime"
              capture="environment"
              gross
              onDatei={aufDatei}
            />
          </div>
          <span className={styles.notiz}>
            Optional — lässt sich auch später an der Zeile nachtragen.
          </span>
        </div>

        {ergebnis && !ergebnis.ok ? (
          <p className={styles.fehler} role="alert">
            {ergebnis.error}
          </p>
        ) : null}
        <button type="submit" className={styles.neben} disabled={legtAn}>
          {legtAn ? "Wird angelegt …" : "Hinzufügen"}
        </button>
        <button
          type="button"
          className={styles.neben}
          onClick={() => {
            aufDatei(null);
            setAnsicht("zu");
          }}
        >
          Abbrechen
        </button>
      </form>
    );
  }

  return (
    <div className={styles.karte}>
      <div className={styles.karteTitel}>Übung hinzufügen</div>

      {waehlbar.length === 0 ? (
        <p className={styles.notiz}>
          Alle Übungen des Studios hängen schon an diesem Modell.
        </p>
      ) : (
        <section className={styles.abschnitt}>
          {waehlbar.map((uebung) => (
            <div key={uebung.id} className={styles.zeile}>
              <div style={{ minWidth: 0 }}>
                <div className={styles.zeileHaupt}>{uebung.name}</div>
                <div
                  className={
                    uebung.modelCount === 0
                      ? styles.zeileMetaFaint
                      : styles.zeileMeta
                  }
                >
                  {uebung.modelCount === 0
                    ? "Noch an keinem Modell"
                    : `An ${uebung.modelCount} ${uebung.modelCount === 1 ? "Modell" : "Modellen"}`}{" "}
                  · {uebung.targetRepsMin}–{uebung.targetRepsMax} Wiederholungen
                </div>
              </div>
              <button
                type="button"
                className={styles.nebenSchmal}
                aria-label={`${uebung.name} hinzufügen`}
                disabled={laeuft}
                onClick={() => {
                  setFehler(null);
                  starte(async () => {
                    const antwort = await uebungHinzufuegen(
                      studioId,
                      machineId,
                      modelId,
                      uebung.id,
                    );
                    if (antwort.ok) setAnsicht("zu");
                    else setFehler(antwort.error);
                  });
                }}
              >
                Hinzufügen
              </button>
            </div>
          ))}
        </section>
      )}

      {fehler ? (
        <p className={styles.fehler} role="alert">
          {fehler}
        </p>
      ) : null}

      <p className={styles.notiz}>
        Übungen gehören dem Studio, nicht dem Gerät. Dieselbe Übung an zwei
        Modellen behält ihren Namen.
      </p>
      <button
        type="button"
        className={styles.neben}
        onClick={() => setAnsicht("neu")}
      >
        Neue Übung anlegen
      </button>
      <button
        type="button"
        className={styles.neben}
        onClick={() => setAnsicht("zu")}
      >
        Abbrechen
      </button>
    </div>
  );
}

/**
 * Umordnen mit zwei Knoepfen statt Ziehen. Ein Drag-and-Drop auf einem
 * Touchscreen konkurriert mit dem Seitenscrollen -- und die Liste hat selten
 * mehr als vier Zeilen.
 */
export function UebungVerschieben({
  studioId,
  machineId,
  modelId,
  linkId,
  name,
  reihenfolge,
}: {
  studioId: string;
  machineId: string;
  modelId: string;
  linkId: string;
  name: string;
  reihenfolge: string[];
}) {
  const [fehler, setFehler] = useState<string | null>(null);
  const [laeuft, starte] = useTransition();
  const index = reihenfolge.indexOf(linkId);

  function schiebe(richtung: -1 | 1) {
    const ziel = index + richtung;
    if (ziel < 0 || ziel >= reihenfolge.length) return;
    const neu = [...reihenfolge];
    [neu[index], neu[ziel]] = [neu[ziel]!, neu[index]!];
    setFehler(null);
    starte(async () => {
      const antwort = await uebungVerschieben(studioId, machineId, modelId, neu);
      if (!antwort.ok) setFehler(antwort.error);
    });
  }

  return (
    <span style={{ flexShrink: 0, display: "flex", gap: 8 }}>
      {fehler ? (
        <span className={styles.fehler} role="alert">
          {fehler}
        </span>
      ) : null}
      <button
        type="button"
        className={styles.nebenSchmal}
        aria-label={`${name} nach oben`}
        disabled={laeuft || index <= 0}
        onClick={() => schiebe(-1)}
      >
        ↑
      </button>
      <button
        type="button"
        className={styles.nebenSchmal}
        aria-label={`${name} nach unten`}
        disabled={laeuft || index >= reihenfolge.length - 1}
        onClick={() => schiebe(1)}
      >
        ↓
      </button>
    </span>
  );
}

function Feld({
  name,
  label,
  ...rest
}: {
  name: string;
  label: string;
} & React.InputHTMLAttributes<HTMLInputElement>) {
  const id = useId();
  return (
    <div className={styles.feld}>
      <label className={styles.label} htmlFor={id}>
        {label}
      </label>
      <input id={id} name={name} className={styles.eingabe} {...rest} />
    </div>
  );
}
