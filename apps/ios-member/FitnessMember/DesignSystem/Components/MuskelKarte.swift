import SwiftUI

/// "Beanspruchte Muskeln" in der Einweisung (designsystem.md SS13.1):
/// Vorder- und Rueckseite nebeneinander, darunter je Muskel eine Zeile.
///
/// Das Modell ist schematisch. Es zeigt nur, welche Muskeln eine Uebung
/// beansprucht und in welcher Rolle -- weder Aktivierungsstaerke noch EMG.
/// Die Abstufung der unterstuetzenden Toene folgt allein ihrer Reihenfolge
/// in der Uebung. Das gehoert in den Code, nicht in die Oberflaeche.
/// Fachliche Freigabe der Grafiken steht noch aus (README Rev. 4).
///
/// Hat kein Muskel eine Flaeche (etwa nur `deep_core`), rendert die Karte
/// nichts: ein Modell ohne jede Hervorhebung saehe aus wie "nichts zu tun".
struct MuskelKarte: View {
    let muskeln: [GeraetMuskel]
    let geschlecht: Geschlecht?

    init(muskeln: [GeraetMuskel], geschlecht: Geschlecht?) {
        self.muskeln = muskeln
        self.geschlecht = geschlecht
    }

    var body: some View {
        if MuskelModell.zeigtModell(muskeln) {
            karte
        } else {
            EmptyView()
        }
    }

    private var karte: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
            Text("Beanspruchte Muskeln".uppercased())
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)

            VStack(spacing: DesignSystem.Spacing.s8) {
                MuskelFigur(muskeln: muskeln, geschlecht: geschlecht)
                HStack(spacing: 0) {
                    ansichtsname("Vorderseite")
                    ansichtsname("Rückseite")
                }
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
                ForEach(Array(muskeln.enumerated()), id: \.offset) { _, muskel in
                    legendenzeile(muskel)
                }
            }
        }
        .padding(DesignSystem.Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt)
                .stroke(DesignSystem.Color.line, lineWidth: 1)
        )
        // Die Figur ist fuer VoiceOver verborgen; die Karte liest sich als
        // ein Satz mit allen Muskeln und Rollen.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.vorlesetext(muskeln))
    }

    private func ansichtsname(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(DesignSystem.Color.textFaint)
            .frame(maxWidth: .infinity)
    }

    private func legendenzeile(_ muskel: GeraetMuskel) -> some View {
        HStack(spacing: DesignSystem.Spacing.s8) {
            Circle()
                .fill(MuskelModell.fuellung(fuer: muskel.key, in: muskeln) ?? DesignSystem.Color.muskelInaktiv)
                .frame(width: 10, height: 10)
            Text(muskel.name)
                .font(DesignSystem.Typography.fliesstext)
                .foregroundStyle(DesignSystem.Color.text)
            Spacer(minLength: DesignSystem.Spacing.s8)
            Text(Self.rollenname(muskel.role))
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
    }

    nonisolated static func rollenname(_ rolle: GeraetMuskel.Rolle) -> String {
        switch rolle {
        case .primary: return "Hauptmuskel"
        case .secondary: return "Unterstützend"
        }
    }

    /// "Beanspruchte Muskeln: Brust, Hauptmuskel; Trizeps, unterstützend"
    nonisolated static func vorlesetext(_ muskeln: [GeraetMuskel]) -> String {
        let teile = muskeln.map { muskel in
            "\(muskel.name), \(muskel.role == .primary ? "Hauptmuskel" : "unterstützend")"
        }
        return "Beanspruchte Muskeln: " + teile.joined(separator: "; ")
    }
}

/// Beide Ansichten in einem Canvas, auf die Breite skaliert. Das
/// Seitenverhaeltnis haengt nur am Modell (maennlich 1860:1310, weiblich
/// 1860:1538), nie an den Muskeln -- die Karte springt nicht.
struct MuskelFigur: View {
    enum Ansicht { case vorne, hinten }

    let farben: [String: Color]
    let geschlecht: Geschlecht?
    let ansichten: Set<Ansicht>
    /// Duenne Linien fuer die Figur im Kleinformat (Trainingskarte): bei
    /// 36 pt Breite waeren die Linien der Karte (SS13.1) ein Klumpen.
    let kompakt: Bool

    init(
        farben: [String: Color], geschlecht: Geschlecht?,
        ansichten: Set<Ansicht> = [.vorne, .hinten], kompakt: Bool = false
    ) {
        self.farben = farben
        self.geschlecht = geschlecht
        self.ansichten = ansichten
        self.kompakt = kompakt
    }

    /// Die Karte der Einweisung: Farben aus den Rollen der Uebung.
    init(muskeln: [GeraetMuskel], geschlecht: Geschlecht?) {
        self.init(
            farben: Dictionary(
                muskeln.map { ($0.key, MuskelModell.fuellung(fuer: $0.key, in: muskeln)) },
                uniquingKeysWith: { erste, _ in erste }
            ).compactMapValues { $0 },
            geschlecht: geschlecht)
    }

    /// Abstand zwischen Vorder- und Rueckseite in SVG-Einheiten.
    nonisolated static let abstand: CGFloat = 60

