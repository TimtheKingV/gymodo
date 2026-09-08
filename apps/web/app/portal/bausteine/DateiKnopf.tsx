"use client";

import { forwardRef, useRef } from "react";
import portalStyles from "../portal.module.css";

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
    capture?: boolean | "user" | "environment";
    disabled?: boolean;
    gross?: boolean;
    onDatei: (datei: File | null) => void;
  }
>(function DateiKnopf(
  { id, name, label, ariaLabel, accept, capture, disabled, gross = false, onDatei },
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
        capture={capture}
        disabled={disabled}
        style={{ display: "none" }}
        onChange={(ereignis) => onDatei(ereignis.target.files?.[0] ?? null)}
      />
      <button
        type="button"
        className={gross ? portalStyles.secondaryGross : portalStyles.secondary}
        disabled={disabled}
        onClick={() => innererRef.current?.click()}
      >
        {label}
      </button>
    </>
  );
});
