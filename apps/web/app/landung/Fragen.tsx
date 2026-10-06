import styles from "./Fragen.module.css";

export type Frage = { frage: string; antwort: string };

/**
 * Natives details/summary: Tastatur, Screenreader und Suche-im-Text gibt es
 * damit gratis. Keine Hoehenanimation -- wie bei Gpath, und eine Antwort,
 * die man lesen will, soll nicht erst einfahren.
 */
export function Fragen({ id, titel, fragen }: { id: string; titel: string; fragen: readonly Frage[] }) {
  const ld = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: fragen.map((f) => ({
      "@type": "Question",
      name: f.frage,
      acceptedAnswer: { "@type": "Answer", text: f.antwort },
    })),
  };
  return (
    <section id={id} className={styles.abschnitt} aria-labelledby={`${id}-titel`}>
      <h2 id={`${id}-titel`} className={styles.titel}>
        {titel}
      </h2>
      <div className={styles.liste}>
        {fragen.map((f) => (
          <details key={f.frage} className={styles.frage}>
            <summary className={styles.kopf}>{f.frage}</summary>
            <p className={styles.antwort}>{f.antwort}</p>
          </details>
        ))}
      </div>
      <script
        type="application/ld+json"
        // JSON.stringify maskiert "<" nicht; ohne Ersatz beendete ein
        // "</script>" im Antworttext das Skript-Element.
        dangerouslySetInnerHTML={{ __html: JSON.stringify(ld).replace(/</g, "\\u003c") }}
      />
    </section>
  );
}
