import type { AuthError, SupabaseClient } from "@supabase/supabase-js";
import { DomainError } from "./errors.js";

/**
 * Ein Ausfall des Auth-Dienstes -- kein Urteil ueber die Anmeldung.
 *
 * `getUser()` meldet beides ueber dasselbe `error`-Feld: "dieses Token gilt
 * nicht" (kein Token dabei, abgelaufen, gefaelscht -- 400/401/403) und "ich
 * konnte nicht nachfragen" (Verbindung weg, 429, 5xx). Nur das Zweite ist
 * ein Ausfall, und nur er darf als solcher nach oben.
 *
 * `AuthRetryableFetchError` ist der Name, den auth-js einem abgerissenen
 * oder nicht beantworteten Aufruf gibt; 429 und 5xx kommen als
 * `AuthApiError` mit Status.
 */
export function istAuthAusfall(error: AuthError | null): boolean {
  if (!error) return false;
  if (error.name === "AuthRetryableFetchError") return true;
  const status = error.status;
  return status === 429 || (status !== undefined && status >= 500);
}

/**
 * Die gepruefte Identitaet des Aufrufers -- nie aus der Nutzlast.
 *
 * `getUser()` laesst das Token vom Auth-Dienst pruefen, statt der lokalen
 * Kopie zu glauben. Das kostet einen Sprung und ist genau deshalb richtig:
 * bei einem Bearer-Token aus einer fremden App ist die lokale Kopie kein
 * Beleg.
 *
 * Der Sprung kann aber auch schiefgehen, und bis hierher fiel das mit
 * "nicht angemeldet" zusammen: gelesen wurde nur `data`, `error` fiel unter
 * den Tisch. Ein Ausfall ist aber keine Aussage ueber die Anmeldung --
 * derselbe Schnitt wie in RootDestinationLogic (PR #17): ein Ladefehler ist
 * keine Aussage ueber die Mitgliedschaft.
 *
 * Der Unterschied ist nicht akademisch. Weiter oben wurde aus `unauthorized`
 * lautlos eine 404-Seite (ladeKatalog) oder eine Rail ohne Zahlen, die die
 * Geraeteliste sperrt (railZahlen) -- beides ohne eine Zeile im Protokoll.
 * Ein Ausfall sah damit aus wie ein Recht, das jemand nicht hat, und war in
 * der CI von aussen nicht zu erkennen.
 */
export async function requireUserId(client: SupabaseClient): Promise<string> {
  const { data, error } = await client.auth.getUser();
  if (istAuthAusfall(error)) {
    throw new DomainError(
      "internal",
      `Die Anmeldung liess sich nicht pruefen (${error!.status ?? error!.name}): ${error!.message}`,
    );
  }
  const userId = data.user?.id;
  if (!userId) {
    throw new DomainError("unauthorized", "Kein angemeldeter Nutzer.");
  }
  return userId;
}
