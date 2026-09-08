"use client";

import { useActionState, useId, useState, useTransition } from "react";
import {
  fotoNachreichen,
  parameterAnlegen,
  parameterLoeschen,
} from "../../../actions";
import { FotoFeld } from "../../../../../bausteine/FotoFeld";
import { NameFeld, Rad } from "../../../../../bausteine/EinstellungRad";
import {
  einheitWerte,
  minMaxWerte,
  nameVorschlaege,
  schluesselAus,
  schrittWerte,
} from "../../../../../bausteine/einstellungVorschlaege";
import styles from "../../../halle.module.css";

/**
 * Zahleneinstellung und Auswahl brauchen verschiedene Felder -- ein Sitz
 * hat einen Bereich, eine Griffstellung eine Liste. Beides gleichzeitig zu
 * zeigen hiesse, den Trainer raten zu lassen, welche Haelfte gilt.
 *
 * Nur EIN Namensfeld statt Beschriftung + Schluessel (Befund: zwei Felder
 * fuer dieselbe Sache waren unnoetig) -- der Schluessel leitet sich aus
 * dem Namen ab (schluesselAus()). Der Bereich steht immer als Rad da,
 * 44 px statt 40 px Zeilenhoehe (einhaendig bedient, Designsystem 1) --
 * keine Vorgabe mit festem Bereich mehr davor (Trainer-Wunsch: "man muss
 * das einfach immer einstellen").
 *
 * Kein Akzent: der gehoert auf diesem Bildschirm dem "Weiter zum Geraet".
 */
export function EinstellungSheet({
  studioId,
  modelId,
}: {
  studioId: string;
  modelId: string;
}) {
  const [offen, setOffen] = useState(false);
  const [kind, setKind] = useState<"number" | "enum">("number");
  const [label, setLabel] = useState("");
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
        Einstellung hinzufügen
      </button>
    );
  }

  return (
    <form action={formAction} className={styles.karte}>
      <div className={styles.karteTitel}>Neue Einstellung</div>

      <input type="hidden" name="key" value={schluesselAus(label)} />
      <NameFeld
        name="label"
        label="Beschriftung"
        required
        placeholder="Sitzhöhe"
        value={label}
        onChange={setLabel}
        vorschlaege={nameVorschlaege()}
        hint="So steht sie später vor dem Mitglied am Gerät."
        gross
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
        <Rad
          gross
          spalten={[
            { name: "minValue", label: "Von", werte: minMaxWerte(), start: "0" },
            { name: "maxValue", label: "Bis", werte: minMaxWerte(), start: "10" },
            { name: "stepValue", label: "Schritt", werte: schrittWerte(), start: "1" },
            { name: "unit", label: "Einheit", werte: einheitWerte(), start: "" },
          ]}
        />
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
        Die Einstellung hängt am Modell, nicht an einem einzelnen Gerät. Jedes
        baugleiche Gerät trägt sie danach mit.
      </p>
    </form>
  );
}

/** Der einzige Weg, ein Altmodell im Gang zu vervollstaendigen. */
export function FotoNachreichen({
  studioId,
  modelId,
  hatFoto,
  fotoUrl,
}: {
  studioId: string;
  modelId: string;
  hatFoto: boolean;
  fotoUrl?: string | undefined;
}) {
  const [fehler, setFehler] = useState<string | null>(null);
  const [laeuft, starte] = useTransition();

  return (
    <div style={{ flexShrink: 0 }}>
      <FotoFeld
        mini
        vorhandeneUrl={fotoUrl}
        ausloeserText={laeuft ? "…" : hatFoto ? "Ersetzen" : "Aufnehmen"}
        ariaLabel={hatFoto ? "Foto ersetzen" : "Foto nachreichen"}
        onDatei={(datei) => {
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

export function EinstellungLoeschen({
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
        aria-label="Einstellung entfernen"
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
