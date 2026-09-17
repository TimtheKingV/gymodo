// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { NameFeld, Rad } from "./EinstellungRad";

afterEach(cleanup);

/**
 * Das Rad meldet eine Auswahl ueber `onWahl`. Wann es das tut, ist keine
 * Kosmetik: NameFeld gibt `onWahl: onChange` mit, das Vorschlagsrad steht
 * beim Oeffnen auf Index 0, und ein folgenloses Scroll-Ereignis schrieb
 * damit den ersten Vorschlag in ein Feld, in dem schon etwas stand.
 *
 * Gefunden am 17. September im CI-Lauf 35268246152: das Portal legte eine
 * Einstellung "Wiederholungen" an -- den ersten Eintrag aus
 * nameVorschlaege() --, obwohl der Test "Sitzposition" getippt hatte.
 */
describe("Rad", () => {
  function radMitSpion() {
    const onWahl = vi.fn();
    render(
      <Rad
        spalten={[
          {
            label: "Vorschlag",
            werte: [
              { wert: "Wiederholungen", anzeige: "Wiederholungen" },
              { wert: "Gewicht", anzeige: "Gewicht" },
              { wert: "Winkel", anzeige: "Winkel" },
            ],
            onWahl,
          },
        ]}
      />,
    );
    return { onWahl, spalte: screen.getByRole("listbox", { name: "Vorschlag" }) };
  }

  it("meldet nichts, wenn ein Scroll die Mitte nicht bewegt", async () => {
    const { onWahl, spalte } = radMitSpion();

    // scrollTop bleibt 0 -- genau der Fall, den Layout, Fokuswechsel oder
    // ein scrollIntoView des Nachbarn ausloesen.
    fireEvent.scroll(spalte);

    await new Promise((fertig) => requestAnimationFrame(() => fertig(null)));
    expect(onWahl).not.toHaveBeenCalled();
  });

  it("meldet, wenn der Trainer wirklich auf eine andere Zeile scrollt", async () => {
    const { onWahl, spalte } = radMitSpion();

    // Zeilenhoehe 40 (nicht "gross"), also ist 40 die zweite Zeile.
    spalte.scrollTop = 40;
    fireEvent.scroll(spalte);

    await waitFor(() => expect(onWahl).toHaveBeenCalledWith("Gewicht"));
    expect(onWahl).toHaveBeenCalledTimes(1);
  });

  it("meldet dieselbe Zeile nicht zweimal", async () => {
    const { onWahl, spalte } = radMitSpion();

    spalte.scrollTop = 40;
    fireEvent.scroll(spalte);
    await waitFor(() => expect(onWahl).toHaveBeenCalledTimes(1));

    fireEvent.scroll(spalte);
    await new Promise((fertig) => requestAnimationFrame(() => fertig(null)));
    expect(onWahl).toHaveBeenCalledTimes(1);
  });
});

describe("NameFeld", () => {
  /**
   * Der Fall aus dem CI-Lauf, eine Ebene hoeher: getippter Name, dann ein
   * folgenloses Scroll-Ereignis im Vorschlagsrad. Vorher stand danach
   * "Wiederholungen" im Feld.
   */
  it("behaelt den getippten Namen, wenn das Vorschlagsrad folgenlos scrollt", async () => {
    const onChange = vi.fn();
    render(
      <NameFeld
        name="label"
        label="Beschriftung"
        value="Sitzposition"
        onChange={onChange}
        vorschlaege={[
          { wert: "Wiederholungen", anzeige: "Wiederholungen" },
          { wert: "Gewicht", anzeige: "Gewicht" },
        ]}
      />,
    );

    // Das Rad erscheint erst mit dem Fokus -- so wie beim Trainer, der ins
    // Feld klickt und dann tippt.
    fireEvent.focus(screen.getByLabelText("Beschriftung"));
    fireEvent.scroll(screen.getByRole("listbox", { name: "Vorschlag" }));

    await new Promise((fertig) => requestAnimationFrame(() => fertig(null)));
    expect(onChange).not.toHaveBeenCalled();
  });
});
