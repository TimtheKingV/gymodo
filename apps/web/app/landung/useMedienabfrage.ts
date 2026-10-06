"use client";
import { useSyncExternalStore } from "react";

/**
 * useSyncExternalStore statt useEffect+useState: kein Zwischenrender mit
 * falschem Wert nach der Hydrierung. Der Server kennt kein Medium und
 * nimmt "trifft nicht zu" an -- dann rendert er die ruhige Fassung ohne
 * Video, die Client-Fassung kommt danach dazu.
 */
export function useMedienabfrage(query: string): boolean {
  return useSyncExternalStore(
    (melden) => {
      const liste = window.matchMedia(query);
      liste.addEventListener("change", melden);
      return () => liste.removeEventListener("change", melden);
    },
    () => window.matchMedia(query).matches,
    () => false,
  );
}

export function useReduzierteBewegung(): boolean {
  return useMedienabfrage("(prefers-reduced-motion: reduce)");
}
