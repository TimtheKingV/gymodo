import Link from "next/link";
import { redirect } from "next/navigation";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { BeitrittsFormular } from "./BeitrittsFormular";
import styles from "./einstieg/landeseite.module.css";

export default async function HomePage() {
  const supabase = await createServerSupabaseClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  // Bis zum 3. September stand hier nur "Nicht angemeldet." -- die
  // M0-Rauchprobe ohne Stylesheet und ohne einen Weg weiter. Diese Seite ist
  // die Landeseite (Start.dc.html): Wortmarke und Anmelden im Kopf, eine
  // Satzzeile ueber drei Zeilen, ein Absatz, zwei Aktionen, ein Hinweis fuer
  // Mitglieder und die Produktgrenze im Fuss.
  if (!user) {
    return (
      <div className={styles.bildschirm}>
        <header className={styles.kopf}>
          <span className={styles.marke}>gymodo</span>
          <Link href="/login" className={styles.anmeldenKopf}>
            Anmelden
          </Link>
        </header>
        <main className={styles.inhalt}>
          <div className={styles.spalte}>
            <h1 className={styles.titel}>
              Dein Studio,
              <br />
              am Gerät
              <br />
              erklärt.
            </h1>
            <p className={styles.vorspann}>
              Ein Tag am Gerät, ein Tap, und das Mitglied sieht die Einweisung, seine eigenen
              Einstellwerte und was es zuletzt geschafft hat. Du pflegst den Katalog hier.
            </p>
            <div className={styles.aktionen}>
              <Link href="/login" className={styles.knopf}>
                Als Trainer anmelden
              </Link>
            </div>
            <Link href="/registrieren" className={styles.nebenaktion}>
              Konto anlegen
            </Link>
            <p className={styles.mitgliedshinweis}>
              Du bist Mitglied? gymodo ist eine App fürs iPhone — im Web gibt es nichts für
              dich zu tun. Frag an der Theke nach der Einladung, oder tippe einfach ein Gerät
              an.
            </p>
          </div>
        </main>
        <footer className={styles.fuss}>
          gymodo misst nichts. Angezeigt wird ausschließlich, was Mitglieder selbst bestätigt
          haben. Einweisungsvideos und Einstellhinweise sind Inhalte des Studios, keine
          Trainings- oder Gesundheitsempfehlung von gymodo.
        </footer>
      </div>
    );
  }

  // Wer den Katalog pflegt, gehoert ins Portal -- diese Seite ist die
  // M0-Rauchprobe und traegt keinen Weg weiter. Bis zum 3. September landete
  // hier jeder Onboarding-Weg und endete: Adresse, Studioname, schwarz.
  //
  // Der Filter auf user_id ist noetig, seit memberships_select_staff (0031)
  // Mitarbeitern alle Zeilen ihres Studios zeigt -- ohne ihn zaehlte jeder
  // Kollege als eigene Mitgliedschaft. Dieselbe Falle wie in portal/page.tsx.
  const { data: personal, error: personalFehler } = await supabase
    .from("studio_memberships")
    .select("role")
    .eq("user_id", user.id)
    .in("role", ["trainer", "owner"])
    .limit(1);
  // Ohne dieses Log ist ein Fehlschlag hier von der urspruenglichen
  // Sackgasse nicht zu unterscheiden: personal bleibt null, die
  // Weiterleitung unterbleibt, und Personal landet still wieder auf dieser
  // Seite. Die Vercel-Logs sind dann die erste Adresse (Gesamtfahrplan 4b).
  if (personalFehler) console.error("Rollenpruefung auf / fehlgeschlagen:", personalFehler);
  if (personal && personal.length > 0) redirect("/portal");

  const { data: studios } = await supabase.from("studios").select("id, name");

  return (
    <main>
      <p data-testid="user-email">{user.email}</p>
      {studios && studios.length > 0 ? (
        <ul data-testid="studio-list">
          {studios.map((studio) => (
            <li key={studio.id}>{studio.name}</li>
          ))}
        </ul>
      ) : (
        <BeitrittsFormular />
      )}
    </main>
  );
}
