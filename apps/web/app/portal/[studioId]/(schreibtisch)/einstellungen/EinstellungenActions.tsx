"use client";

import { useActionState, useId, useState } from "react";
import { useFormStatus } from "react-dom";
import { AktionsFormular, AktionsKnopf, Feld } from "../../../Form";
import { Auswahl } from "../../../bausteine/Auswahl";
import type { ActionResult } from "../../../actions";
import {
  abmelden,
  beitrittscodeAktivSetzen,
  beitrittscodeErneuern,
  passwortAendern,
  studioSpeichern,
} from "../../../actions";
import styles from "../../../portal.module.css";

/**
 * Stammdaten und Stornofrist: zwei Karten, ein Formular, ein Knopf.
 *
 * Warum nicht AktionsFormular aus Form.tsx -- das setzt den Absendeknopf
 * hinter alle Kinder und traegt selbst die Kartenpolsterung
 * (.sectionBody). Hier spannt ein <form> ueber zwei Karten, "Stammdaten"
 * und "Kurse", so wie EinstellungenStudio.dc.html sie zeichnet, und der
 * Knopf gehoert in die erste. Ein zweiter Knopf unter "Kurse" waere das
 * zweite Formular auf dem Bildschirm und damit die zweite Akzentflaeche;
 * ein Feld ganz ohne Speicherweg waere unbedienbar. Also eines fuer
 * beides.
 */
export function StudioFormular({
  studioId,
  pfad,
  name,
  zeitzone,
  zeitzonen,
  stornofristStunden,
}: {
  studioId: string;
  pfad: string;
  name: string;
  zeitzone: string;
  zeitzonen: string[];
  stornofristStunden: number;
}) {
  const [ergebnis, formAction] = useActionState(
    async (prev: ActionResult | null, formData: FormData) =>
      await studioSpeichern(studioId, pfad, prev, formData),
    null,
  );
  const zeitzoneId = useId();
  const [gewaehlteZeitzone, setGewaehlteZeitzone] = useState(zeitzone);
  const fristId = useId();
  const fristHinweisId = `${fristId}-hinweis`;

  return (
    <form action={formAction}>
      <section className={styles.section}>
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Stammdaten</h2>
        </div>
        <div className={styles.sectionBody}>
          <Feld name="name" label="Name" required defaultValue={name} />
          <div className={styles.field}>
            <label className={styles.label} htmlFor={zeitzoneId}>
              Zeitzone
            </label>
            {/* Eine Auswahl, kein Textfeld: die Zeitzone wird gegen die
                Liste des Laufzeitsystems geprueft (domain/studio.ts), und
                eine getippte Zeitzone, die es nicht gibt, ist kein
                Tippfehler mit Warnung, sondern eine Kursanzeige, die
                spaeter auflaeuft. Was nur eine feste Menge Werte annehmen
                kann, waehlt man. */}
            <Auswahl
              id={zeitzoneId}
              name="timezone"
              value={gewaehlteZeitzone}
              onChange={setGewaehlteZeitzone}
              optionen={zeitzonen.map((zone) => ({ wert: zone, anzeige: zone }))}
            />
            <span className={styles.hint}>
              Sie bestimmt, wann ein Kurstermin beginnt.
            </span>
          </div>
          {ergebnis && !ergebnis.ok ? (
            <p className={styles.error} role="alert">
              {ergebnis.error}
            </p>
          ) : null}
          <div className={styles.actions}>
            <Absenden />
          </div>
        </div>
      </section>

      <section className={styles.section}>
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Kurse</h2>
        </div>
        <div className={styles.sectionBody}>
          <div className={styles.field}>
            <label className={styles.label} htmlFor={fristId}>
              Stornofrist
            </label>
            <div className={styles.inlineFeld}>
              <input
                id={fristId}
                name="cancellationDeadlineHours"
                className={`${styles.input} ${styles.schmalesFeld}`}
                inputMode="numeric"
                required
                defaultValue={String(stornofristStunden)}
                aria-describedby={fristHinweisId}
              />
              <span className={styles.einheit}>Stunden vor Beginn</span>
            </div>
            <span id={fristHinweisId} className={styles.hint}>
              Bis wann sich ein Mitglied abmelden kann. Das ist eure Regel,
              keine Vorgabe von gymodo. 0 heißt: bis zum Beginn. Gespeichert
              wird sie mit den Stammdaten darüber.
            </span>
          </div>
        </div>
      </section>
    </form>
  );
}

