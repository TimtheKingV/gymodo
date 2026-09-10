import SwiftUI

/// Der Serien-Streifen am Kopf des Home-Tabs -- Flamme links, sieben
/// Tagesboxen rechts, Fussnote darunter.
///
/// Er steht an der Stelle der frueheren Kennzahlen-Zeile ("diese Woche /
/// gesamt / Tage her") und traegt deren Aussage mit: "diese Woche" liest
/// man an den Hanteln ab, "Tage her" am letzten Hantel-Tag, "gesamt"
/// steht in der Fussnote. Drei Zahlen, die dasselbe sagen wie ein Bild,
/// waeren eine Zahl zu viel und zwei Bilder zu wenig.
///
/// **Die Tagesbox ist die des Kurs-Wochenplans** (KurseWochenView,
/// `tagesboxen`): 44 pt, Radius 12, Kuerzel ueber der Zahl. Neu ist nur,
/// dass an einem Trainingstag die Hantel an die Stelle der Zahl tritt.
/// Zwei Wochenstreifen in einer App, die sich in Hoehe und Radius
/// unterscheiden, waeren zwei Entwuerfe.
///
/// **Den Akzent traegt die Flamme, nicht die Tage.** designsystem.md SS2
/// laesst genau eine Akzentflaeche je Screen zu; drei akzentgruene
/// Tagesboxen waeren drei, und im schummrigen Geraetebereich verloere der
/// Akzent damit die Signalwirkung, fuer die er gewaehlt wurde. Die Serie
/// ist der aktive Wert dieses Screens und erbt den Akzent von der
/// Kennzahl "diese Woche", die sie ersetzt. Die Tage tragen ihre Aussage
/// ueber Form und Fuellung: Hantel statt Zahl, surfaceRaised statt
/// nichts.
struct HomeSerieView: View {
    let stand: Serienstand
    let gesamt: Int
    let lastSessionAt: String?
    /// Vom Aufrufer, damit der Streifen keine eigene Uhr hat und in
    /// einer Vorschau ein fester Tag vorgegeben werden kann.
    let jetzt: Date

    var body: some View {
        let tage = HomeSerie.tage(stand)

        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text("DEINE SERIE")
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)

            HStack(spacing: DesignSystem.Spacing.s12) {
                flamme
                HStack(spacing: DesignSystem.Spacing.s4) {
                    ForEach(tage) { tagesbox($0) }
                }
            }

            Text(
                HomeSerie.fussnote(
                    gesamt: gesamt, lastSessionAt: lastSessionAt,
                    jetzt: jetzt, kalender: .current)
            )
            .font(.system(size: 12, weight: .semibold).monospacedDigit())
            .foregroundStyle(DesignSystem.Color.textFaint)
        }
        // EIN Element, nicht sieben plus Flamme: der Streifen ist nicht
        // bedienbar, und sieben einzeln vorgelesene Tagesboxen waeren nur
        // Weg zwischen der Ueberschrift und dem, was darunter steht.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(HomeSerie.vorlesetext(wochen: stand.weeks, tage: tage))
    }
}

private extension HomeSerieView {
    /// Gedeckt bei einer Serie von null -- die Zahl bleibt trotzdem
    /// stehen. Sie ist die Antwort auf "wie lange schon", und "0" ist
    /// eine Antwort; die Flamme sagt ueber die Farbe, dass gerade nichts
    /// laeuft.
    var laeuft: Bool { stand.weeks > 0 }

    var flamme: some View {
        VStack(spacing: DesignSystem.Spacing.s4) {
            HStack(spacing: DesignSystem.Spacing.s4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 21))
                    .foregroundStyle(
                        laeuft ? DesignSystem.Color.accent : DesignSystem.Color.textFaint)
                Text("\(stand.weeks)")
                    .font(.system(size: 27, weight: .black).monospacedDigit())
                    .foregroundStyle(
                        laeuft ? DesignSystem.Color.accent : DesignSystem.Color.textMuted)
            }
            Text(HomeSerie.wochenLabel(stand.weeks).uppercased())
                .font(.system(size: 10, weight: .heavy))
                .tracking(1)
                .foregroundStyle(
                    laeuft ? DesignSystem.Color.accent : DesignSystem.Color.textFaint)
        }
        .frame(width: 56)
    }

    /// Die Hantel ERSETZT die Tagesnummer, sie steht nicht daneben. Der
    /// Streifen beantwortet auf einen Blick "an welchen Tagen", und dafuer
    /// muss die Antwort die groesste Form in der Box sein. Das Datum steht
    /// im Kursplan, wo man Tage antippt -- hier tippt man nichts an.
    @ViewBuilder
    func tagesbox(_ tag: HomeSerieTag) -> some View {
        VStack(spacing: DesignSystem.Spacing.s4) {
            Text(tag.kuerzel)
                .font(.system(size: 10, weight: .heavy))
                .tracking(1)
                .foregroundStyle(
                    tag.trainiert || tag.istHeute
                        ? DesignSystem.Color.textMuted : DesignSystem.Color.textFaint)

            if tag.trainiert {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.text)
            } else {
                Text("\(tag.tagesnummer)")
                    .font(.system(size: 16, weight: .black).monospacedDigit())
                    .foregroundStyle(
                        tag.istHeute ? DesignSystem.Color.textMuted : DesignSystem.Color.textFaint)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(tag.trainiert ? DesignSystem.Color.surfaceRaised : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        // Heute traegt eine Kontur, keine Flaeche: die Fuellung ist schon
        // vergeben ("hier stand eine Einheit"), und beides zugleich muss
        // an einem Tag lesbar bleiben, an dem man trainiert hat.
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .stroke(DesignSystem.Color.line, lineWidth: tag.istHeute ? 1.5 : 0))
    }
}
