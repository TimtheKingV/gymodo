"use client";

import { forwardRef, useRef } from "react";
import portalStyles from "../portal.module.css";
import medien from "./Medien.module.css";

/**
 * Ein gestalteter Ausloeser statt eines nackten <input type="file">
 * (Trainer-Feedback: dieselbe saubere Optik wie ueberall sonst). Kapselt ein
 * unsichtbares Dateifeld, das ein Klick auf den Knopf oeffnet --
 * verallgemeinert das Muster, das FotoNachreichen in EinstellungSheet.tsx
 * schon einmal von Hand gebaut hat.
 *
 * `ref` zeigt auf das echte <input>: bestehende Aufrufer setzen danach z. B.
 * `eingabe.current.value = ""`, um dieselbe Datei erneut waehlbar zu machen
 * (wie es VideoUpload.tsx/Uploads.tsx schon vor dieser Komponente taten).
 * Ein eigener innerer Ref loest den Knopf-Klick aus, der aeussere bleibt
 * unabhaengig davon nutzbar -- zwei Refs auf denselben Knoten, keiner
 * ersetzt den anderen.
 *
 * Kein `capture`-Attribut, mit Absicht (Testnotiz 22.09., #8/#13): damit
 * oeffnete iOS direkt die Kamera, und ein Foto oder Video aus der
 * Mediathek liess sich gar nicht waehlen. Ohne capture fragt das System
 * selbst -- Mediathek, Aufnehmen oder Datei.
 *
 * `art="flaeche"` (Testnotiz 23.09., zweite Sitzung, #4): der Ausloeser ist
 * das leere Feld selbst, in voller Breite und 16:9 -- vorher lag daneben
 * eine 96-px-Kachel "Kein Video", die auf Tipp nichts tat.
 */
export const DateiKnopf = forwardRef<
  HTMLInputElement,
  {
    id?: string;
    name?: string | undefined;
    label: string;
    /** Name des echten, versteckten Dateifelds fuer Screenreader UND fuer
        Tests (`getByLabel(...).setInputFiles(...)` findet ein verstecktes
        Feld -- `isVisible()` betrifft nur Sichtbarkeitspruefungen, nicht
        die Auffindbarkeit selbst). Faellt auf `label` zurueck, wenn nicht
        gesetzt. */
    ariaLabel?: string | undefined;
    accept?: string;
    disabled?: boolean;
    gross?: boolean;
    art?: "knopf" | "flaeche";
    onDatei: (datei: File | null) => void;
  }
>(function DateiKnopf(
  { id, name, label, ariaLabel, accept, disabled, gross = false, art = "knopf", onDatei },
  aeussererRef,
) {
  const innererRef = useRef<HTMLInputElement>(null);

  return (
    <>
      <input
        ref={(knoten) => {
          innererRef.current = knoten;
          if (typeof aeussererRef === "function") aeussererRef(knoten);
          else if (aeussererRef) aeussererRef.current = knoten;
        }}
        id={id}
        name={name}
        type="file"
        aria-label={ariaLabel ?? label}
        accept={accept}
        disabled={disabled}
        style={{ display: "none" }}
        onChange={(ereignis) => onDatei(ereignis.target.files?.[0] ?? null)}
      />
      <button
        type="button"
        className={
          art === "flaeche"
            ? medien.wahlFlaeche
            : gross
              ? portalStyles.secondaryGross
              : portalStyles.secondary
        }
        disabled={disabled}
        onClick={() => innererRef.current?.click()}
      >
        {art === "flaeche" ? (
          <>
            <svg
              width="28"
              height="28"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.8"
              strokeLinecap="round"
              strokeLinejoin="round"
              aria-hidden="true"
            >
              <rect x="3" y="6" width="13" height="12" rx="2" />
              <path d="M16 10.5l5-3v9l-5-3" />
            </svg>
            <span>{label}</span>
          </>
        ) : (
          label
        )}
      </button>
    </>
  );
});
