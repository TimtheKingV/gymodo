"use client";
import { useEffect, useRef, useState } from "react";
import styles from "./Held.module.css";
import { useMedienabfrage, useReduzierteBewegung } from "./useMedienabfrage";

/**
 * Hochkant-Video nur mobil, nur ohne Bewegungsreduktion, nur im Bild
 * (Spec 7.2, Gpath). In Etappe 1 uebergibt niemand ein Video (E6); der
 * Baustein steht, damit das Video spaeter nur eine Prop ist.
 */
export function HeldVideo({ src, poster }: { src: string; poster: string }) {
  const reduziert = useReduzierteBewegung();
  const schmal = useMedienabfrage("(max-width: 989px)");
  const aktiv = schmal && !reduziert;
  const video = useRef<HTMLVideoElement>(null);
  const vonHandAngehalten = useRef(false);
  const imBild = useRef(false);
  const [laeuft, setLaeuft] = useState(false);

  useEffect(() => {
    const v = video.current;
    if (!aktiv || !v) return;
    const abspielen = () => {
      if (!imBild.current || vonHandAngehalten.current || document.hidden) return;
      v.play().then(
        () => setLaeuft(true),
        () => setLaeuft(false),
      );
    };
    const io = new IntersectionObserver(
      ([e]) => {
        if (!e) return;
        imBild.current = e.isIntersecting;
        if (e.isIntersecting) abspielen();
        else {
          v.pause();
          setLaeuft(false);
        }
      },
      { threshold: 0.15 },
    );
    io.observe(v);
    // Safari haelt Videos im Hintergrund an; der Observer meldet beim
    // Zurueckkehren keinen Wechsel.
    document.addEventListener("visibilitychange", abspielen);
    window.addEventListener("pageshow", abspielen);
    return () => {
      io.disconnect();
      document.removeEventListener("visibilitychange", abspielen);
      window.removeEventListener("pageshow", abspielen);
    };
  }, [aktiv]);

  if (!aktiv) return null;

  const umschalten = () => {
    const v = video.current;
    if (!v) return;
    if (laeuft) {
      vonHandAngehalten.current = true;
      v.pause();
      setLaeuft(false);
    } else {
      vonHandAngehalten.current = false;
      v.play().then(() => setLaeuft(true));
    }
  };

  return (
    <div className={styles.video}>
      <video
        ref={video}
        src={src}
        poster={poster}
        muted
        loop
        playsInline
        preload="none"
        aria-hidden="true"
        tabIndex={-1}
      />
      <button
        type="button"
        className={styles.pause}
        onClick={umschalten}
        aria-label={laeuft ? "Video anhalten" : "Video abspielen"}
      >
        <span aria-hidden="true">{laeuft ? "❚❚" : "▶"}</span>
      </button>
    </div>
  );
}
