import Link from "next/link";
import { erreichbarkeit, ladeKatalog, railZahlen } from "../../catalog";
import { offenePunkte } from "../../offen";
import { Seite } from "../../../bausteine/Seite";
import { Abschnitt } from "../../../bausteine/Abschnitt";
import { Zeile, Zeilen } from "../../../bausteine/Zeile";
import { Zustand } from "../../../bausteine/Zustand";
import { Modellbild } from "../../../bausteine/Modellbild";
import { StiftLink } from "../../../bausteine/Stift";
import styles from "../../../portal.module.css";
import bausteine from "../../../bausteine/bausteine.module.css";

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
      {/*
        Ein Link auf den eigenen Ablauf statt eines aufklappenden Formulars
        ueber der Liste (Testnotiz 23.09., #7): beim Anlegen sollen die
        anderen Geraete nicht darunter stehen, und nach den Stammdaten
        geht es mit "Weiter" durch Einstellungen, Uebungen und Geraete.
      */}
      <div className={bausteine.hinzufuegenLeiste}>
        <Link href={`/portal/${studioId}/geraete/neu`} className={styles.primary}>
          + Gerät hinzufügen
        </Link>
      </div>

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
              const offen = offenePunkte(studioId, modell);

              return (
                <Zeile
                  key={modell.id}
                  bild={
                    <Modellbild
                      url={modell.photoPath ? katalog.photoUrls[modell.photoPath] : undefined}
                      name={modell.name}
                      leerText="Kein Foto"
                      groesse="zeile"
                    />
                  }
                  titel={modell.name}
                  meta={
                    // Zwei Zeilen statt einer Kette aus fuenf durch Punkte
                    // getrennten Tatsachen: die erste sagt, was im Raum
                    // steht, die zweite, ob das Modell fertig ist. Vorher
                    // stand beides in einem Lauf, und was davon ein Mangel
                    // war, musste man Wort fuer Wort lesen.
                    <>
                      <span>
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
                      </span>
                      {/* Offenes zaehlt die Marke am Stift (Testnotiz
                          23.09., #3) -- der orange Hinweis hier stand
                          doppelt. Nur "fertig" bekommt noch eine Zeile. */}
                      {offen.length === 0 ? (
                        <span className={styles.zeileZustand}>Fertig eingerichtet</span>
                      ) : null}
                    </>
                  }
                  aktionenOben
                  aktionen={
                    // Ein Stift oben rechts statt des breiten Knopfs
                    // "Bearbeiten" (Testnotiz 22.09., #1), mit der Zahl
                    // offener Punkte als gruene Marke (23.09., #3). Der Modellname
                    // steht im aria-label -- eine Liste aus lauter gleichen
                    // Stiften sagt einem Screenreader sonst nicht, welche
                    // Zeile gemeint ist.
                    <StiftLink
                      href={`/portal/${studioId}/geraete/${modell.id}`}
                      label={`${modell.name} bearbeiten`}
                      offen={offen.length}
                    />
                  }
                />
              );
            })}
          </Zeilen>
        )}
      </Abschnitt>
    </Seite>
  );
}
