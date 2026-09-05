"use client";

import type { StudioMember } from "@fitretro/domain";
import { AktionsKnopf } from "../../../Form";
import { mitgliedEntfernen, mitgliedRolleAendern } from "../../../actions";
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
 * Eine Zeile des Abschnitts "Mitglied hochstufen".
 *
 * Nebenaktion, KEINE Akzentflaeche -- das ist die eine Stelle, an der
 * diese Seite dem Artboard bewusst nicht folgt.
 * LeuteMitarbeiter.dc.html zeichnet "Zum Trainer machen" in Akzentfarbe
 * und ist damit in sich stimmig: es zeichnet genau EIN Mitglied. Real
 * sind es 24. Gemessen am 5. September, Studio mit zwoelf Mitgliedern und
 * der Kuerzung bei acht: acht Akzentflaechen auf einem Bildschirm -- die
 * Regel "genau eine Akzentflaeche je Bildschirm" (Struktur-Spec
 * Abschnitt 1, gemessen von akzentflaechen() in e2e/helpers/abnahme.ts)
 * ist mit einer wiederholten Zeilenaktion nicht zu haben.
 *
 * Aufgeloest wird das zugunsten der Regel, nicht der Zeichnung: dieser
 * Reiter traegt null Akzentflaechen, wie die Tags-Seite aus Aufgabe 5 --
 * der Praezedenzfall, den auch der Auftrag zu dieser Aufgabe nennt. Er
 * legt nichts an; er verwaltet Rechte. Die beiden Rollenaktionen
 * unterscheiden sich trotzdem sichtbar: Hochstufen ist eine Nebenaktion,
 * Herabstufen eine zerstoerende.
 */
export function HochstufenZeile({
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
          label="Zum Trainer machen"
          bestaetigung={HOCHSTUFEN_BESTAETIGUNG}
          aktion={() => mitgliedRolleAendern(studioId, pfad, person.userId, "trainer")}
        />
      }
    />
  );
}