function Absenden() {
  const { pending } = useFormStatus();
  return (
    <button type="submit" className={styles.primary} disabled={pending}>
      {pending ? "Wird gespeichert …" : "Änderungen speichern"}
    </button>
  );
}

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
    <section className={styles.section}>
      <div className={styles.sectionHead}>
        <h2 className={styles.sectionTitle}>Studio-Code</h2>
      </div>
      <div className={styles.sectionBody}>
        <p className={styles.token}>
          {angezeigterCode}
          {istAktiv ? null : " · gesperrt"}
        </p>
        <p className={styles.sectionNote}>
          Der zweite Weg ins Studio, wenn kein Aushangschild zur Hand ist:
          Mitglieder geben den Code in der App ein. Er macht niemanden zum
          Trainer — Mitarbeiter fügt ihr unter Leute hinzu.
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
        {/* Ein Warnkasten, kein Fliesstext: der Satz kuendigt eine Folge
            an, die kein Zurueck hat. Der letzte Halbsatz ist der
            eigentliche -- er sagt, was NICHT kaputtgeht, und nimmt der
            Handlung die Angst. Er steht auf der Seite, nicht erst in der
            Bestaetigung: wer erst im zweiten Klick erfaehrt, was er
            anrichtet, hat schon einmal geklickt. */}
        <p className={styles.warning}>
          Ein neuer Code macht den alten sofort ungültig. Ausdrucke und
          Verträge mit dem alten Code funktionieren dann nicht mehr.
          Aushangschilder tragen keinen Code — sie bleiben gültig.
        </p>
      </div>
    </section>
  );
}

export function PasswortAendernFormular() {
  const [fertig, setFertig] = useState(false);

  return (
    <section className={styles.section}>
      <div className={styles.sectionHead}>
        <h2 className={styles.sectionTitle}>Passwort ändern</h2>
        {fertig ? (
          <span className={styles.sectionNote}>Das Passwort ist geändert.</span>
        ) : null}
      </div>
      <AktionsFormular
        action={passwortAendern}
        submitLabel="Passwort ändern"
        onErfolg={() => setFertig(true)}
      >
        <Feld
          name="aktuell"
          label="Aktuelles Passwort"
          type="password"
          required
          autoComplete="current-password"
        />
        <Feld
          name="neu"
          label="Neues Passwort"
          type="password"
          required
          autoComplete="new-password"
          hint="Mindestens zehn Zeichen. Keine Pflicht zu Sonderzeichen — Länge trägt weiter als Zeichenklassen."
        />
        <Feld
          name="wiederholung"
          label="Wiederholen"
          type="password"
          required
          autoComplete="new-password"
        />
      </AktionsFormular>
    </section>
  );
}

/**
 * Abmelden ist hier eine zerstoerende Aktion, keine Nebenaktion: auf einer
 * eigenen Karte unter eigener Ueberschrift sucht man diesen Knopf
 * absichtlich, und danach ist die Sitzung weg. So zeichnet ihn auch
 * EinstellungenKonto.dc.html (Umriss in --danger). Der zweite "Abmelden"
 * im Fuss der Rail bleibt, was er ist -- ein leiser Fusszeilenlink.
 */
export function AbmeldeKnopf() {
  return (
    <form action={abmelden}>
      <button type="submit" className={styles.destructive}>
        Abmelden
      </button>
    </form>
  );
}
