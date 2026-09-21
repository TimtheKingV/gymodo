// @vitest-environment jsdom
import { afterEach, describe, expect, it } from "vitest";
import { elementAngabe, repoPfad, zielElement } from "./element";

afterEach(() => {
  document.body.innerHTML = "";
});

function markup(html: string): HTMLElement {
  document.body.innerHTML = html;
  return document.body.firstElementChild as HTMLElement;
}

describe("zielElement", () => {
  it("nimmt den Knopf, wenn auf seine Schrift gezeigt wird", () => {
    const knopf = markup("<button><span><em>Gerät anlegen</em></span></button>");
    const schrift = knopf.querySelector("em")!;
    expect(zielElement(schrift)).toBe(knopf);
  });

  it("bleibt am Element, wenn es selbst bedeutsam ist", () => {
    const feld = markup('<input type="text" />');
    expect(zielElement(feld)).toBe(feld);
  });

  it("steigt hoechstens vier Ebenen", () => {
    const tief = markup(
      "<button><div><div><div><div><span>tief</span></div></div></div></div></button>",
    );
    const span = tief.querySelector("span")!;
    expect(zielElement(span)).toBe(span);
  });
});

describe("elementAngabe", () => {
  it("nimmt die Kennung aus data-testnotiz vor data-testid und id", () => {
    const knopf = markup('<button data-testnotiz="geraete.anlegen" data-testid="x" id="y">A</button>');
    expect(elementAngabe(knopf).identifier).toBe("geraete.anlegen");
    expect(elementAngabe(markup('<button data-testid="x" id="y">A</button>')).identifier).toBe("x");
    expect(elementAngabe(markup('<button id="y">A</button>')).identifier).toBe("y");
    expect(elementAngabe(markup("<button>A</button>")).identifier).toBeNull();
  });

  it("nimmt aria-label vor dem sichtbaren Text", () => {
    expect(elementAngabe(markup('<button aria-label="Schließen">✕</button>')).label).toBe("Schließen");
    expect(elementAngabe(markup("<button>  Gerät\n  anlegen </button>")).label).toBe("Gerät anlegen");
  });

  it("loest aria-labelledby auf", () => {
    document.body.innerHTML = '<h2 id="t">Geräte</h2><button aria-labelledby="t"></button>';
    const knopf = document.querySelector("button")!;
    expect(elementAngabe(knopf).label).toBe("Geräte");
  });

  it("kuerzt lange Beschriftungen", () => {
    const lang = "a".repeat(300);
    const label = elementAngabe(markup(`<button>${lang}</button>`)).label;
    expect(label).toHaveLength(120);
    expect(label?.endsWith("…")).toBe(true);
  });

  it("Typ ist Rolle oder Markierung, Quelle bleibt dom", () => {
    expect(elementAngabe(markup("<button>A</button>")).type).toBe("button");
    expect(elementAngabe(markup('<div role="dialog"></div>')).type).toBe("dialog");
    expect(elementAngabe(markup('<input type="number" />')).type).toBe("input[type=number]");
    expect(elementAngabe(markup('<div data-testnotiz-typ="EinstellungRad"></div>')).type).toBe(
      "EinstellungRad",
    );
    expect(elementAngabe(markup("<button>A</button>")).source).toBe("dom");
  });

  it("uebernimmt eine ausdrueckliche Fundstelle", () => {
    const knopf = markup(
      '<button data-testnotiz-datei="apps/web/app/portal/page.tsx" data-testnotiz-zeile="42">A</button>',
    );
    expect(elementAngabe(knopf)).toMatchObject({
      file: "apps/web/app/portal/page.tsx",
      line: 42,
    });
  });

  it("ohne Fundstelle stehen beide auf null", () => {
    expect(elementAngabe(markup("<button>A</button>"))).toMatchObject({ file: null, line: null });
  });
});

describe("Herkunft aus der React-Faser", () => {
  /** So haengt React seine Faser an den Knoten; mehr liest das Modul nicht. */
  function mitFaser(element: Element, faser: unknown): Element {
    Object.defineProperty(element, "__reactFiber$probe", {
      value: faser,
      configurable: true,
      enumerable: true,
    });
    return element;
  }

  it("nimmt den Komponentennamen und die Fundstelle", () => {
    function PrimaryButton() {
      return null;
    }
    const knopf = mitFaser(markup("<button>A</button>"), {
      type: "button",
      return: {
        type: PrimaryButton,
        _debugSource: {
          fileName: "/Users/tim/gymodo/apps/web/app/portal/bausteine/Kachel.tsx",
          lineNumber: 42,
        },
      },
    });
    expect(elementAngabe(knopf)).toMatchObject({
      type: "PrimaryButton",
      file: "apps/web/app/portal/bausteine/Kachel.tsx",
      line: 42,
    });
  });

  it("Bausteine des Routers zaehlen nicht -- dann gilt die Rolle", () => {
    function SegmentViewNode() {
      return null;
    }
    const knopf = mitFaser(markup("<button>A</button>"), {
      type: "button",
      return: { type: SegmentViewNode },
    });
    expect(elementAngabe(knopf)).toMatchObject({ type: "button", file: null });
  });
});

describe("repoPfad", () => {
  it("kuerzt den Pfad der Bauumgebung auf den des Repos", () => {
    expect(repoPfad("/Users/tim/code/gymodo/apps/web/app/portal/page.tsx")).toBe(
      "apps/web/app/portal/page.tsx",
    );
  });

  it("was nicht im Web-Ziel liegt, bleibt der Dateiname", () => {
    expect(repoPfad("webpack://./node_modules/react/index.js")).toBe("index.js");
  });
});
