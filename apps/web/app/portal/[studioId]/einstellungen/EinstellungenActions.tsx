"use client";

import { useState } from "react";
import { AktionsFormular, AktionsKnopf, Feld } from "../../Form";
import { abmelden, beitrittscodeAktivSetzen, beitrittscodeErneuern, passwortAendern } from "../../actions";
import styles from "../../portal.module.css";

export function BeitrittscodeKarte({
  studioId,
  pfad,
  code,
  active,
}: {
  studioId: string;
  pfad: string;
  code: string;
  active: boolean;
}) {
  const [angezeigterCode, setAngezeigterCode] = useState(code);
  const [istAktiv, setIstAktiv] = useState(active);
  const [kopiert, setKopiert] = useState(false);

  return (
    <div className={styles.section}>
      <div className={styles.sectionHead}>
        <h2 className={styles.sectionTitle}>Studio-Code</h2>
      </div>
      <p className={styles.sectionNote}>
        Der zweite Weg ins Studio, wenn kein Aushangschild zur Hand ist:
        Mitglieder geben den Code in der App ein. Er macht niemanden zum
        Trainer — Mitarbeiter fügt ihr unter Leute hinzu.
      </p>
      <p className={styles.token}>
        {angezeigterCode}
        {istAktiv ? null : " · gesperrt"}
      </p>
      <div className={styles.rowActions}>
        <button
          type="button"
          className={styles.secondary}
          onClick={async () => {
            await navigator.clipboard.writeText(angezeigterCode);
            setKopiert(true);
          }}
        >
          {kopiert ? "Kopiert" : "Kopieren"}
        </button>
        <AktionsKnopf
          label="Neuen Code erzeugen"
          laufendLabel="Wird erzeugt …"
          bestaetigung="Wirklich? Der alte Code gilt dann nicht mehr."
          aktion={async () => {
            const antwort = await beitrittscodeErneuern(studioId, pfad);
            if (antwort.ok) {
              setAngezeigterCode(antwort.code);
              setIstAktiv(true);
              setKopiert(false);
              return { ok: true as const };
            }
            return antwort;
          }}
        />
        <AktionsKnopf
          label={istAktiv ? "Code sperren" : "Code entsperren"}
          art={istAktiv ? "destructive" : "secondary"}
          aktion={async () => {
            const antwort = await beitrittscodeAktivSetzen(studioId, pfad, !istAktiv);
            if (antwort.ok) setIstAktiv(!istAktiv);
            return antwort;
          }}
        />
      </div>
      <p className={styles.hint}>
        Ein neuer Code macht den alten sofort ungültig. Ausdrucke und Verträge
        mit dem alten Code funktionieren dann nicht mehr. Aushangschilder
        tragen keinen Code — sie bleiben gültig.
      </p>
    </div>
  );
}

export function PasswortAendernFormular() {
  const [fertig, setFertig] = useState(false);

  return (
    <div className={styles.section}>
      <div className={styles.sectionHead}>
        <h2 className={styles.sectionTitle}>Passwort ändern</h2>
      </div>
      {fertig ? (
        <p className={styles.sectionNote}>Das Passwort ist geändert.</p>
      ) : null}
      <AktionsFormular
        action={passwortAendern}
        submitLabel="Passwort ändern"
        onErfolg={() => setFertig(true)}
      >
        <div className={styles.grid}>
          <Feld name="aktuell" label="Aktuelles Passwort" type="password" required autoComplete="current-password" />
          <Feld
            name="neu"
            label="Neues Passwort"
            type="password"
            required
            autoComplete="new-password"
            hint="Mindestens zehn Zeichen. Keine Pflicht zu Sonderzeichen — Länge trägt weiter als Zeichenklassen."
          />
          <Feld name="wiederholung" label="Wiederholen" type="password" required autoComplete="new-password" />
        </div>
      </AktionsFormular>
    </div>
  );
}

export function AbmeldeKnopf() {
  return (
    <form action={abmelden}>
      <button type="submit" className={styles.secondary}>
        Abmelden
      </button>
    </form>
  );
}
