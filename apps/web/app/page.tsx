import { redirect } from "next/navigation";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { BeitrittsFormular } from "./BeitrittsFormular";
import { Einstieg } from "./einstieg/Einstieg";
import einstiegStyles from "./einstieg/einstieg.module.css";
import { Startseite } from "./landung/Startseite";

export default async function HomePage() {
  const supabase = await createServerSupabaseClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  // Ohne Sitzung: die Landeseite fuer Mitglieder (Spec 2026-10-03, Etappe 1).
  // Bis dahin stand hier die Trainer-Landung aus Start.dc.html mit dem Satz
  // "im Web gibt es nichts fuer dich zu tun" -- der faellt weg, weil die
  // Seite jetzt Mitglieder anspricht. Trainer finden Anmelden im Kopf.
  if (!user) return <Startseite />;

  // Wer den Katalog pflegt, gehoert ins Portal. Wer keine Mitarbeiterrolle
  // hat, bleibt hier -- das ist der Mitgliedsbildschirm (KeinStudio.dc.html,
  // untere Haelfte): entweder das Beitrittsformular oder, sobald ein Studio
  // steht, dessen Liste.
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
  const hatStudio = Boolean(studios && studios.length > 0);

  // Fix-Runde 1 (Aufgabe 11): Titel und Vorspann muessen in beiden
  // Zweigen wahr sein. "Noch kein Studio" stimmt nur, solange die Liste
  // leer ist -- darueber stand er vorher auch dann, wenn sie es nicht war.
  // KeinStudio.dc.html zeichnet nur den leeren Fall; der Kernsatz ("Das
  // Portal ist fuer Studios, trainiert wird in der App") gilt fuer beide,
  // nur der Beitrittsteil setzt voraus, dass noch kein Studio dabeisteht.
  const titel = hatStudio ? "Deine Studios" : "Noch kein Studio";
  const vorspann = hatStudio
    ? "Das Portal ist für Studios. Trainieren läuft in der App."
    : "Du wolltest trainieren? Das Portal ist für Studios. Trainieren läuft in der App — dort trittst du deinem Studio bei, indem du den Aushang am Eingang oder den Aufkleber an einem Gerät scannst.";

  return (
    <Einstieg titel={titel} vorspann={vorspann}>
      <p data-testid="user-email" className={einstiegStyles.hinweis}>
        {user.email}
      </p>
      {hatStudio ? (
        <ul data-testid="studio-list" className={einstiegStyles.felder}>
          {studios!.map((studio) => (
            <li key={studio.id}>{studio.name}</li>
          ))}
        </ul>
      ) : (
        /*
         * Der Studio-Code steht hier gegen die Canvas-Notiz note-einstieg, die ihn
         * aus dem Web streichen will. Der Grund ist kein Widerspruch, sondern eine
         * Reihenfolge: den Beitritt soll die iOS-App tragen (Scan des Aushangs
         * oder des Aufklebers), und die ist Phase 6 -- apps/ enthaelt nur web.
         * Faellt das Formular vorher, gibt es im ganzen Produkt keinen
         * Beitrittsweg mehr.
         *
         * Auslöser fuer den Rueckbau ist die App, kein Datum.
         */
        <BeitrittsFormular />
      )}
    </Einstieg>
  );
}
