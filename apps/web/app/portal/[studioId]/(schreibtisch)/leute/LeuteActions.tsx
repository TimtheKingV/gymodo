"use client";

import { useId, useState, useTransition } from "react";
import type { StudioMember } from "@fitretro/domain";
import { AktionsKnopf } from "../../../Form";
import { mitgliedEntfernen, mitgliedRolleAendern } from "../../../actions";
import { Auswahl } from "../../../bausteine/Auswahl";
import { Zeile } from "../../../bausteine/Zeile";
import styles from "../../../portal.module.css";

const rollenLabel: Record<StudioMember["role"], string> = {
  owner: "Inhaber",
  trainer: "Trainer",
  member: "Mitglied",
};

/**
 * Der Satz, der beim Hochstufen zweimal dasteht: einmal als Fusssatz des
 * Reiters, einmal als Beschriftung des Bestaetigungsknopfes.
 *
 * Befund 23: vorher fragte der Knopf "Wirklich?". Ein Klick mehr ohne eine
 * Information mehr ist keine Bestaetigung -- Struktur-Spec Abschnitt 2
 * verlangt fuer das Hochstufen eine bestaetigte Handlung, und das ist eine
 * Handlung, die vorher sagt, was sie bedeutet.
 */
const HOCHSTUFEN_BESTAETIGUNG = "Hochstufen gibt Zugriff auf den ganzen Katalog.";

/**
 * Eine Zeile des Reiters Mitglieder: E-Mail, Beitrittsdatum, Entfernen.
 * Kein Rollenkennzeichen -- auf diesem Reiter steht ausschliesslich, wer
 * Mitglied ist, und ein Abzeichen, das an jeder Zeile dasselbe sagt, ist
 * keine Auskunft (LeuteMitglieder.dc.html zeichnet es ebenso wenig).
 */
export function MitgliedZeile({
  studioId,
  pfad,
  person,
  seit,
}: {
  studioId: string;
  pfad: string;
  person: StudioMember;
  seit: string;
}) {
  return (
    <Zeile
      titel={person.email}
      meta={seit}
      aktionen={
        <AktionsKnopf
          label="Entfernen"
          art="destructive"
          bestaetigung="Wirklich entfernen?"
          aktion={() => mitgliedEntfernen(studioId, pfad, person.userId)}
        />
      }
    />
  );
}

/**
 * Eine Zeile des Abschnitts "Alle Mitarbeiter".
 *
 * Befund 22 -- das eigentliche Loch dieser Aufgabe: bis hier bot diese
 * Zeile "Zu Mitglied zurueckstufen" auf JEDER Nicht-Inhaber-Zeile an, auch
 * auf der eigenen. Ein Trainer konnte sich damit selbst zum Mitglied
 * machen und verlor in demselben Klick das ganze Portal -- ohne einen Weg
 * zurueck, denn Rollen aendern darf nur Personal. Der Inhaber ist an zwei
 * Stellen geschuetzt (setMembershipRole nimmt "owner" als Zielrolle nicht
 * an, und memberships_update_staff aus 0031 laesst die Inhaberzeile nicht
 * zu); fuer die eigene Trainerzeile gab es nichts dergleichen.
 *
 * Hier steht jetzt "Das bist du" statt eines Knopfes, wie
 * LeuteMitarbeiter.dc.html es zeichnet. Das ist eine Oberflaeche, kein
 * Riegel: die Domaene laesst einen direkten Aufruf von
 * mitgliedRolleAendern(studioId, pfad, eigeneId, "member") weiterhin
 * durch. Fuer die Rechteverwaltung -- eine Trainerseite, kein
 * oeffentlicher Endpunkt -- ist das hier bewusst so; ein echter Riegel
 * gehoert in setMembershipRole und ist keine Aufgabe dieser Seite.
 *
 * Die Inhaberzeile traegt gar keine Aktion: RLS laesst sie ohnehin nicht
 * zu, und ein Knopf, der zuverlaessig scheitert, ist schlechter als
 * keiner.
 */
