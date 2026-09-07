import Link from "next/link";
import { AktionsFormular, Feld } from "../../../Form";
import { modellAnlegen } from "../../../actions";
import { erreichbarkeit, ladeKatalog, railZahlen } from "../../catalog";
import { Seite } from "../../../bausteine/Seite";
import { Abschnitt } from "../../../bausteine/Abschnitt";
import { Zeile, Zeilen } from "../../../bausteine/Zeile";
import { Zustand } from "../../../bausteine/Zustand";
import styles from "../../../portal.module.css";

/**
 * Geraete und Modelle sind ein Bereich (Struktur-Spec, Entscheidung 5) --
 * diese Seite ist seine Startseite und zeigt die Modelle, gestaltet nach
 * Geraete.dc.html. Die vormals flache Geraeteliste (jedes Geraet quer ueber
 * alle Modelle) ist entfallen: ihre beiden Aktionen, Stilllegen und Wieder
 * in Betrieb, standen schon vorher zusaetzlich im Modell-Detail unter
 * "Geraete im Raum" (modelle/[modelId]/page.tsx, Abschnitt 4) -- geprueft
 * vor dem Loeschen, nicht nur behauptet. Die flache Liste war eine zweite
 * Kopie derselben Aktionen an einem Ort, den kein Artboard zeichnet.
 */
