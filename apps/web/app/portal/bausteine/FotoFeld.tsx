"use client";

import { useEffect, useState } from "react";
import { DateiKnopf } from "./DateiKnopf";
import { MedienVorschau } from "./MedienVorschau";
import portalStyles from "../portal.module.css";

/**
 * Foto waehlen + Vorschau, ein Baustein statt drei separater Nachbauten
 * (ModellNeuFormular.tsx, EinstellungSheet.tsxs FotoNachreichen,
 * StammdatenFormular.tsx bauten das bisher je fuer sich). Zeigt die gerade
 * gewaehlte Datei sofort per Objekt-URL -- Trainer-Wunsch: "wenn Bild oder
 * Video drin ist dann das oben als Mini-Vorschau anzeigen" -- oder, ohne
 * neue Auswahl, ein schon gespeichertes Foto (`vorhandeneUrl`).
 *
 * Traegt selbst das echte `<input type="file" name=...>` -- reines
 * Umstyling der bisherigen Formularfelder, kein neuer Uebertragungsweg.
 */
export function FotoFeld({
  name,
  vorhandeneUrl,
  ausloeserText,
  ariaLabel,
  alt,
  hinweis,
  mini = false,
  gross = false,
  onDatei,
}: {
  /** Ohne `name` (z. B. FotoNachreichen) baut der Aufrufer selbst eine
      FormData aus der Datei -- kein natives Formularfeld noetig. */
  name?: string;
  vorhandeneUrl?: string | undefined;
  ausloeserText?: string;
  /** Fuer das versteckte Dateifeld (Screenreader, Tests) -- unabhaengig
      vom sichtbaren Knopftext. */
  ariaLabel?: string;
  /** Alternativtext des Vorschaubilds, z. B. "Foto von Latzug". Leer =
      dekorativ. */
  alt?: string;
  hinweis?: React.ReactNode;
  mini?: boolean;
  gross?: boolean;
  onDatei?: (datei: File | null) => void;
}) {
  const [objektUrl, setObjektUrl] = useState<string | null>(null);

  // Objekt-URLs sind fluechtiger Speicher des Tabs -- beim Verwerfen/Wechsel
  // freigeben, sonst haeuft sich das ueber mehrere Auswahlversuche an.
  useEffect(() => {
    return () => {
      if (objektUrl) URL.revokeObjectURL(objektUrl);
    };
  }, [objektUrl]);

  function aufDatei(datei: File | null) {
    setObjektUrl((bisherige) => {
      if (bisherige) URL.revokeObjectURL(bisherige);
      return datei ? URL.createObjectURL(datei) : null;
    });
    onDatei?.(datei);
  }

  return (
    <div className={portalStyles.mediaRow}>
      <MedienVorschau
        url={objektUrl ?? vorhandeneUrl ?? null}
        art="bild"
        leerText="Noch kein Foto"
        alt={alt}
        mini={mini}
      />
      <div style={{ display: "flex", flexDirection: "column", gap: 8, flex: "1 1 200px" }}>
        <DateiKnopf
          name={name}
          label={ausloeserText ?? (vorhandeneUrl ? "Ersetzen" : "Foto auswählen")}
          ariaLabel={ariaLabel}
          accept="image/jpeg,image/png"
          capture="environment"
          gross={gross}
          onDatei={aufDatei}
        />
        {hinweis ? <span className={portalStyles.hint}>{hinweis}</span> : null}
      </div>
    </div>
  );
}
