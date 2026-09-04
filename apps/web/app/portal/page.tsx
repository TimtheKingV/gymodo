import { redirect } from "next/navigation";
import Link from "next/link";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { Einstieg } from "../einstieg/Einstieg";
import einstiegStyles from "../einstieg/einstieg.module.css";
import { Seite } from "./bausteine/Seite";
import { Abschnitt } from "./bausteine/Abschnitt";
import { Zeile, Zeilen } from "./bausteine/Zeile";
import styles from "./portal.module.css";

/**
 * Einstieg ins Portal. Wer in genau einem Studio Trainer ist -- der
 * Normalfall -- landet direkt dort und sieht diese Seite nie.
 *
 * Zwei verschiedene Bildschirme auf einer Route, keine zwei Zustaende einer
 * Seite (Aufgabe-9-Brief): "kein Studio" ist ein Einstiegsbildschirm --
 * kein Kontext, keine Navigation, ein Satz -- und bekommt die `Einstieg`-
 * Huelle samt eigenem <main> (Aufgabe 6). Die Studiowahl ist eine Liste im
 * Portal, dafuer gibt es kein Artboard (Befund 15), deshalb nach den
 * Portal-Bausteinen gestaltet (Seite/Abschnitt/Zeilen/Zeile) statt nach
 * Vorlage. `Seite` rendert bewusst kein eigenes <main> (siehe Seite.tsx) --
 * das <main className={styles.content}> hier bleibt deshalb bestehen: die
 * Route liegt ausserhalb von (schreibtisch) und hat kein Layout, das die
 * Landmarke sonst setzt. Kein Zweig rendert beide zugleich.
 */
export default async function PortalPage() {
  const supabase = await createServerSupabaseClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  // memberships_select_staff (0031) laesst Mitarbeiter alle Zeilen ihres
  // Studios sehen, nicht nur die eigene -- ohne den user_id-Filter kaeme
  // hier fuer jeden Kollegen eine weitere Zeile desselben Studios zurueck.
  const { data: mitgliedschaften } = await supabase
    .from("studio_memberships")
    .select("role, studios (id, name)")
    .eq("user_id", user.id)
    .in("role", ["trainer", "owner"]);

  const studios = (mitgliedschaften ?? [])
    .map((zeile) => (zeile as unknown as { studios: { id: string; name: string } | null }).studios)
    .filter((studio): studio is { id: string; name: string } => studio !== null);

  if (studios.length === 1) redirect(`/portal/${studios[0]!.id}`);

  if (studios.length === 0) {
    // KeinStudio.dc.html, obere Haelfte -- wortgetreu. Die untere Haelfte
    // ("Du wolltest trainieren?") richtet sich an ein Mitglied, das nicht
    // hier landet, sondern auf "/": sie gehoert zu Aufgabe 11, nicht hierher.
    return (
      <Einstieg
        titel="Noch kein Studio"
        vorspann="Dein Konto steht. Ein Studio muss dich noch als Mitarbeiter hinzufügen — danach steht hier das Portal."
      >
        {/*
          KeinStudio.dc.html setzt hier 20px Abstand (margin: 20px 0 0), nicht
          die 24px von .fuss -- .hinweis selbst traegt keinen eigenen Abstand
          (siehe einstieg.module.css), deshalb hier explizit ueber das
          Abstandstoken statt eine neue Klasse fuer einen einzigen Fall.
        */}
        <p className={einstiegStyles.hinweis} style={{ marginTop: "var(--s20)" }}>
          Wer im Studio schon dabei ist, findet dich über deine E-Mail-Adresse unter{" "}
          <span className={einstiegStyles.betont}>Leute → Mitarbeiter</span>. Bis dahin gibt es
          hier nichts zu sehen — das ist keine Sperre, sondern die Wahrheit.
        </p>
      </Einstieg>
    );
  }

  return (
    <main className={styles.content}>
      <Seite
        titel="Studio wählen"
        vorspann="Du bist in mehreren Studios Trainer oder Inhaber. Wähle, mit welchem du weitermachst."
      >
        <Abschnitt titel="Studios">
          <Zeilen>
            {studios.map((studio) => (
              <Zeile
                key={studio.id}
                titel={studio.name}
                aktionen={
                  <Link className={styles.secondary} href={`/portal/${studio.id}`}>
                    Öffnen
                  </Link>
                }
              />
            ))}
          </Zeilen>
        </Abschnitt>
      </Seite>
    </main>
  );
}
