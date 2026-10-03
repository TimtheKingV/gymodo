import { DomainError, listStaffInvites, type StaffInvite } from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { AktionsKnopf } from "../../../../Form";
import { einladungZurueckziehen } from "../../../../actions";
import { Abschnitt } from "../../../../bausteine/Abschnitt";
import { Erlaeuterung } from "../../../../bausteine/Erlaeuterung";
import { Reiter } from "../../../../bausteine/Reiter";
import { Seite } from "../../../../bausteine/Seite";
import { Zeile, Zeilen } from "../../../../bausteine/Zeile";
import { Zustand } from "../../../../bausteine/Zustand";
import { EinladungErstellen } from "../EinladungErstellen";
import { MitarbeiterZeile, MitgliedHochstufen } from "../LeuteActions";
import { ladeLeute, leuteReiter, seit } from "../leute";
import styles from "../../../../portal.module.css";

/**
 * Reiter "Mitarbeiter" (Aufgabe 19, LeuteMitarbeiter.dc.html) -- nach
 * Struktur-Spec Abschnitt 2 der heikelste Bildschirm des Portals: hier
 * wird die Rechteverwaltung bedient, und sie braucht "die entsprechende
 * Sorgfalt: bestaetigte Handlung beim Hochstufen, und niemand kann sich
 * selbst die letzte Inhaberrolle entziehen".
 *
 * Die Importe liegen eine Ebene tiefer als in leute/page.tsx (vier ../
 * statt drei) -- abgeschriebene Pfade kosteten in Aufgabe 17 vierzehn
 * TypeScript-Fehler, die wie Typprobleme aussahen.
 *
 * Der Untertitel folgt NICHT dem Artboard. Das zeichnet noch "Zugriff auf
 * alles ausser den Trainingsdaten der Mitglieder -- so ist es gedacht;
 * die Datenbank setzt diese Grenze noch nicht durch" (Befund 20). Seit
 * Migration 0033 setzt sie sie durch: die vier Select-Policies auf
 * workout_sessions, workout_sets, member_machine_calibrations und
 * progression_suggestions haben ihre "or is_studio_staff(...)"-Klausel
 * verloren. Der Satz hier sagt deshalb, was gilt -- und er sagt es ueber
 * EIN Mitglied, nicht ueber das Studio: studio_overview (0034) gibt
 * Personal weiterhin Summen heraus, davon lebt der Ueberblick. "Das
 * Portal zeigt keine Trainingsdaten" waere falsch.
 *
 * Seit der Testnotiz 25.09. (#6) steht hier "Mitarbeiter einladen": ein
 * Link fuer eine Person, sieben Tage gueltig (0045). Darunter die offenen
 * Einladungen, jede zurueckziehbar. Der Weg ueber Studio-Code und
 * Hochstufen bleibt, ist aber nicht mehr der erste.
 */

