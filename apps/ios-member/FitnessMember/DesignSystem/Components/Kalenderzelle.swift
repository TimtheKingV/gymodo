import SwiftUI

/// Was in der Zelle steht. Die Hantel ERSETZT die Tagesnummer, sie steht
/// nicht daneben: ein Wochenstreifen beantwortet auf einen Blick "an
/// welchen Tagen", und dafuer muss die Antwort die groesste Form in der
/// Zelle sein.
enum Kalenderzelleninhalt: Equatable {
    case zahl(Int)
    case hantel
}

/// Die Farbregel der Tageszelle, ohne SwiftUI-View -- die pruefbare
/// Haelfte der Komponente (KalenderzelleTests).
///
/// Sie steht getrennt, weil sie das eigentlich Strittige ist: die beiden
/// Kalender beantworteten "gewaehlt" und "heute" frueher verschieden,
/// und eine Regel, die in einem `body` steckt, laesst sich nicht gegen
/// einen Wert pruefen, sondern nur ansehen.
enum Kalenderfarben {
    /// Gewaehlt schlaegt trainiert: sonst haette ein trainierter Tag eine
    /// andere Auswahl-Fuellung als ein leerer, und "gewaehlt" waere keine
    /// Aussage mehr, sondern zwei.
    static func fuellung(istGewaehlt: Bool, trainiert: Bool) -> Color {
        if istGewaehlt { return DesignSystem.Color.text }
        if trainiert { return DesignSystem.Color.surfaceRaised }
        return .clear
    }

    /// Auf der weissen Fuellung steht der Hintergrundton -- weiss auf
    /// weiss waere unsichtbar. Darunter heben trainiert und heute den
    /// Vordergrund je eine Stufe an, damit der Ring allein nicht der
    /// einzige Hinweis auf heute bleibt.
    static func vordergrund(istGewaehlt: Bool, trainiert: Bool, istHeute: Bool) -> Color {
        if istGewaehlt { return DesignSystem.Color.bg }
        if trainiert { return DesignSystem.Color.text }
        return istHeute ? DesignSystem.Color.textMuted : DesignSystem.Color.textFaint
    }

    /// nil heisst: kein Ring. Der Ring haengt an nichts ausser heute --
    /// nur dadurch koennen heute, trainiert und gewaehlt gleichzeitig an
    /// einem Tag stehen, ohne sich zu ueberschreiben.
    static func ring(istHeute: Bool) -> Color? {
        istHeute ? DesignSystem.Color.accent : nil
    }
}

/// Die Tageszelle beider Kalender -- der 40-pt-Kreis, ohne den
/// Buchstaben darueber und ohne den Punkt darunter: die gehoeren dem
/// jeweiligen Streifen, nicht der Zelle.
///
/// **Zwei Kanaele an der Tageszelle, und nur zwei.** Die FUELLUNG sagt,
/// was der Tag ist (nichts, trainiert, gewaehlt), der RING sagt heute.
/// Weil sie getrennt sind, kollidiert kein Zustand mit einem anderen --
/// ein Tag kann zugleich heute, trainiert und gewaehlt sein, und alle
/// drei bleiben lesbar. Der Akzent bleibt dabei eine Linie, keine
/// Flaeche: designsystem.md SS2 laesst genau eine Akzentflaeche je
/// Screen zu, und die traegt auf Home die Flamme, im Kursplan der
/// Umschalter „Angemeldet/Alle Kurse“.
///
/// **Eine Zelle fuer beide Kalender, nicht zwei.** Home fuellte die
/// Auswahl mit `line` und ringte heute, der Kursplan fuellte sie mit
/// `accent` und markierte heute gar nicht -- zwei Wochenstreifen in
/// einer App, die dieselbe Frage verschieden beantworten, sind zwei
/// Entwuerfe.
struct Kalenderzelle: View {
    let inhalt: Kalenderzelleninhalt
    let istGewaehlt: Bool
    let istHeute: Bool
    /// Ein Tag mit abgeschlossener Einheit. Der Kursplan kennt das nicht
    /// und uebergibt `false`.
    var trainiert: Bool = false
    /// Ein Tag, der nur das Raster fuellt (Nachbarmonat im Monatsgitter).
    /// Er wird gedimmt statt weggelassen, sonst rutschte das Gitter.
    var gedeckt: Bool = false

    var body: some View {
        ZStack {
            Circle().fill(Kalenderfarben.fuellung(istGewaehlt: istGewaehlt, trainiert: trainiert))

            switch inhalt {
            case .hantel:
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 15, weight: .semibold))
            case .zahl(let nummer):
                Text("\(nummer)")
                    .font(.system(size: 16, weight: .black).monospacedDigit())
            }
        }
        .foregroundStyle(
            Kalenderfarben.vordergrund(
                istGewaehlt: istGewaehlt, trainiert: trainiert, istHeute: istHeute))
        .frame(width: 40, height: 40)
        // strokeBorder statt stroke: der Ring liegt INNEN und laesst die
        // Zelle 40 pt breit, sonst sprungen die Spalten um den heutigen
        // Tag herum auseinander.
        .overlay {
            if let ring = Kalenderfarben.ring(istHeute: istHeute) {
                Circle().strokeBorder(ring, lineWidth: 1.5)
            }
        }
        .opacity(gedeckt ? 0.4 : 1)
    }
}

#Preview {
    HStack(spacing: DesignSystem.Spacing.s8) {
        Kalenderzelle(inhalt: .zahl(3), istGewaehlt: false, istHeute: false)
        Kalenderzelle(inhalt: .zahl(4), istGewaehlt: false, istHeute: true)
        Kalenderzelle(inhalt: .hantel, istGewaehlt: false, istHeute: false, trainiert: true)
        Kalenderzelle(inhalt: .hantel, istGewaehlt: true, istHeute: true, trainiert: true)
        Kalenderzelle(inhalt: .zahl(7), istGewaehlt: false, istHeute: false, gedeckt: true)
    }
    .padding()
    .background(DesignSystem.Color.bg)
}
