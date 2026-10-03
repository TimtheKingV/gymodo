"use client";

import styles from "./testnotiz.module.css";

/**
 * Ein eigenes Panel statt eines Menues aus der Seite: es muss ueber allem
 * liegen und darf keinen Klick zur Seite durchlassen, solange es offen ist.
 * Genau wie in der App.
 *
 * Die Zeilen richten sich danach, ob der Browser den Tab freigeben kann.
 * Am Rechner gibt es Ausschnitt und Seite, weil dort ein Foto entsteht; am
 * Handy fuehren beide Wege ins Notizblatt, wo der Tester seinen eigenen
 * Screenshot anhaengt.
 */
export function TestnotizMenue({
  titel,
  anzahl,
  fehler,
  bereit,
  laeuft,
  freigabe,
  beiAusschnitt,
  beiSeite,
  beiElement,
  beiNotiz,
  beiSitzung,
  beiFreigabe,
  beiSchliessen,
}: {
  titel: string;
  anzahl: number;
  fehler: string | null;
  bereit: boolean;
  laeuft: boolean;
  freigabe: boolean;
  beiAusschnitt: () => void;
  beiSeite: () => void;
  beiElement: () => void;
  beiNotiz: () => void;
  beiSitzung: () => void;
  beiFreigabe: () => void;
  beiSchliessen: () => void;
}) {
  return (
    <>
      <div className={styles.schleier} onClick={beiSchliessen} />
      <div className={styles.menue} role="dialog" aria-label="Testnotiz">
        <div className={styles.kopfzeile}>{titel}</div>

        {fehler ? <div className={styles.fehler}>{fehler}</div> : null}

        {!freigabe ? (
          <>
            <Zeile titel="Notiz" beiKlick={beiNotiz} />
            <Zeile titel="Element" beiKlick={beiElement} />
          </>
        ) : bereit ? (
          <>
            <Zeile titel="Ausschnitt" beiKlick={beiAusschnitt} />
            <Zeile titel="Seite" beiKlick={beiSeite} />
            <Zeile titel="Element" beiKlick={beiElement} />
            <Zeile titel="Nur Notiz" beiKlick={beiNotiz} />
          </>
        ) : laeuft ? (
          // Bis das Bild da ist, steht hier kein Angebot: "Bildschirm
          // freigeben" waere waehrend des Freigabedialogs schlicht falsch.
          <div className={`${styles.zeile} ${styles.zeileLeise}`}>Bild wird gemacht …</div>
        ) : (
          <Zeile titel="Bildschirm freigeben" beiKlick={beiFreigabe} />
        )}

        <Zeile titel={`Sitzung (${anzahl})`} beiKlick={beiSitzung} />
        <div className={styles.trenner} />
        <Zeile titel="Schließen" leise beiKlick={beiSchliessen} />
      </div>
    </>
  );
}

function Zeile({
  titel,
  leise = false,
  beiKlick,
}: {
  titel: string;
  leise?: boolean;
  beiKlick: () => void;
}) {
  return (
    <button
      type="button"
      className={leise ? `${styles.zeile} ${styles.zeileLeise}` : styles.zeile}
      onClick={beiKlick}
    >
      {titel}
    </button>
  );
}
