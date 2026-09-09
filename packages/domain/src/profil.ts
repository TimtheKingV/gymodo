import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { requireUserId } from "./auth.js";
import { DomainError } from "./errors.js";

/**
 * Der Anzeigename eines Mitglieds. Sechzig Zeichen sind grosszuegig fuer
 * einen Vornamen und knapp genug, dass die Kopfkarte im Profil ihn nicht
 * umbrechen muss.
 */
export const anzeigenameSchema = z.object({
  displayName: z
    .string()
    .trim()
    .min(1, "Der Name darf nicht leer sein.")
    .max(60, "Der Name ist zu lang -- hoechstens 60 Zeichen.")
    .refine((wert) => !/[\r\n]/.test(wert), "Der Name darf keinen Zeilenumbruch enthalten."),
});

/** Wirft `DomainError("validation_failed")`, sonst der geputzte Name. */
export function pruefeAnzeigename(roh: unknown): string {
  const geprueft = anzeigenameSchema.safeParse(roh);
  if (!geprueft.success) {
    throw new DomainError("validation_failed", geprueft.error.issues[0]!.message);
  }
  return geprueft.data.displayName;
}

/**
 * Der einzige Schreibweg des Namens -- fuer die Registrierung (Aufgabe
 * 11) und fuer das spaetere Aendern im Profil (Aufgabe 10).
 *
 * `upsert`, weil es fuer kein Bestandsmitglied eine profiles-Zeile gibt:
 * die Tabelle steht seit 0001, aber nie hat Produktivcode sie gefuellt.
 * Insert- und Update-Policy pruefen beide `id = auth.uid()`, die Zeile
 * kann also nur die eigene sein.
 */
export async function setDisplayName(
  client: SupabaseClient,
  payload: unknown,
): Promise<{ displayName: string }> {
  const displayName = pruefeAnzeigename(payload);
  const userId = await requireUserId(client);

  const { error } = await client
    .from("profiles")
    .upsert({ id: userId, display_name: displayName }, { onConflict: "id" });

  // Woertlich durchgereicht verriete das die Tabelle "profiles" (siehe
  // respond.ts) -- z. B. genau dann, wenn Migration 0039 auf dem Server
  // noch fehlt und die RLS-Policy den Insert ablehnt.
  if (error) throw new DomainError("internal", "Der Name konnte nicht gespeichert werden.");

  return { displayName };
}
