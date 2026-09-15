import SwiftUI
// Fuer UIFont.capHeight in unterstrichVersatz -- SwiftUI allein garantiert
// den UIKit-Typ nicht.
import UIKit

/// Wie kraeftig die Rastlinie unter dem Rad liegt.
///
/// Nur noch eine Frage der Staerke, nicht der Farbe: beide Raeder rasten,
/// also tragen beide dieselbe accent-Linie. Die Wiederholungen bekommen
/// die duennere -- sie sind der zweite Wert der Zeile (44pt gegen 64pt),
/// und eine gleich dicke Linie unter der kleineren Zahl waere schwerer als
/// die unter der groesseren.
enum UnterstrichStil {
    case held        // Gewicht: 4pt
    case zweitwert   // Wiederholungen: 3pt
}

/// Wie das Rad eine Zeile zeigt: die gewaehlte in voller Groesse, die
/// Nachbarn kleiner und blasser (designsystem.md SS7).
enum Nachbarstufe: Equatable {
    case gewaehlt
    case nachbar
    case fern
}

/// Ein Wertrad, immer offen.
///
/// Der Kniff aus designsystem.md SS7: "die Linie bleibt liegen, die Zahlen
/// ziehen daran vorbei." Die Unterstreichung gehoert deshalb NICHT zur
/// scrollenden Zeile -- sie liegt statisch hinter dem Scroller auf Hoehe der
/// Mittelzeile. Seit Schnitt 3 gibt es keinen geschlossenen Zustand mehr
/// (Sammelstelle Punkt 11): gescrollt wird sofort, und die Linie ist von
/// Anfang an die Rastmarke.
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
    /// Wie viele Zeilen der Ausschnitt zeigt -- immer ungerade, die gewaehlte
    /// in der Mitte. Fuenf ist die Vorgabe (zwei Nachbarn je Richtung); der
    /// Satzpfad nimmt drei, weil er auf ein 667-pt-iPhone passen muss
    /// (Sammelstelle Punkt 12) und ein Nachbar fuer die Aussage des Rads
    /// reicht: wer 80,0 sieht, sieht auch, dass der naechste Schritt 82,5 ist.
    var sichtbareZeilen = 5

    @ScaledMetric(relativeTo: .body) private var zeilenhoehe: CGFloat = 44
    @State private var scrollPosition: Double?
    @State private var anschlagStoss = 0

    private var amAnschlag: Bool {
        guard anschlagText != nil else { return false }
        return Rastwerte.amAnschlag(auswahl, in: werte)
    }

    private var radhoehe: CGFloat { zeilenhoehe * CGFloat(sichtbareZeilen) }

    var body: some View {
        ZStack {
            unterstreichung
            scroller
        }
        .frame(height: radhoehe)
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

    /// Der Abstand von der Zeilenmitte zur Grundlinie der Ziffern.
    ///
    /// Der Scroller rastet mit `anchor: .center`, die Mitte der gewaehlten
    /// Zeile ist also bekannt. SwiftUI zentriert darin den Zeilenkasten, und
    /// der ist nicht symmetrisch: unter der Grundlinie liegt noch die
    /// Unterlaenge. Die Grundlinie sitzt deshalb um `(ascender + descender) / 2`
    /// unter der Mitte (`descender` ist negativ) -- nicht auf ihr. Ziffern
    /// stehen auf der Grundlinie, das ist also genau ihre Unterkante; `s8`
    /// ist der Abstand, der daraus eine Unterstreichung statt eines
    /// Anstossens macht.
    ///
    /// Aus der Schrift gerechnet und nicht als Zahl hingeschrieben, weil
    /// dasselbe Rad in zwei Groessen laeuft (64pt Gewicht, 44pt
    /// Wiederholungen) und ein fester Versatz nur fuer eine davon stimmte.
    private var unterstrichVersatz: CGFloat {
        let schrift = UIFont.systemFont(ofSize: basisGroesse, weight: .black)
        return (schrift.ascender + schrift.descender) / 2 + DesignSystem.Spacing.s8
    }

    /// Liegt fest. Bewegt sich nie -- das ist der ganze Punkt.
    ///
    /// Sie liegt UNTER der Zahl, nicht auf ihrer Mitte: eine Linie mitten
    /// durch die Ziffern markiert nicht, sie streicht durch.
    private var unterstreichung: some View {
        Rectangle()
            .fill(DesignSystem.Color.accent)
            .frame(height: unterstrich == .held ? 4 : 3)
            .offset(y: unterstrichVersatz)
    }

    /// Wo der Verlauf oben (und gespiegelt unten) voll deckend wird -- als
    /// Anteil der Radhoehe, weil LinearGradient in Anteilen rechnet, die
    /// Zeile aber in Punkten steht. Die voll deckende Mitte ist immer
    /// `zeilenhoehe * 1.8` hoch: die Versalhoehe der 64-pt-Ziffern liegt bei
    /// rund 46 pt, und ein Verlauf, der schon in der Mitte beginnt, blendet
    /// die gewaehlte Zahl selbst an -- sie saehe ausgegraut aus.
    private var verlaufsrand: CGFloat {
        max(0, (1 - (zeilenhoehe * 1.8) / radhoehe) / 2)
    }

    private var scroller: some View {
        // Die Effekt-Closure unten laeuft nonisolated und darf keinen
        // Instanzzustand lesen -- ein lokaler Int geht mit.
        let zeilen = sichtbareZeilen
        return ScrollView(.vertical, showsIndicators: false) {
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
                        // Ohne diese drei Zeilen kuerzte SwiftUI "100,5" zu
                        // "1..." -- ein Rad, das seinen eigenen Wert nicht
                        // zeigt, ist schlimmer als eine kleinere Ziffer.
                        // Der Regelfall bleibt unangetastet: geschrumpft
                        // wird nur, wo die Spalte wirklich nicht reicht
                        // (Geraet ohne Obergrenze, grosse Dynamic-Type-Stufen).
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .allowsTightening(true)
                        .frame(height: zeilenhoehe)
                        .frame(maxWidth: .infinity)
                        .scrollTransition(.interactive, axis: .vertical) { inhalt, phase in
                            let stufe = Self.nachbarstufe(phase: phase.value, sichtbareZeilen: zeilen)
                            return inhalt
                                .scaleEffect(Self.skalierung(stufe))
                                .opacity(Self.deckkraft(stufe))
                        }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollPosition, anchor: .center)
        // Damit Minimum und Maximum mittig einrasten koennen.
        .safeAreaPadding(.vertical, (radhoehe - zeilenhoehe) / 2)
        // Ausblendung nach bg, wie SS7 sie verlangt.
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: verlaufsrand),
                    .init(color: .black, location: 1 - verlaufsrand),
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
    // Nachbar (2 Zeilen Abstand) bei |phase| ~ 1,0.
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

    // static/nonisolated, weil scrollTransition's Effekt-Closure nonisolated
    // laeuft (sie bekommt ein VisualEffect, kein View) -- die drei Funktionen
    // duerfen deshalb nicht implizit @MainActor sein. Alle drei lesen keinen
    // Instanzzustand, sind also verlustfrei aus dem Actor loesbar.

    /// Phase -> Stufe, aus der Zeilenzahl gerechnet. `phase` ist auf [-1, 1]
    /// ueber den HALBEN Ausschnitt begrenzt: bei fuenf Zeilen liegt der erste
    /// Nachbar bei 0,5, bei drei Zeilen schon bei 1,0. Die Schwellen 0,5 und
    /// 1,5 ZEILEN sind fuer beide dieselben -- deshalb wird die Phase erst in
    /// Zeilen umgerechnet.
    nonisolated static func nachbarstufe(phase: Double, sichtbareZeilen: Int) -> Nachbarstufe {
        let halberAusschnitt = Double(sichtbareZeilen - 1) / 2
        return switch abs(phase) * halberAusschnitt {
        case ..<0.5: .gewaehlt
        case ..<1.5: .nachbar
        default: .fern
        }
    }

    private nonisolated static func skalierung(_ stufe: Nachbarstufe) -> CGFloat {
        switch stufe {
        case .gewaehlt: 1.0
        case .nachbar: 30.0 / 64.0
        case .fern: 26.0 / 64.0
        }
    }

    private nonisolated static func deckkraft(_ stufe: Nachbarstufe) -> Double {
        switch stufe {
        case .gewaehlt: 1.0
        case .nachbar: 0.38
        case .fern: 0.15
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

        var body: some View {
            VStack(spacing: DesignSystem.Spacing.s32) {
                RastRad(
                    werte: Rastwerte.gewichte(min: 5, max: 150, schritt: 2.5),
                    auswahl: $gewicht,
                    unterstrich: .held,
                    voLabel: "Gewicht",
                    voWert: Zahlformat.gewichtGesprochen,
                    anschlagText: "Maximum des Geräts erreicht",
                    text: Zahlformat.gewicht
                )
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignSystem.Color.bg)
        }
    }
    return Vorschau()
}
