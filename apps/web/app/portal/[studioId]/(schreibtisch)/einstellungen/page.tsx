import { DomainError, getStudioSettings } from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { Reiter } from "../../../bausteine/Reiter";
import styles from "../../../portal.module.css";
import { BeitrittscodeKarte, StudioFormular } from "./EinstellungenActions";

/**
 * Die beiden Reiter sind zwei Routen und zwei Server-Komponenten. Welche
 * gerade offen ist, weiss jede von sich selbst -- `aktiv` ist deshalb eine
 * Konstante und kein usePathname im Browser.
 */
function reiterEintraege(basis: string) {
  return [
    { href: basis, label: "Studio", aktiv: true },
    { href: `${basis}/konto`, label: "Konto", aktiv: false },
  ];
}

export default async function EinstellungenPage({
  params,
}: {
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;
  const client = await createServerSupabaseClient();
  const pfad = `/portal/${studioId}/einstellungen`;

  let einstellungen: Awaited<ReturnType<typeof getStudioSettings>>;
  try {
    einstellungen = await getStudioSettings(client, studioId);
  } catch (fehler) {
    // Wie in leute/page.tsx: das Layout prueft nur Mitgliedschaft, nicht
    // Rolle -- diese Seite muss sich selbst sperren, sonst laedt sie
    // darunter den echten Beitrittscode.
    if (fehler instanceof DomainError && fehler.code === "unauthorized") {
      return (
        <>
          <h1 className={styles.pageTitle}>Einstellungen</h1>
          {/* Der Reiter gehoert auch in diese Antwort: er ist der einzige
              Weg zu /einstellungen/konto, und das Konto geht jeden etwas
              an. Ohne ihn endete ein einfaches Mitglied hier in einer
              Sackgasse -- und ein stummer Deaktiviert-Zustand ist nach
              Spec Abschnitt 5 keiner. */}
          <Reiter name="Einstellungen" eintraege={reiterEintraege(pfad)} />
          <div className={styles.section}>
            <div className={styles.empty}>
              <p className={styles.emptyTitle}>
                Die Studiodaten sind Trainern und Inhabern vorbehalten.
              </p>
              <p className={styles.emptyNext}>
                Dein eigenes Passwort änderst du unter <em>Konto</em>. Für
                alles am Studio frag jemanden mit Trainerrolle.
              </p>
            </div>
          </div>
        </>
      );
    }
    // Sonst: was falsch ist und was gilt, auf der Seite selbst -- nicht die
    // Standardseite von Next. Solange 0032 irgendwo nicht eingespielt ist,
    // ist das der 42703 auf cancellation_deadline_hours und damit kein
    // seltener Sonderfall.
    return (
      <>
        <h1 className={styles.pageTitle}>Einstellungen</h1>
        <Reiter name="Einstellungen" eintraege={reiterEintraege(pfad)} />
        <div className={styles.section}>
          <div className={styles.empty}>
            <p className={styles.error}>
              {fehler instanceof DomainError
                ? fehler.message
                : "Die Einstellungen liessen sich nicht laden."}
            </p>
            <p className={styles.emptyNext}>
              Nichts ist geändert worden. Der Beitrittscode gilt unverändert
              weiter; unter <em>Konto</em> kommst du trotzdem an dein Passwort.
            </p>
          </div>
        </div>
      </>
    );
  }

  // Die Auswahl kommt aus derselben Quelle, gegen die die Fachschicht beim
  // Speichern prueft (Intl) -- eine zweite, eigene Liste liefe irgendwann
  // auseinander. Der gespeicherte Wert steht auch dann drin, wenn diese
  // Node-Fassung ihn nicht mehr kennt: sonst zeigte die Auswahl stumm eine
  // andere Zeitzone an, als das Studio hat.
  const zeitzonen = Intl.supportedValuesOf("timeZone");
  const auswahl = zeitzonen.includes(einstellungen.timezone)
    ? zeitzonen
    : [einstellungen.timezone, ...zeitzonen];

  return (
    <>
      <h1 className={styles.pageTitle}>Einstellungen</h1>
      <p className={styles.pageLead}>
        Stammdaten des Studios, die Regel für Kurse und der Code, mit dem
        Mitglieder beitreten.
      </p>

      <Reiter name="Einstellungen" eintraege={reiterEintraege(pfad)} />

      <StudioFormular
        studioId={studioId}
        pfad={pfad}
        name={einstellungen.name}
        zeitzone={einstellungen.timezone}
        zeitzonen={auswahl}
        stornofristStunden={einstellungen.cancellationDeadlineHours}
      />

      <BeitrittscodeKarte
        studioId={studioId}
        pfad={pfad}
        code={einstellungen.joinCode}
        active={einstellungen.joinCodeActive}
      />
    </>
  );
}
