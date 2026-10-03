import Link from "next/link";
import { getStaffInviteInfo } from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { Einstieg } from "../../einstieg/Einstieg";
import styles from "../../einstieg/einstieg.module.css";
import { AnnehmenFormular } from "../AnnehmenFormular";
import { einladungsPfad } from "../weiter";

/**
 * Der Einladungslink (Testnotiz 25.09., #6 -- Moeglichkeit 2).
 *
 * Drei Faelle:
 * - Der Link gilt nicht (unbekannt, abgelaufen, benutzt, zurueckgezogen):
 *   ein Satz und was zu tun ist. Alle vier sehen gleich aus -- 0045 sagt
 *   warum.
 * - Nicht angemeldet: wer einlaedt und wozu, dazu Konto anlegen und
 *   Anmelden. Beide fuehren ueber ?weiter= hierher zurueck.
 * - Angemeldet: "Einladung annehmen", danach das Portal.
 *
 * Der Studioname kommt aus staff_invite_info, das auch anon lesen darf --
 * sonst stuende vor der Anmeldung nur "ein Studio".
 */
export default async function EinladungPage({
  params,
}: {
  params: Promise<{ token: string }>;
}) {
  const { token } = await params;
  const client = await createServerSupabaseClient();
  const info = await getStaffInviteInfo(client, token);

  if (!info) {
    return (
      <Einstieg
        titel="Diese Einladung gilt nicht mehr"
        vorspann="Sie ist abgelaufen, schon angenommen oder zurückgezogen worden. Bitte die Person, die dich eingeladen hat, um einen neuen Link."
      >
        <div className={styles.links}>
          <Link href="/">Zur Startseite</Link>
        </div>
      </Einstieg>
    );
  }

  const {
    data: { user },
  } = await client.auth.getUser();
  const weiter = encodeURIComponent(einladungsPfad(token));
  const bis = new Date(info.expiresAt).toLocaleDateString("de-DE", {
    day: "numeric",
    month: "long",
    timeZone: "Europe/Berlin",
  });

  return (
    <Einstieg
      titel={`Einladung zu ${info.studioName}`}
      vorspann={
        <>
          Du wirst Trainer bei <span className={styles.betont}>{info.studioName}</span>: du
          pflegst Geräte, Übungen und Kurse und siehst die Mitgliederliste. Der Link gilt bis
          zum {bis}.
        </>
      }
    >
      {user ? (
        <>
          <p className={styles.hinweis}>
            Angemeldet als <span className={styles.betont}>{user.email}</span>.
          </p>
          <AnnehmenFormular token={token} />
        </>
      ) : (
        <>
          <Link href={`/registrieren?weiter=${weiter}`} className={styles.knopf}>
            Konto anlegen
          </Link>
          <div className={styles.links}>
            <Link href={`/login?weiter=${weiter}`}>Schon ein Konto? Anmelden</Link>
          </div>
        </>
      )}
    </Einstieg>
  );
}
