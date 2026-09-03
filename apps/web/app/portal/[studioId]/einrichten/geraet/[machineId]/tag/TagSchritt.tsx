"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { tagErsetzen, tagPruefen, tagVerbinden } from "../../../actions";
import { antwortAuf, type Befund } from "../../../befund";
import styles from "../../../halle.module.css";

type Ansicht = "kleben" | "befund";

/**
 * Zwei Ansichten, ein Zustand: was gerade in der Hand liegt. Das gehoert
 * nicht in die URL -- ein Neuladen soll hier zurueck ans Kleben fuehren,
 * nicht auf eine Antwort zu einem Tag, den niemand mehr haelt.
 *
 * AUFGABE 9b: der Sucher fehlt noch. Er schaltet sich zwischen "kleben" und
 * "befund" -- getUserMedia, jsQR, und der gelesene Text durch parseTagScan
 * in dasselbe pruefe() wie das Feld unten. Bis dahin ist das Token-Feld die
 * Hauptaktion; danach wird es der Rueckfallweg fuer eine verweigerte
 * Kamerafreigabe (Spec 7).
 */
export function TagSchritt({
  studioId,
  machineId,
  geraetLabel,
  geraetHatTag,
}: {
  studioId: string;
  machineId: string;
  geraetLabel: string;
  geraetHatTag: boolean;
}) {
  const router = useRouter();
  const [ansicht, setAnsicht] = useState<Ansicht>("kleben");
  const [token, setToken] = useState("");
  const [befund, setBefund] = useState<Befund | null>(null);
  const [fehler, setFehler] = useState<string | null>(null);
  const [laeuft, starte] = useTransition();

  function pruefe(kandidat: string) {
    setFehler(null);
    starte(async () => {
      const antwort = await tagPruefen(studioId, kandidat);
      if (!antwort.ok) {
        setFehler(antwort.error);
        return;
      }
      setToken(kandidat);
      setBefund(antwort.befund);
      setAnsicht("befund");
    });
  }

  if (ansicht === "befund" && befund) {
    const antwort = antwortAuf(befund, geraetLabel, { geraetHatTag });
    return (
      <>
        <div
          className={
            antwort.ton === "warnung" ? styles.karteWarnung : styles.karte
          }
        >
          <div
            style={{ fontSize: 22, fontWeight: 800, letterSpacing: "-0.02em" }}
          >
            {antwort.titel}
          </div>
          <p className={styles.notiz}>{antwort.text}</p>
        </div>

        {antwort.hauptaktion !== null ? (
          <button
            type="button"
            className={styles.haupt}
            disabled={laeuft}
            onClick={() => {
              setFehler(null);
              starte(async () => {
                // Ersetzen bindet zuerst und sperrt danach den alten --
                // umgekehrt stuende das Geraet nach einem Abbruch ohne Tag da.
                const ergebnis =
                  antwort.hauptaktion === "ersetzen"
                    ? await tagErsetzen(studioId, machineId, token)
                    : await tagVerbinden(studioId, machineId, token);
                if (!ergebnis.ok) {
                  setFehler(ergebnis.error);
                  return;
                }
                router.push(
                  `/portal/${studioId}/einrichten/geraet/${machineId}/uebungen`,
                );
              });
            }}
          >
            {antwort.hauptaktion === "ersetzen" ? "Ersetzen" : "Verbinden"}
          </button>
        ) : null}

        {fehler ? (
          <p className={styles.fehler} role="alert">
            {fehler}
          </p>
        ) : null}

        <button
          type="button"
          className={styles.neben}
          onClick={() => {
            setBefund(null);
            setToken("");
            setAnsicht("kleben");
          }}
        >
          Anderen Tag nehmen
        </button>
      </>
    );
  }

  return (
    <>
      <div className={styles.karte}>
        <Skizze />
        <p className={styles.notiz}>
          In Augenhöhe, wo man im Stehen hinsieht.
        </p>
      </div>

      <section className={styles.abschnitt}>
        <div className={styles.abschnittKopf}>
          <h2 className={styles.label}>Worauf es ankommt</h2>
        </div>
        <div className={styles.zeile}>
          <div>
            <div className={styles.zeileHaupt}>Nicht auf Bewegtes</div>
            <div className={styles.zeileMeta}>
              Kein Gewichtsblock, kein Hebel, kein Polster
            </div>
          </div>
        </div>
        <div className={styles.zeile}>
          <div>
            <div className={styles.zeileHaupt}>
              Metall braucht die Ferritseite
            </div>
            <div className={styles.zeileMeta}>
              Sonst liest der Chip nicht — der QR schon
            </div>
          </div>
        </div>
        <div className={styles.zeile}>
          <div>
            <div className={styles.zeileHaupt}>Sauber und trocken</div>
            <div className={styles.zeileMeta}>
              Einmal abwischen hält den Tag jahrelang
            </div>
          </div>
        </div>
      </section>

      <div className={styles.feld}>
        <label className={styles.label} htmlFor="tag-token">
          Token vom Tag
        </label>
        <input
          id="tag-token"
          className={styles.eingabe}
          value={token}
          placeholder="22 Zeichen"
          onChange={(ereignis) => setToken(ereignis.target.value)}
        />
        <span className={styles.notiz}>
          Steht im Klartext neben dem QR. Nimm irgendeinen Tag aus der
          Gerätepackung — welcher es ist, findet die Prüfung heraus.
        </span>
      </div>

      {fehler ? (
        <p className={styles.fehler} role="alert">
          {fehler}
        </p>
      ) : null}

      <button
        type="button"
        className={styles.haupt}
        disabled={laeuft || token.trim() === ""}
        onClick={() => pruefe(token)}
      >
        {laeuft ? "Wird geprüft …" : "Tag prüfen"}
      </button>
    </>
  );
}

/** Wo der Tag hingehoert. Die Position entscheidet ueber die Trefferquote. */
function Skizze() {
  return (
    <svg
      width="100%"
      height="150"
      viewBox="0 0 300 150"
      fill="none"
      stroke="var(--text-faint)"
      strokeWidth="1.75"
      strokeLinecap="round"
      strokeLinejoin="round"
      role="img"
      aria-label="Skizze: der Tag klebt in Augenhöhe am feststehenden Rahmen"
    >
      <path d="M60 132h90" />
      <path d="M105 132V44" />
      <path d="M105 44h52" />
      <path d="M157 44v14" />
      <rect x="60" y="60" width="34" height="62" rx="3" />
      <path d="M60 74h34M60 86h34M60 98h34M60 110h34" />
      <path d="M128 132v-22h34v22" />
      <path d="M128 110c0-9 7-14 17-14s17 5 17 14" />
      <circle cx="196" cy="82" r="17" stroke="var(--accent)" strokeWidth="2" />
      <path d="M188 82h16M196 74v16" stroke="var(--accent)" strokeWidth="2" />
      <path
        d="M179 82h-14"
        stroke="var(--accent)"
        strokeWidth="2"
        strokeDasharray="3 4"
      />
      <text
        x="196"
        y="118"
        fill="var(--accent)"
        fontSize="11"
        fontWeight="700"
        textAnchor="middle"
        stroke="none"
        letterSpacing="1.4"
      >
        HIER
      </text>
    </svg>
  );
}