/** "3. Oktober" in der Studio-Zeitzone (Designsystem 10). */
function tag(iso: string, timeZone: string): string {
  return new Date(iso).toLocaleDateString("de-DE", { day: "numeric", month: "long", timeZone });
}
export default async function LeuteMitarbeiterPage({
  params,
}: {
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;
  const daten = await ladeLeute(studioId);

  // Der Revalidierungspfad zeigt auf DIESEN Reiter, nicht auf
  // /portal/<id>/leute: mitgliedRolleAendern bekommt ihn von der Seite,
  // und die Seite, die nach der Aktion frisch sein muss, ist diese.
  const pfad = `/portal/${studioId}/leute/mitarbeiter`;

  if (daten.keinRecht) {
    return (
      <Seite titel="Mitarbeiter">
        <Zustand art="keinRecht" titel="Diese Seite ist Trainern und Inhabern vorbehalten." />
      </Seite>
    );
  }

  // Die offenen Einladungen. Ein Fehler hier nimmt der Seite nicht die
  // Mitarbeiterliste -- er steht im eigenen Abschnitt.
  let einladungen: StaffInvite[] = [];
  let einladungenFehler: string | null = null;
  try {
    einladungen = await listStaffInvites(await createServerSupabaseClient(), studioId);
  } catch (e) {
    einladungenFehler =
      e instanceof DomainError ? e.message : "Die Einladungen ließen sich nicht laden.";
  }

  return (
    <Seite
      titel="Mitarbeiter"
      vorspann="Mitarbeiter pflegen den Katalog und sehen die Mitgliederliste. Trainingsdaten eines Mitglieds sieht nur das Mitglied selbst. Das Portal legt eine Mitgliedschaft an und beendet sie, sonst nichts."
    >
      <Reiter name="Leute" eintraege={leuteReiter(studioId, daten, "mitarbeiter")} />

      <Abschnitt titel="Alle Mitarbeiter">
        {daten.fehler ? (
          <Zustand art="fehler" titel={daten.fehler} />
        ) : daten.mitarbeiter.length === 0 ? (
          // Praktisch unerreichbar -- wer diese Seite sieht, steht selbst
          // in dieser Liste. Ein stummer Leerlauf waere trotzdem der
          // falsche Ausgang (Designsystem 5).
          <Zustand
            art="leer"
            titel="Noch niemand pflegt dieses Studio."
            naechsterSchritt="Lade jemanden ein oder stuf ein Mitglied hoch, dann steht es hier."
          />
        ) : (
          <Zeilen>
            {daten.mitarbeiter.map((person) => (
              <MitarbeiterZeile
                key={person.userId}
                studioId={studioId}
                pfad={pfad}
                person={person}
                seit={seit(person.joinedAt, daten.zeitzone)}
                selbst={person.userId === daten.eigeneId}
              />
            ))}
          </Zeilen>
        )}
      </Abschnitt>

      <Abschnitt titel="Mitarbeiter einladen">
        <p className={styles.sectionNote}>
          Schick den Link an die Person, die mitarbeiten soll. Sie legt ein Konto an oder meldet
          sich an und ist danach Trainer.
        </p>
        <EinladungErstellen studioId={studioId} pfad={pfad} />
        {einladungenFehler ? (
          <Zustand art="fehler" titel={einladungenFehler} />
        ) : einladungen.length > 0 ? (
          <Zeilen>
            {einladungen.map((einladung) => (
              <Zeile
                key={einladung.id}
                titel={`Offene Einladung · gilt bis ${tag(einladung.expiresAt, daten.zeitzone)}`}
                meta={`Erstellt am ${tag(einladung.createdAt, daten.zeitzone)}`}
                aktionen={
                  <AktionsKnopf
                    label="Zurückziehen"
                    art="destructive"
                    bestaetigung="Link ungültig machen?"
                    aktion={einladungZurueckziehen.bind(null, studioId, pfad, einladung.id)}
                  />
                }
              />
            ))}
          </Zeilen>
        ) : null}
      </Abschnitt>

      <Abschnitt titel="Mitglied hochstufen">
        {daten.mitglieder.length === 0 ? (
          <Zustand
            art="leer"
            titel="Noch kein Mitglied, das sich hochstufen ließe."
            naechsterSchritt="Mitglieder treten über den Studio-Code bei."
          />
        ) : (
          // Keine Kuerzung und kein ?alle=1 auf diesem Reiter: ein
          // Auswahlfeld haelt auch 24 Mitglieder, ohne den Bildschirm zu
          // fluten. Die Kuerzung bleibt dort, wo sie etwas kuerzt -- auf
          // dem Reiter Mitglieder, der die Liste selbst zeigt.
          <MitgliedHochstufen studioId={studioId} pfad={pfad} mitglieder={daten.mitglieder} />
        )}
      </Abschnitt>

      <Erlaeuterung>
        Hochstufen gibt Zugriff auf den ganzen Katalog. Der Studio-Code macht niemanden
        zum Trainer.
      </Erlaeuterung>
    </Seite>
  );
}
