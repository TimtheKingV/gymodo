"use client";

import { useActionState } from "react";
import { Einstieg } from "../einstieg/Einstieg";
import { Feld } from "../portal/Form";
import styles from "../einstieg/einstieg.module.css";
import { registrieren, registrierungBestaetigen } from "./actions";

/**
 * Ein Ablauf, kein Ortswechsel: zwei Artboards (Registrieren.dc.html,
 * Verifizieren.dc.html), eine Route. registrierenAction liefert entweder
 * einen Fehler oder die Adresse, an die der Code ging -- sobald sie steht,
 * rendert dieselbe Route den zweiten Schritt.
 *
 * Registrieren.dc.html zeichnet unter dem Knopf "Ein Konto allein reicht
 * nicht -- du brauchst danach den Code deines Studios." Das gilt fuers Web
 * nicht mehr: hier wird man Mitarbeiter, nicht Mitglied, und der
 * Studio-Code macht Mitglieder. note-einstieg auf der Canvas sagt das
 * ausdruecklich (Personal kommt ueber Leute -> Mitarbeiter in ein
 * bestehendes Studio). Der Satz ist deshalb ersetzt.
 *
 * Verifizieren.dc.html zeichnet zusaetzlich einen Link "Neuen Code
 * anfordern". Dafuer gibt es keine Server Action -- das waere neues
 * Verhalten, kein Aussehen -- und er wird hier nicht gebaut.
 */
export default function RegistrierenPage() {
  const [registrierenState, registrierenAction] = useActionState(registrieren, null);
  const [bestaetigenState, bestaetigenAction] = useActionState(registrierungBestaetigen, null);

  if (registrierenState && "sentTo" in registrierenState && registrierenState.sentTo) {
    const adresse = registrierenState.sentTo;
    return (
      <Einstieg
        titel="Verifizieren"
        vorspann={
          <>
            Wir haben einen Code an <span className={styles.adresse}>{adresse}</span> geschickt.
            Er gilt eine Stunde.
          </>
        }
      >
        <form action={bestaetigenAction}>
          <input type="hidden" name="email" value={adresse} />
          <div className={styles.felder}>
            <Feld
              name="token"
              label="Code aus der E-Mail"
              inputMode="numeric"
              autoComplete="one-time-code"
              required
            />
          </div>
          {bestaetigenState && "error" in bestaetigenState ? (
            <p className={styles.fehlermeldung} role="alert">
              {bestaetigenState.error}
            </p>
          ) : null}
          <button type="submit" className={styles.knopf}>
            Bestätigen
          </button>
        </form>
      </Einstieg>
    );
  }

  return (
    <Einstieg
      titel="Registrieren"
      fuss={
        <p className={styles.hinweis}>
          Ein Konto allein reicht nicht — ein Studio muss dich danach als Mitarbeiter hinzufügen.
        </p>
      }
    >
      <form action={registrierenAction}>
        <div className={styles.felder}>
          <Feld name="email" label="E-Mail" type="email" autoComplete="email" required />
          <Feld
            name="password"
            label="Passwort"
            type="password"
            autoComplete="new-password"
            required
            hint="Mindestens zehn Zeichen. Länge zählt mehr als Sonderzeichen."
          />
        </div>
        {registrierenState && "error" in registrierenState ? (
          <p className={styles.fehlermeldung} role="alert">
            {registrierenState.error}
          </p>
        ) : null}
        <button type="submit" className={styles.knopf}>
          Konto anlegen
        </button>
      </form>
    </Einstieg>
  );
}