export default async function GeraetePage({
  params,
}: {
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;
  const [katalog, zahlen] = await Promise.all([ladeKatalog(studioId), railZahlen(studioId)]);

  // Der Gerätekatalog ist auf Datenbankebene fuer Mitglieder sichtbar:
  // equipment_models_select und die Machines-Police in 0004/0007 pruefen
  // is_studio_member, nicht is_studio_staff -- ein Mitglied bekommt
  // dieselben Zeilen wie ein Trainer. Diese Seite ist damit die EINZIGE
  // Sperre; RLS faengt hier nichts ab.
  //
  // Die Rolle steht trotzdem fest, nur aus einer anderen Ecke: railZahlen()
  // hat sie bereits ueber listStudioMembers geprueft (das wirft
  // "unauthorized" fuer ein Mitglied, im Unterschied zu getStudioCatalog)
  // und traegt sie als mitglieder === null, wenn das Konto sie nicht sehen
  // darf (RailZahlen in catalog.ts). Das ist eine bewusste Zwischenloesung,
  // keine geklaerte Frage: mitglieder === null heisst woertlich "darf die
  // Mitgliederliste nicht sehen", nicht "darf die Geräteliste nicht sehen"
  // -- es traegt nur, solange beide Seiten an derselben Rolle (Mitglied vs.
  // Trainer/Inhaber) haengen. Faechert sich die Rolle je feiner auf (etwa
  // "darf Geraete, aber nicht Leute sehen"), bricht diese Weiche lautlos in
  // die falsche Richtung -- ohne Typfehler und ohne roten Test. Dann
  // braucht es ein eigenes, direktes Signal statt dieser Kopplung.
  if (zahlen.mitglieder === null) {
    return (
      <Seite titel="Geräte">
        <Zustand
          art="keinRecht"
          titel="Die Geräteliste ist Trainern und Inhabern vorbehalten."
        />
      </Seite>
    );
  }

  return (
    <Seite
      titel="Geräte"
      vorspann="Ein Modell beschreibt den Gerätetyp. Die einzelnen Geräte im Raum sind Instanzen davon — zwei Kabelzüge nebeneinander sind ein Modell und zwei Geräte."
    >
      <Abschnitt titel="Alle Gerätemodelle">
        {katalog.models.length === 0 ? (
          <Zustand
            art="leer"
            titel="Noch kein Gerätemodell."
            naechsterSchritt="Fang mit dem Gerät an, das am häufigsten benutzt wird."
          />
        ) : (
          <Zeilen>
            {katalog.models.map((modell) => {
              const stand = erreichbarkeit(modell);
              const mitVideo = modell.exercises.filter((uebung) => uebung.hasVideo).length;
              const fotoDa = Boolean(modell.photoPath);
              const parameterAnzahl = modell.settingDefinitions.length;

              return (
                <Zeile
                  key={modell.id}
                  titel={modell.name}
                  meta={
                    <>
                      {modell.manufacturer ? (
                        modell.manufacturer
                      ) : (
                        <span className={styles.absent}>Ohne Hersteller</span>
                      )}
                      {" · "}
                      {stand.geraete === 0 ? (
                        <span className={styles.absent}>noch kein Gerät</span>
                      ) : (
                        `${stand.geraete} ${stand.geraete === 1 ? "Gerät" : "Geräte"}, ${stand.erreichbar} erreichbar`
                      )}
                      {" · "}
                      {modell.exercises.length === 0 ? (
                        <span className={styles.absent}>keine Übung</span>
                      ) : (
                        `${modell.exercises.length} ${modell.exercises.length === 1 ? "Übung" : "Übungen"}, ${mitVideo} mit Video`
                      )}
                      {" · "}
                      {!fotoDa && parameterAnzahl === 0 ? (
                        <span className={styles.absent}>kein Foto, keine Parameter</span>
                      ) : (
                        <>
                          {fotoDa ? "Foto" : <span className={styles.absent}>kein Foto</span>}
                          {" · "}
                          {parameterAnzahl > 0 ? (
                            `${parameterAnzahl} Parameter`
                          ) : (
                            <span className={styles.absent}>keine Parameter</span>
                          )}
                        </>
                      )}
                    </>
                  }
                  aktionen={
                    // "Bearbeiten" bleibt der sichtbare Text (Aufgabe 12) --
                    // aria-label ergaenzt den Modellnamen fuer den
                    // Accessibility-Baum, denn eine Liste mit lauter
                    // gleichlautenden "Bearbeiten"-Links sagt einem
                    // Screenreader nicht, welche Zeile gemeint ist.
                    <Link
                      className={styles.secondary}
                      href={`/portal/${studioId}/modelle/${modell.id}`}
                      aria-label={`${modell.name} bearbeiten`}
                    >
                      Bearbeiten
                    </Link>
                  }
                />
              );
            })}
          </Zeilen>
        )}
      </Abschnitt>

      {/*
        Bewusst kein Abschnitt-Baustein: AktionsFormular bringt sein eigenes
        styles.sectionBody-Polster mit, das zusammen mit Abschnitts eigenem
        Polster (abschnittRumpf) doppelt aufgetragen wuerde. Modell-Detail,
        Einstellungen und die Kurs-Formulare tragen ihre Eingabeformulare aus
        demselben Grund ebenfalls roh (styles.section), nicht im Baustein.
      */}
      <section className={styles.section} id="modell-anlegen">
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Modell anlegen</h2>
        </div>
        <AktionsFormular
          action={modellAnlegen.bind(null, studioId)}
          submitLabel="Modell anlegen"
        >
          <div className={styles.grid}>
            <Feld name="name" label="Name" required placeholder="Latzug" />
            <Feld name="manufacturer" label="Hersteller" placeholder="Technogym" />
            <Feld
              name="weightStepKg"
              label="Gewichtsschritt"
              required
              inputMode="decimal"
              placeholder="2,5"
              hint="In Kilogramm. So viel liegt zwischen zwei Steckplätzen."
            />
            <Feld
              name="minWeightKg"
              label="Minimum"
              inputMode="decimal"
              placeholder="5"
              hint="Leer lassen für 0."
            />
            <Feld
              name="maxWeightKg"
              label="Maximum"
              inputMode="decimal"
              placeholder="100"
              hint="Leer lassen, wenn kein Anschlag bekannt ist."
            />
          </div>
        </AktionsFormular>
      </section>
    </Seite>
  );
}
