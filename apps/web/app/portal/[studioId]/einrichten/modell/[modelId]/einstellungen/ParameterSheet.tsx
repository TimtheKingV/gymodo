"use client";

import { useActionState, useId, useRef, useState, useTransition } from "react";
import {
  fotoNachreichen,
  parameterAnlegen,
  parameterLoeschen,
} from "../../../actions";
import styles from "../../../halle.module.css";

/**
 * Zahlenparameter und Auswahl brauchen verschiedene Felder -- ein Sitz hat
 * einen Bereich, eine Griffstellung eine Liste. Beides gleichzeitig zu
 * zeigen hiesse, den Trainer raten zu lassen, welche Haelfte gilt.
 *
 * Kein Akzent: der gehoert auf diesem Bildschirm dem "Weiter zum Geraet".
 */
export function ParameterSheet({
  studioId,
  modelId,
}: {
  studioId: string;
  modelId: string;
}) {
  const [offen, setOffen] = useState(false);
  const [kind, setKind] = useState<"number" | "enum">("number");
  const werteId = useId();

  const [ergebnis, formAction, laeuft] = useActionState(
    async (_prev: unknown, formData: FormData) => {
      const antwort = await parameterAnlegen(studioId, modelId, null, formData);
      if (antwort.ok) setOffen(false);
      return antwort;
    },
    null,
  );

  if (!offen) {
    return (
      <button
        type="button"
        className={styles.neben}
        onClick={() => setOffen(true)}
      >
        Parameter hinzufügen
      </button>
    );
  }

  return (
    <form action={formAction} className={styles.karte}>
      <div className={styles.karteTitel}>Neuer Parameter</div>

      <Feld
        name="label"
        label="Beschriftung"
        required
        placeholder="Sitzhöhe"
        hinweis="So steht er später vor dem Mitglied am Gerät."
      />
      <Feld
        name="key"
        label="Schlüssel"
        required
        placeholder="sitz"
        hinweis="Kurz und ohne Leerzeichen. Ändert sich später nicht."
      />

      <div className={styles.feld}>
        <span className={styles.label}>Art</span>
        <div className={styles.chips}>
          {(["number", "enum"] as const).map((wert) => (
            <button
              key={wert}
              type="button"
              className={wert === kind ? styles.chipAktiv : styles.chip}
              aria-pressed={wert === kind}
              onClick={() => setKind(wert)}
            >
              {wert === "number" ? "Zahl" : "Auswahl"}
            </button>
          ))}
        </div>
        <input type="hidden" name="kind" value={kind} />
        <span className={styles.notiz}>
          Eine Auswahl braucht mindestens zwei verschiedene Werte — mit einem
          einzigen ist sie keine Auswahl, sondern ein fester Wert.
        </span>
      </div>

      {kind === "number" ? (
        <>
          <div style={{ display: "flex", gap: 12 }}>
            <div style={{ flex: 1 }}>
              <Feld
                name="minValue"
                label="Von"
                inputMode="decimal"
                placeholder="1"
              />
            </div>
            <div style={{ flex: 1 }}>
              <Feld
                name="maxValue"
                label="Bis"
                inputMode="decimal"
                placeholder="8"
              />
            </div>
            <div style={{ flex: 1 }}>
              <Feld
                name="stepValue"
                label="Schritt"
                inputMode="decimal"
                placeholder="1"
              />
            </div>
          </div>
          <Feld
            name="unit"
            label="Einheit"
            placeholder="°"
            hinweis="Leer lassen, wenn die Rasten nur durchgezählt sind."
          />
        </>
      ) : (
        <div className={styles.feld}>
          <label className={styles.label} htmlFor={werteId}>
            Erlaubte Werte
          </label>
          <textarea
            id={werteId}
            name="allowedValues"
            className={styles.eingabe}
            rows={3}
            placeholder={"A\nB\nC"}
          />
          <span className={styles.notiz}>Ein Wert je Zeile.</span>
        </div>
      )}

      {ergebnis && !ergebnis.ok ? (
        <p className={styles.fehler} role="alert">
          {ergebnis.error}
        </p>
      ) : null}

      <button type="submit" className={styles.neben} disabled={laeuft}>
        {laeuft ? "Wird angelegt …" : "Hinzufügen"}
      </button>
      <p className={styles.notiz}>
        Der Parameter hängt am Modell, nicht an einem einzelnen Gerät. Jedes
        baugleiche Gerät trägt ihn danach mit.
      </p>
    </form>
  );
}

/** Der einzige Weg, ein Altmodell im Gang zu vervollstaendigen. */
export function FotoNachreichen({
  studioId,
  modelId,
  hatFoto,
}: {
  studioId: string;
  modelId: string;
  hatFoto: boolean;
}) {
  const id = useId();
  const [fehler, setFehler] = useState<string | null>(null);
  const [laeuft, starte] = useTransition();
  const eingabe = useRef<HTMLInputElement>(null);

  return (
    <div style={{ flexShrink: 0 }}>
      <label className={styles.nebenSchmal} htmlFor={id}>
        {laeuft ? "…" : hatFoto ? "Ersetzen" : "Aufnehmen"}
      </label>
      <input
        ref={eingabe}
        id={id}
        type="file"
        accept="image/jpeg,image/png"
        capture="environment"
        aria-label={hatFoto ? "Foto ersetzen" : "Foto nachreichen"}
        style={{ display: "none" }}
        onChange={(ereignis) => {
          const datei = ereignis.target.files?.[0];
          if (!datei) return;
          const formData = new FormData();
          formData.set("photo", datei);
          setFehler(null);
          starte(async () => {
            const antwort = await fotoNachreichen(
              studioId,
              modelId,
              null,
              formData,
            );
            if (eingabe.current) eingabe.current.value = "";
            if (!antwort.ok) setFehler(antwort.error);
          });
        }}
      />
      {fehler ? (
        <span className={styles.fehler} role="alert">
          {fehler}
        </span>
      ) : null}
    </div>
  );
}

export function ParameterLoeschen({
  studioId,
  modelId,
  settingId,
}: {
  studioId: string;
  modelId: string;
  settingId: string;
}) {
  const [fehler, setFehler] = useState<string | null>(null);
  const [laeuft, starte] = useTransition();

  return (
    <span style={{ flexShrink: 0 }}>
      {fehler ? (
        <span className={styles.fehler} role="alert">
          {fehler}
        </span>
      ) : null}
      <button
        type="button"
        className={styles.nebenSchmal}
        disabled={laeuft}
        aria-label="Parameter entfernen"
        onClick={() => {
          setFehler(null);
          starte(async () => {
            const antwort = await parameterLoeschen(
              studioId,
              modelId,
              settingId,
            );
            if (!antwort.ok) setFehler(antwort.error);
          });
        }}
      >
        {laeuft ? "…" : "Entfernen"}
      </button>
    </span>
  );
}

function Feld({
  name,
  label,
  hinweis,
  ...rest
}: {
  name: string;
  label: string;
  hinweis?: string;
} & React.InputHTMLAttributes<HTMLInputElement>) {
  const id = useId();
  return (
    <div className={styles.feld}>
      <label className={styles.label} htmlFor={id}>
        {label}
      </label>
      <input id={id} name={name} className={styles.eingabe} {...rest} />
      {hinweis ? <span className={styles.notiz}>{hinweis}</span> : null}
    </div>
  );
}
