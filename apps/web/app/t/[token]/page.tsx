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
  kind: "machine" | "studio";
  studio_name: string;
  // Bei kind "studio" hat der Tag kein Geraet -- diese drei sind dann null
  // (linker Join in resolve_tag_fallback).
  machine_label: string | null;
  model_name: string | null;
  photo_path: string | null;
  exercises: Array<{ name: string; video_path: string | null }>;
};

function CheckIcon() {
  return (
    <svg
      className={styles.nutzenIcon}
      width="20"
      height="20"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="m4.5 12.5 5 5 10-11" />
    </svg>
  );
}

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

  // Ein Aushang hat kein Geraet -- er zeigt das Studio, nicht eine
  // Geraeteseite ohne Geraet (Artboard 27, FallbackAushang.dc.html).
  if (zeile.kind === "studio") {
    return (
      <main className={styles.seite} data-testid="tag-aushang">
        <header>
          <span className={styles.label}>Aushang</span>
          <h1 className={styles.geraet}>{zeile.studio_name}</h1>
          <p className={styles.standort}>Dein Studio arbeitet mit gymodo.</p>
        </header>

        <section className={styles.nutzen}>
          <div className={styles.nutzenZeile}>
            <CheckIcon />
            <p className={styles.nutzenText}>
              <strong>Einweisung an jedem Gerät.</strong> Wie es eingestellt
              wird, als Video, direkt am Gerät.
            </p>
          </div>
          <div className={styles.nutzenZeile}>
            <CheckIcon />
            <p className={styles.nutzenText}>
              <strong>Deine Einstellungen bleiben.</strong> Sitzhöhe, Gewicht
              und die letzten Sätze — an jedem Gerät.
            </p>
          </div>
          <div className={styles.nutzenZeile}>
            <CheckIcon />
            <p className={styles.nutzenText}>
              <strong>Kurse buchen.</strong> Wochenplan, Anmeldung, Warteliste.
            </p>
          </div>
        </section>

        <section className={styles.installieren}>
          <p className={styles.schritteTitel}>In zwei Schritten dabei</p>
          <div className={styles.schritt}>
            <span className={styles.schrittNummer}>1</span>
            <span className={styles.schrittText}>
              App laden und Konto anlegen.
            </span>
          </div>
          <div className={styles.schritt}>
            <span className={styles.schrittNummer}>2</span>
            <span className={styles.schrittText}>
              Diesen Aushang noch einmal scannen — damit gehörst du zu{" "}
              <strong>{zeile.studio_name}</strong>.
            </span>
          </div>
          <a className={styles.aktion} href="https://apps.apple.com/">
            App laden
          </a>
          <p className={styles.fussnote}>Zurzeit nur für iPhone.</p>
        </section>
      </main>
    );
  }

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
        <p className={styles.zweiterScan}>
          Nach dem Laden diesen Code hier noch einmal scannen — dann bist du
          bei <strong>{zeile.studio_name}</strong> angemeldet.
        </p>
      </section>

      <p className={styles.grenze}>
        gymodo misst nichts. Einweisungsvideos und Einstellhinweise sind Inhalte
        deines Studios, keine Trainings- oder Gesundheitsempfehlung von gymodo.
      </p>
    </main>
  );
}
