import SwiftUI

enum UnterstrichStil {
    case akzent   // Gewicht: 4pt accent
    case linie    // Wiederholungen: 3pt line
}

/// Ein Wertrad. Ruhe und Offen sind derselbe Aufbau.
///
/// Der Kniff aus designsystem.md SS7: "die Linie bleibt liegen, die Zahlen
/// ziehen daran vorbei." Die Unterstreichung gehoert deshalb NICHT zur
/// scrollenden Zeile -- sie liegt statisch hinter dem Scroller auf Hoehe der
/// Mittelzeile. Dadurch hat der Screen in beiden Zustaenden dieselbe
/// Silhouette und der Uebergang ist eine Bewegung statt eines Aufbaus.
///
/// Momentum, Deceleration, Rubber-Banding und Unterbrechbarkeit kommen vom
/// System-Scroller. Das sind genau die vier Dinge, die eine handgeschriebene
/// DragGesture als erstes falsch macht -- bei der laut SS9 am haeufigsten
/// ausgeloesten Geste der App das groesste vermeidbare Risiko.
struct RastRad: View {
    let werte: [Double]
    /// Muss ein Element aus `werte` sein. Ein Servervorschlag oder ein alter
    /// gespeicherter Wert (z. B. von vor einem Geraete-Schrittwechsel) kann
    /// daneben liegen -- dafuer gibt es `Rastwerte.naechster(zu:in:)`, das
    /// auf den naechsten erreichbaren Wert rundet. Ohne diese Invariante hat
    /// weder `amAnschlag` je einen Treffer, noch findet `scrollPosition`
    /// eine passende Zeile.
    @Binding var auswahl: Double
    let offen: Bool
    let unterstrich: UnterstrichStil
    /// VoiceOver: "Gewicht" bzw. "Wiederholungen".
    let voLabel: String
    /// VoiceOver: der Wert als EINE Zeichenkette, inklusive Einheit.
    let voWert: (Double) -> String
    /// Wird an den VoiceOver-Wert angehaengt, wenn die Auswahl am Ende
    /// klebt. `nil` bei Geraeten ohne dokumentierte Obergrenze.
    let anschlagText: String?
    /// Formatiert die Zahl auf der Zeile.
    let text: (Double) -> String
    /// Schriftgroesse der gewaehlten Zeile. Default 64pt trifft
    /// `DesignSystem.Typography.wertHeld` (Gewicht, der Held der
    /// Satz-Wertzeile). Die Wiederholungen sind der zweite Wert und
    /// bekommen 44pt (Main.dc.html; die Design-Challenge hat die
    /// gegenteilige 50px-Abweichung in GeraetWertRad.dc.html gefunden und
    /// auf 44 korrigiert). Additiv mit Default, damit das Gewichtsrad aus
    /// Aufgabe 7 unangetastet bleibt.
    var basisGroesse: CGFloat = 64

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var zeilenhoehe: CGFloat = 44
    @State private var scrollPosition: Double?
    @State private var anschlagStoss = 0

    private var amAnschlag: Bool {
        guard anschlagText != nil else { return false }
        return auswahl == werte.first || auswahl == werte.last
    }

    /// Fuenf Zeilen: der gewaehlte Wert plus zwei Nachbarn je Richtung.
    private var radhoehe: CGFloat { zeilenhoehe * 5 }

    var body: some View {
        ZStack {
            unterstreichung
            scroller
        }
        .frame(height: offen ? radhoehe : zeilenhoehe * 1.6)
        .animation(reduceMotion ? nil : DesignSystem.Motion.oeffnen, value: offen)
        .sensoryFeedback(.selection, trigger: auswahl)
        .sensoryFeedback(.impact(weight: .light), trigger: anschlagStoss)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(voLabel)
        .accessibilityValue(voWertMitAnschlag)
        .accessibilityAdjustableAction { richtung in
            switch richtung {
            case .increment: schiebe(um: 1)
            case .decrement: schiebe(um: -1)
            @unknown default: break
            }
        }
    }

    // MARK: - Bestandteile