export function MitarbeiterZeile({
  studioId,
  pfad,
  person,
  seit,
  selbst,
}: {
  studioId: string;
  pfad: string;
  person: StudioMember;
  seit: string;
  selbst: boolean;
}) {
  return (
    <Zeile
      titel={
        <>
          <span className={`${styles.badge} ${styles.badgeActive}`}>
            {rollenLabel[person.role]}
          </span>{" "}
          {person.email}
        </>
      }
      meta={seit}
      aktionen={
        selbst ? (
          <span className={styles.rowMeta}>Das bist du</span>
        ) : person.role === "owner" ? null : (
          <AktionsKnopf
            label="Zum Mitglied herabstufen"
            art="destructive"
            bestaetigung="Wirklich herabstufen?"
            aktion={() => mitgliedRolleAendern(studioId, pfad, person.userId, "member")}
          />
        )
      }
    />
  );
}

/**
 * Der Abschnitt "Mitglied hochstufen": ein Auswahlfeld, ein Knopf.
 *
 * So zeichnet es LeuteMitarbeiter.dc.html -- EIN Feld mit Chevron auf
 * 44 px (Feldhoehe, nicht die 40 px einer Zeilenaktion) und EIN Knopf in
 * Akzentfarbe, nicht ein Knopf je Mitglied. Das Muster steht im Repo
 * schon: tags/TagBinden.tsx, Label, Auswahl, Knopf.
 *
 * Damit traegt dieser Reiter genau eine Akzentflaeche, gleich wie viele
 * Mitglieder das Studio hat -- die Regel aus Struktur-Spec Abschnitt 1
 * und die Zeichnung sagen dasselbe. Eine wiederholte Zeilenaktion haette
 * beides gegeneinandergestellt: bei zwoelf Mitgliedern gemessene acht
 * Akzentflaechen auf einem Bildschirm.
 *
 * Das Feld steht auf dem ersten Mitglied statt auf einem leeren
 * Platzhalter: ein deaktivierter Knopf traegt .primary:disabled und
 * damit KEINE Akzentflaeche mehr -- der Reiter haette seine eine Flaeche
 * genau so lange nicht, wie noch niemand ausgewaehlt hat. Vor dem
 * Versehen schuetzt die zweistufige Bestaetigung, nicht ein leeres Feld.
 */
export function MitgliedHochstufen({
  studioId,
  pfad,
  mitglieder,
}: {
  studioId: string;
  pfad: string;
  mitglieder: StudioMember[];
}) {
  const feldId = useId();
  const [gewaehlt, setGewaehlt] = useState(mitglieder[0]?.userId ?? "");
  const [bestaetigt, setBestaetigt] = useState(false);
  const [fehler, setFehler] = useState<string | null>(null);
  const [laeuft, starte] = useTransition();

  return (
    <>
      {fehler ? (
        <span className={styles.error} role="alert">
          {fehler}
        </span>
      ) : null}
      <div className={styles.field}>
        <label className={styles.label} htmlFor={feldId}>
          Mitglied
        </label>
        <Auswahl
          id={feldId}
          value={gewaehlt}
          onChange={(wert) => {
            setGewaehlt(wert);
            // Eine neue Auswahl nimmt die Bestaetigung zurueck: sonst
            // stuende der zweite Klick fuer eine andere Person als der
            // erste.
            setBestaetigt(false);
          }}
          optionen={mitglieder.map((person) => ({
            wert: person.userId,
            anzeige: person.email,
          }))}
        />
      </div>
      <div className={styles.actions}>
        <button
          type="button"
          className={styles.primary}
          disabled={laeuft}
          onClick={() => {
            if (!bestaetigt) {
              setBestaetigt(true);
              return;
            }
            setFehler(null);
            starte(async () => {
              const antwort = await mitgliedRolleAendern(studioId, pfad, gewaehlt, "trainer");
              setBestaetigt(false);
              if (!antwort.ok) setFehler(antwort.error);
            });
          }}
        >
          {laeuft
            ? "Wird gespeichert …"
            : bestaetigt
              ? HOCHSTUFEN_BESTAETIGUNG
              : "Zum Trainer machen"}
        </button>
      </div>
    </>
  );
}
