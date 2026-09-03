"use client";

import { useEffect, useRef, useState } from "react";
import jsQR from "jsqr";
import { parseTagScan } from "@fitretro/domain/tag-scan";
import styles from "../../../halle.module.css";

type Zustand = "startet" | "laeuft" | "verweigert" | "nicht-moeglich";

/**
 * Der Sucher. Safari kennt BarcodeDetector nicht (Spec 5), also die Kamera
 * ueber getUserMedia und ein Decoder im Browser. Immer jsQR, kein
 * BarcodeDetector-Zweig: zwei Decoder-Pfade heissen zwei Fehlerbilder, von
 * denen einer auf dem Testgeraet nie laeuft.
 *
 * Der Chip zaehlt hier nicht: im Tag steckt zusaetzlich NFC, aber ein
 * Browser liest kein NFC. Im Portal geht es allein ueber den QR
 * (Entscheidung 5).
 *
 * Was der Decoder liest, geht durch parseTagScan und von dort in dasselbe
 * pruefe() wie das Token-Feld darunter. Der Sucher ist die Kamera davor,
 * mehr nicht -- deshalb ist der Rueckfallweg kein Ersatzpfad, sondern
 * derselbe Pfad ohne Linse.
 */
export function Sucher({ onToken }: { onToken: (token: string) => void }) {
  const [zustand, setZustand] = useState<Zustand>("startet");
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  // Der Callback wird ueber ein Ref gelesen, damit der Effekt nicht bei jedem
  // Rendern der Elternkomponente die Kamera neu anfordert.
  const onTokenRef = useRef(onToken);
  onTokenRef.current = onToken;

  useEffect(() => {
    if (
      typeof navigator === "undefined" ||
      !navigator.mediaDevices?.getUserMedia
    ) {
      // Auch der Grund, warum das hier steht und nicht nur der Fehlerfall:
      // ohne sicheren Kontext (HTTPS oder localhost) gibt es mediaDevices
      // gar nicht. Eine LAN-Adresse zaehlt nicht als sicher.
      setZustand("nicht-moeglich");
      return;
    }

    let stream: MediaStream | null = null;
    let bild = 0;
    let beendet = false;

    function halt() {
      beendet = true;
      cancelAnimationFrame(bild);
      stream?.getTracks().forEach((spur) => spur.stop());
    }

    function lies() {
      const video = videoRef.current;
      const canvas = canvasRef.current;
      if (!video || !canvas || beendet) return;

      if (video.readyState === video.HAVE_ENOUGH_DATA) {
        const ctx = canvas.getContext("2d", { willReadFrequently: true });
        if (ctx && video.videoWidth > 0) {
          canvas.width = video.videoWidth;
          canvas.height = video.videoHeight;
          ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
          const daten = ctx.getImageData(0, 0, canvas.width, canvas.height);
          const treffer = jsQR(daten.data, daten.width, daten.height, {
            inversionAttempts: "dontInvert",
          });
          if (treffer) {
            const token = parseTagScan(treffer.data);
            if (token) {
              halt();
              onTokenRef.current(token);
              return;
            }
          }
        }
      }
      bild = requestAnimationFrame(lies);
    }

    async function starte() {
      try {
        stream = await navigator.mediaDevices.getUserMedia({
          // Die Rueckkamera: der Trainer haelt das Telefon an das Geraet.
          video: { facingMode: { ideal: "environment" } },
          audio: false,
        });
      } catch {
        setZustand("verweigert");
        return;
      }
      if (beendet) {
        stream.getTracks().forEach((spur) => spur.stop());
        return;
      }

      const video = videoRef.current;
      if (!video) return;
      video.srcObject = stream;
      // playsInline steht am Element; ohne es geht mobiles Safari in den
      // Vollbildspieler und der Sucher verschwindet hinter der Abspielflaeche.
      await video.play().catch(() => undefined);
      setZustand("laeuft");
      bild = requestAnimationFrame(lies);
    }

    void starte();
    return halt;
  }, []);

  if (zustand === "verweigert" || zustand === "nicht-moeglich") {
    return (
      <div className={styles.karteWarnung}>
        <div className={styles.karteTitel}>
          {zustand === "verweigert"
            ? "Die Kamera ist nicht freigegeben"
            : "Die Kamera lässt sich hier nicht öffnen"}
        </div>
        <p className={styles.notiz}>
          {zustand === "verweigert"
            ? "In Safari: „aA“ links in der Adresszeile, dann Website-Einstellungen, dann Kamera erlauben."
            : "Der Browser gibt die Kamera nur über eine gesicherte Verbindung frei."}{" "}
          Der Chip im Tag hilft im Browser nicht — aber der Token steht auch im
          Klartext auf dem Aufkleber, und das Feld darunter führt zum selben
          Ergebnis.
        </p>
      </div>
    );
  }

  return (
    <div className={styles.karte}>
      <div className={styles.sucherRahmen}>
        <video
          ref={videoRef}
          playsInline
          muted
          aria-label="Sucher"
          className={styles.sucherBild}
        />
        <span className={styles.sucherEcken} aria-hidden="true" />
      </div>
      <canvas ref={canvasRef} style={{ display: "none" }} />
      <p className={styles.notiz}>
        {zustand === "startet"
          ? "Kamera startet …"
          : "Halt den QR auf dem Tag ins Bild. Geh nah ran — der Code ist klein."}
      </p>
      <p className={styles.notiz}>
        Im Tag steckt zusätzlich NFC — der trägt den Weg des Mitglieds. Ein
        Browser liest kein NFC, im Portal geht es allein über den QR.
      </p>
    </div>
  );
}