    /// Liegt fest. Bewegt sich nie -- das ist der ganze Punkt.
    private var unterstreichung: some View {
        VStack(spacing: 0) {
            Spacer()
            Rectangle()
                .fill(unterstrich == .akzent ? DesignSystem.Color.accent : DesignSystem.Color.line)
                .frame(height: unterstrich == .akzent ? 4 : 3)
            Spacer()
        }
        .frame(height: zeilenhoehe * 1.6)
    }

    private var scroller: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(werte, id: \.self) { wert in
                    // `scrollTransition`s Effekt-Closure bekommt keine View,
                    // sondern ein `VisualEffect` -- ein schmales Protokoll
                    // ohne `.font`/`.foregroundStyle` (siehe Kommentar unten).
                    // Deshalb steht Schrift und Grundfarbe fest auf der
                    // Zeile selbst, und nur Skalierung/Deckkraft wandern mit
                    // der Scrollphase.
                    Text(text(wert))
                        .font(.system(size: basisGroesse, weight: .black).monospacedDigit())
                        .foregroundStyle(DesignSystem.Color.text)
                        .frame(height: zeilenhoehe)
                        .frame(maxWidth: .infinity)
                        .scrollTransition(.interactive, axis: .vertical) { inhalt, phase in
                            inhalt
                                .scaleEffect(skalierung(fuer: phase.value))
                                .opacity(deckkraft(fuer: phase.value))
                        }
                }
            }
            .scrollTargetLayout()
        }
        .scrollDisabled(!offen)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollPosition, anchor: .center)
        // Damit Minimum und Maximum mittig einrasten koennen.
        .safeAreaPadding(.vertical, (radhoehe - zeilenhoehe) / 2)
        // Ausblendung nach bg, wie SS7 sie verlangt.
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.32),
                    .init(color: .black, location: 0.68),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
        .onAppear {
            // Verteidigung der Invariante auf `auswahl` (siehe deren
            // Dokumentation): ein unsauberer Startwert wird auf den
            // naechsten erreichbaren Wert gerundet statt eine Zeile ohne
            // sichtbare Auswahl zu zeigen -- in einem dunklen Kraftraum,
            // einhaendig, ist eine leise Korrektur besser als ein leeres
            // Rad.
            if !werte.contains(auswahl) {
                auswahl = Rastwerte.naechster(zu: auswahl, in: werte)
            } else {
                scrollPosition = auswahl
            }
        }
        .onChange(of: scrollPosition) { _, neu in
            guard let neu, neu != auswahl else { return }
            auswahl = neu
        }
        .onChange(of: auswahl) { _, neu in
            if scrollPosition != neu { scrollPosition = neu }
            // Der Anschlag-Stoss ist fuer den Scroll-Daumen die EINZIGE
            // Rueckmeldung am Rand -- die sichtbare Haelfte lebt in
            // WertZeile (Aufgabe 12). Er soll beim Ankommen am Rand
            // klopfen, nicht waehrend die Auswahl dort ruht: `onChange`
            // feuert nur bei einer tatsaechlichen Wertaenderung, also genau
            // beim Uebergang, egal ob er vom Scrollen, vom Rotor oder von
            // der Verteidigung oben kommt. `schiebe(um:)` knockt separat,
            // wenn ein Schritt am Rand ins Leere liefe (`auswahl` aendert
            // sich dabei nicht) -- die beiden Pfade ueberschneiden sich
            // nie, also kein doppeltes Klopfen fuer dieselbe Geste.
            if neu == werte.first || neu == werte.last {
                anschlagStoss += 1
            }
        }
    }

    // MARK: - Nachbar-Optik (designsystem.md SS7)
    //
    // KORREKTUR gegenueber einer frueheren Fassung dieses Kommentars:
    // `ScrollTransitionPhase.value` ist NICHT die Zeilenzahl zur Mitte,
    // sondern kontinuierlich auf [-1, 1] begrenzt (-1 = topLeading, 0 =
    // identity, +1 = bottomTrailing). Bei einem Fuenf-Zeilen-Viewport landet
    // der erste Nachbar (1 Zeile Abstand) bei |phase| ~ 0,5 und der zweite
    // Nachbar (2 Zeilen Abstand) bei |phase| ~ 1,0. Die Schwellen 0,25 und
    // 0,75 liegen deshalb jeweils in der Mitte zwischen "0 Zeilen" / "1
    // Zeile" bzw. "1 Zeile" / "2 Zeilen" -- nicht bei 0,5/1,5, was fuer den
    // begrenzten Wertebereich zu hoch waere und den radFern-Zweig nie
    // erreichen wuerde.
    //
    // ZWEITE KORREKTUR: `scrollTransition`s Effekt-Closure liefert ein
    // `VisualEffect`, kein `View` -- `.font` und `.foregroundStyle` gibt es
    // darauf nicht (von Xcode UND `swiftc -typecheck` bestaetigt, nicht nur
    // vermutet). Was `VisualEffect` anbietet, reicht aber, um dieselben
    // Zieltypografien zu treffen, ohne sie zu erfinden:
    //
    // Groesse -- exakt per Skalierung: jede Zeile rendert mit `basisGroesse`
    // (64pt fuers Gewicht, 44pt fuer die Wiederholungen); ein Glyph bei
    // 30/64 = 0,469 skaliert sieht aus wie 30pt der 64pt-Basis bzw. 20,6pt
    // der 44pt-Basis, bei 26/64 = 0,406 wie 26pt bzw. 17,9pt. Die Faktoren
    // 30/64 und 26/64 bleiben deshalb Verhaeltnisse, nicht absolute Groessen
    // -- bei der 44pt-Basis waeren absolute 30pt-Nachbarn fast so gross wie
    // die Auswahl, und die von SS7 verlangte Staffelung ginge verloren.
    //
    // Farbe -- naeherungsweise per Deckkraft ueber bekanntem Grund: das Rad
    // liegt immer auf `DesignSystem.Color.bg` (#0A0B0D), die Zeile selbst
    // steht fest auf `text` (#F2F4F7). "text bei Alpha ueber bg" trifft die
    // Zielfarben: 0,38 landet nahe `textFaint` (#5C636E), 0,15 nahe `line`
    // (#2A2E36) -- der Farbton faellt dabei minimal waermer aus als die
    // echten (etwas kuehleren) Tokens, was fuer zurueckgenommene Nachbarn
    // hinnehmbar ist. Die beiden Alphawerte setzen `bg` als Grund voraus --
    // stuende das Rad je auf `surface` statt `bg`, muessten sie neu
    // gerechnet werden.

    private func skalierung(fuer phase: Double) -> CGFloat {
        switch abs(phase) {
        case ..<0.25: 1.0
        case ..<0.75: 30.0 / 64.0
        default: 26.0 / 64.0
        }
    }

    private func deckkraft(fuer phase: Double) -> Double {
        switch abs(phase) {
        case ..<0.25: 1.0
        case ..<0.75: offen ? 0.38 : 0
        default: offen ? 0.15 : 0
        }
    }

    // MARK: - VoiceOver

    private var voWertMitAnschlag: String {
        guard amAnschlag, let anschlagText else { return voWert(auswahl) }
        return "\(voWert(auswahl)), \(anschlagText)"
    }

    /// Auf und Ab gehen genau einen Geraeteschritt (designsystem.md SS12).
    private func schiebe(um schritte: Int) {
        guard let index = werte.firstIndex(of: auswahl) else { return }
        let ziel = index + schritte
        guard werte.indices.contains(ziel) else {
            anschlagStoss += 1
            return
        }
        auswahl = werte[ziel]
    }
}

#Preview {
    struct Vorschau: View {
        @State private var gewicht = 80.0
        @State private var offen = true

        var body: some View {
            VStack(spacing: DesignSystem.Spacing.s32) {
                RastRad(
                    werte: Rastwerte.gewichte(min: 5, max: 150, schritt: 2.5),
                    auswahl: $gewicht,
                    offen: offen,
                    unterstrich: .akzent,
                    voLabel: "Gewicht",
                    voWert: Zahlformat.gewichtGesprochen,
                    anschlagText: "Maximum des Geräts erreicht",
                    text: Zahlformat.gewicht
                )
                Button(offen ? "Schließen" : "Öffnen") { offen.toggle() }
                    .foregroundStyle(DesignSystem.Color.accent)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignSystem.Color.bg)
        }
    }
    return Vorschau()
}