    var body: some View {
        if let geometrie = MuskelModell.geometrie {
            let modell = geschlecht == .weiblich ? geometrie.weiblich : geometrie.maennlich
            // Nur die gewaehlten Ansichten, in fester Reihenfolge; ein
            // Abstand nur zwischen zweien.
            let gewaehlt: [MuskelGeometrie.Ansicht] =
                (ansichten.contains(.vorne) ? [modell.vorne] : [])
                + (ansichten.contains(.hinten) ? [modell.hinten] : [])
            let breite = gewaehlt.map(\.viewBox.width).reduce(0, +) + Self.abstand * CGFloat(max(0, gewaehlt.count - 1))
            let hoehe = gewaehlt.map(\.viewBox.height).max() ?? 1
            let farben = farben
            let kompakt = kompakt

            Canvas { kontext, groesse in
                let massstab = groesse.width / breite
                kontext.scaleBy(x: massstab, y: massstab)
                var versatz: CGFloat = 0
                for ansicht in gewaehlt {
                    Self.zeichne(ansicht, versatz: versatz, farben: farben, kompakt: kompakt, in: kontext)
                    versatz += ansicht.viewBox.width + Self.abstand
                }
            }
            .aspectRatio(breite / hoehe, contentMode: .fit)
            .accessibilityHidden(true)
        }
    }

    /// Kopf, Hals, Haende, Fuesse und Knie sind die `detail`-Pfade und nie
    /// Muskeln. Sie stehen im hellen Grau der nicht beanspruchten Muskeln
    /// statt im Dunkel der Haut -- sonst sah die Figur kopflos aus (Testnotiz
    /// 17.10., #5). Sie werden nie gruen. Das Modell fuehrt keinen Nacken-
    /// muskel (README Rev. 4: Sehnen und Gelenke bleiben neutral), also
    /// auch die Straenge am Hals.
    nonisolated static let detailFuellung = DesignSystem.Color.muskelInaktiv

    /// Linienstaerken in SVG-Einheiten (SS13.1), skalieren mit der Karte.
    nonisolated private static let koerperLinie: CGFloat = 2.3
    nonisolated private static let detailLinie: CGFloat = 1.1
    nonisolated private static let muskelKante: CGFloat = 3.2
    nonisolated private static let kompaktFaktor: CGFloat = 0.5

    nonisolated private static func zeichne(
        _ ansicht: MuskelGeometrie.Ansicht,
        versatz: CGFloat,
        farben: [String: Color],
        kompakt: Bool,
        in basis: GraphicsContext
    ) {
        var kontext = basis
        kontext.translateBy(x: versatz - ansicht.viewBox.minX, y: -ansicht.viewBox.minY)
        kontext.clip(to: Path(ansicht.viewBox))

        let haut = GraphicsContext.Shading.color(DesignSystem.Color.muskelHaut)
        let neutral = GraphicsContext.Shading.color(detailFuellung)
        let linie = GraphicsContext.Shading.color(DesignSystem.Color.muskelLinie)
        // Im Kleinformat mal 0,5: dieselbe Wirkung bei einem Zehntel der Breite.
        let faktor: CGFloat = kompakt ? kompaktFaktor : 1
        for pfad in ansicht.body {
            kontext.fill(pfad, with: haut)
            kontext.stroke(pfad, with: linie, lineWidth: koerperLinie * faktor)
        }
        for pfad in ansicht.detail {
            kontext.fill(pfad, with: neutral)
            kontext.stroke(pfad, with: linie, lineWidth: detailLinie * faktor)
        }

        let kante = GraphicsContext.Shading.color(DesignSystem.Color.muskelKante)
        let kantenstil = StrokeStyle(lineWidth: muskelKante * faktor, lineJoin: .round)
        for flaeche in ansicht.muskeln {
            // Wie clip-path im SVG: der Ausschnitt schneidet Flaeche und
            // Kante, damit an der Schnittkante keine zusaetzliche Linie entsteht.
            var muskelKontext = kontext
            if let rechteck = flaeche.clip { muskelKontext.clip(to: Path(rechteck)) }
            if let umriss = flaeche.clipPfad { muskelKontext.clip(to: umriss) }
            let farbe = farben[flaeche.muscle] ?? DesignSystem.Color.muskelInaktiv
            muskelKontext.fill(flaeche.pfad, with: .color(farbe), style: FillStyle(eoFill: flaeche.geradeUngerade))
            muskelKontext.stroke(flaeche.pfad, with: kante, style: kantenstil)
        }
    }
}

#Preview("Brustpresse") {
    ScrollView {
        VStack(spacing: DesignSystem.Spacing.s16) {
            MuskelKarte(
                muskeln: [
                    GeraetMuskel(key: "pectorals", name: "Brust", role: .primary),
                    GeraetMuskel(key: "triceps", name: "Trizeps", role: .secondary),
                    GeraetMuskel(key: "deltoid_anterior", name: "Vordere Schulter", role: .secondary),
                ],
                geschlecht: .maennlich
            )
            MuskelKarte(
                muskeln: [
                    GeraetMuskel(key: "pectorals", name: "Brust", role: .primary),
                    GeraetMuskel(key: "triceps", name: "Trizeps", role: .secondary),
                    GeraetMuskel(key: "deltoid_anterior", name: "Vordere Schulter", role: .secondary),
                ],
                geschlecht: .weiblich
            )
        }
        .padding(DesignSystem.Spacing.s16)
    }
    .background(DesignSystem.Color.bg)
}
