import { createBrowserClient } from "@supabase/ssr";

/**
 * Client im Browser -- ausschliesslich fuer den Videoupload.
 *
 * Alles andere laeuft ueber Server Actions. Der Upload nicht: 50 MiB durch
 * eine Server Action haetten weder Fortschrittsanzeige noch Wiederaufnahme
 * nach Abbruch, und beides verlangt Spec 6.8 ausdruecklich (Studio-WLAN).
 * Der Browser spricht deshalb direkt mit dem Storage-Dienst -- mit dem
 * Zugriffstoken des angemeldeten Nutzers, also unter denselben Policies
 * aus 0020 wie jeder andere Zugriff.
 */
export function createBrowserSupabaseClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key) {
    throw new Error(
      "NEXT_PUBLIC_SUPABASE_URL und NEXT_PUBLIC_SUPABASE_ANON_KEY fehlen.",
    );
  }
  return createBrowserClient(url, key);
}

export function storageUrl(): string {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  if (!url) throw new Error("NEXT_PUBLIC_SUPABASE_URL fehlt.");
  return `${url}/storage/v1/upload/resumable`;
}
