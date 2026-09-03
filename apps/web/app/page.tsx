import { redirect } from "next/navigation";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { BeitrittsFormular } from "./BeitrittsFormular";

export default async function HomePage() {
  const supabase = await createServerSupabaseClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return <p data-testid="anonymous">Nicht angemeldet.</p>;
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
