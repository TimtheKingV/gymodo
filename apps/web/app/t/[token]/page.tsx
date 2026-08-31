import { createClient } from "@supabase/supabase-js";
import {
  MEDIA_URL_TTL_SECONDS,
  PHOTO_BUCKET,
  VIDEO_BUCKET,
  hashTagToken,
  isValidTagToken,
  signMediaUrl,
  signMediaUrls,
} from "@fitretro/domain";
import { requiredEnv } from "@/lib/env";
import styles from "./fallback.module.css";

export const dynamic = "force-dynamic";

/**
 * Web-Fallback fuer Geraete-Tags.
 *
 * Diese Seite ist oeffentlich und zeigt niemals persoenliche Daten. Ein
 * unbekannter, ungueltiger und ein gesperrter Token liefern bewusst dieselbe
 * Antwort, damit sich gueltige Tokens nicht durch Ausprobieren unterscheiden
 * lassen.
 *
 * Was sie zeigt, ist Studioinhalt (Spec 6.4): Geraetename, Foto und die
 * Einweisungsvideos. Der Nutzen kommt vor der Installationsaufforderung --
 * damit wird aus einer Sackgasse ein Trichter, und er funktioniert auch auf
 * Android, wo es die App nicht gibt.
 */
type FallbackZeile = {
  machine_label: string;
  model_name: string;
  photo_path: string | null;
  exercises: Array<{ name: string; video_path: string | null }>;
};

export default async function TagFallbackPage({
  params,
}: {
  params: Promise<{ token: string }>;
}) {
  const { token } = await params;

  const unbekannt = (
    <main className={styles.neutral}>
      <h1 className={styles.neutralTitel} data-testid="tag-unknown">
        Dieser Code ist nicht aktiv.
      </h1>
      <p className={styles.neutralText}>Bitte wende dich an dein Studio.</p>
    </main>
  );

  if (!isValidTagToken(token)) return unbekannt;

  // Oeffentlicher Endpunkt ohne Nutzersession: der anonyme Schluessel
  // berechtigt zu nichts ausser dem Aufruf von resolve_tag_fallback
  // (SECURITY DEFINER) und dem Lesen genau der Medien, auf die gerade ein
  // aktiver Tag zeigt (is_media_published, Policy aus 0021).
  const client = createClient(
    requiredEnv("SUPABASE_URL"),
    requiredEnv("SUPABASE_ANON_KEY"),
    { auth: { persistSession: false } },
  );

  const { data } = await client.rpc("resolve_tag_fallback", {
    p_token_hash: hashTagToken(token),
  });

  const zeile = (data as FallbackZeile[] | null)?.[0];
  if (!zeile) return unbekannt;

  const videoPfade = zeile.exercises
    .map((uebung) => uebung.video_path)
    .filter((pfad): pfad is string => Boolean(pfad));

  const [fotoUrl, videoUrls] = await Promise.all([
    zeile.photo_path
      ? signMediaUrl(client, PHOTO_BUCKET, zeile.photo_path, MEDIA_URL_TTL_SECONDS)
      : Promise.resolve(null),
    signMediaUrls(client, VIDEO_BUCKET, videoPfade, MEDIA_URL_TTL_SECONDS),
  ]);

  return (
    <main className={styles.seite}>
      <header>
        <h1 className={styles.geraet} data-testid="machine-name">
          {zeile.model_name} {zeile.machine_label}
        </h1>
      </header>

      {fotoUrl ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          className={styles.foto}
          data-testid="machine-photo"
          src={fotoUrl}
          alt={`${zeile.model_name} ${zeile.machine_label}`}
        />
      ) : null}

      {zeile.exercises.length > 0 ? (
        <section className={styles.uebungen}>
          <h2 className={styles.label}>So stellst du dieses Gerät ein</h2>
          {zeile.exercises.map((uebung) => {
            const videoUrl = uebung.video_path
              ? (videoUrls.get(uebung.video_path) ?? null)
              : null;
            return (
              <article
                key={uebung.name}
                className={styles.uebung}
                data-testid={`exercise-${uebung.name}`}
              >
                <h3 className={styles.uebungName}>{uebung.name}</h3>
                {videoUrl ? (
                  <video
                    className={styles.video}
                    data-testid={`video-${uebung.name}`}
                    src={videoUrl}
                    controls
                    playsInline
                    preload="metadata"
                  />
                ) : (
                  // Vollstaendigkeit wird nie erzwungen (Spec 6.8): eine
                  // Uebung ohne Video steht trotzdem da.
                  <p className={styles.ohneVideo}>Für diese Übung gibt es kein Video.</p>
                )}
              </article>
            );
          })}
        </section>
      ) : null}

      <section className={styles.installieren}>
        <p className={styles.installierenText} data-testid="install-hint">
          Installiere die App, um deine Einstellungen und deinen Verlauf zu
          speichern.
        </p>
        <a className={styles.aktion} href="https://apps.apple.com/">
          App installieren
        </a>
      </section>

      <p className={styles.grenze}>
        gymodo misst nichts. Einweisungsvideos und Einstellhinweise sind Inhalte
        deines Studios, keine Trainings- oder Gesundheitsempfehlung von gymodo.
      </p>
    </main>
  );
}
