import Testing
@testable import Sensorik

/// Spec B, Nachtrag 14.10. Punkt 2: Regel nach dem Namen des Geraetetyps.
struct BefestigungsartTests {
    @Test(arguments: [
        ("Kurzhantel", true, Befestigungsart?.some(.kurzhantel)),
        ("Kurzhantelbank", true, .some(.kurzhantel)),
        ("Langhantel", true, .some(.langhantel)),
        ("SZ-Stange", true, .some(.langhantel)),
        ("Beinpresse", true, .some(.stapel)),
        ("Latzugstation + V-Griff", true, .some(.stapel)),
        ("Ruderergometer mit Rollsitz", false, nil),
        // "SZ" nur als eigenes Wort: sonst traefe es jedes Wort mit "sz".
        ("Schulterpresse", true, .some(.stapel)),
    ])
    func vorschlagNachName(name: String, kraft: Bool, erwartet: Befestigungsart?) {
        #expect(Befestigungsart.vorschlag(geraetename: name, istKraft: kraft) == erwartet)
    }

    /// Kurzhantel vor Langhantel: ein Name mit beiden ist eine Ablage, an der
    /// die Kurzhantel gegriffen wird -- die Reihenfolge der Spec gilt.
    @Test func kurzhantelGehtVor() {
        #expect(Befestigungsart.vorschlag(geraetename: "Kurzhantel- und Langhantelablage", istKraft: true) == .kurzhantel)
    }
}
