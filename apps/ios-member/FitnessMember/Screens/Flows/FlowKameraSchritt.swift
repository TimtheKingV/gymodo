import Koerperbild
import Sensorik
import SwiftUI

/// Was die Kamera-Phase vom Zaehler zeigt; als Wert, damit die Vorschau keine Kamera braucht.
struct FlowKameraAnzeige {
    let welle: Sollwelle
    let tempo: Uebungstempo
    let sollzeit: TimeInterval
    let spur: [KameraSatzAblauf.Spurpunkt]
    let wiederholungen: Int

    /// Ohne Zaehler (der Wechsel in die Arbeitsphase ist noch nicht verarbeitet): stehende Welle, 0 Wdh.
    init(zaehler: FlowZaehler?, start: KameraStart) {
        welle = zaehler?.welle ?? Sollwelle(vorgabe: start.tempo.vorgabe)
        tempo = start.tempo
        sollzeit = zaehler?.sollzeit ?? 0
        spur = zaehler?.spur ?? []
        wiederholungen = zaehler?.wiederholungen ?? 0
    }

    init(welle: Sollwelle, tempo: Uebungstempo, sollzeit: TimeInterval, spur: [KameraSatzAblauf.Spurpunkt],
         wiederholungen: Int) {
        self.welle = welle; self.tempo = tempo; self.sollzeit = sollzeit; self.spur = spur
        self.wiederholungen = wiederholungen
    }
}

/// Die Arbeitsphase eines zaehlbaren Flow-Schritts: Livebild mit Strichfigur (dezent), die Tempo-Welle,
/// die Zahl gross, die Hinweiszeile; darueber "SCHRITT n VON m" und die Restzeit, darunter Name und
/// "Als Nächstes: …". Kein Phasenwort, keine Takt-Pille.
struct FlowKameraSchritt: View {
    let ueberschrift: String
    let restS: Int
    let name: String
    let naechsterName: String?
    let profil: Kameraprofil
    let ziel: Livebildziel
    let skelett: Skelett?
    let anzeige: FlowKameraAnzeige
    let hinweis: String?

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.s16) {
            Text(ueberschrift)
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                .overlay(alignment: .topTrailing) { FlowZeitPille(restS: restS) }
            flaeche
            VStack(spacing: DesignSystem.Spacing.s8) {
                Text(name)
                    .font(DesignSystem.Typography.detailScreentitel)
                    .foregroundStyle(DesignSystem.Color.text)
                    .multilineTextAlignment(.center)
                if let naechsterName {
                    Text("Als Nächstes: \(naechsterName)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private var flaeche: some View {
        ZStack(alignment: .bottom) {
            KameraBildflaeche(ziel: ziel, skelett: skelett, profil: profil, dezent: true, mitRahmen: false)
            VStack(spacing: DesignSystem.Spacing.s8) {
                if let hinweis {
                    Text(hinweis)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DesignSystem.Color.warn)
                        .multilineTextAlignment(.center)
                }
                Text("\(anzeige.wiederholungen) Wdh.")
                    .font(DesignSystem.Typography.wertHeld)
                    .foregroundStyle(DesignSystem.Color.text)
                    .monospacedDigit()
                    .accessibilityLabel("\(anzeige.wiederholungen) Wiederholungen")
                Wellenband(welle: anzeige.welle, tempo: anzeige.tempo, sollzeit: anzeige.sollzeit, spur: anzeige.spur,
                           punkt: anzeige.spur.last?.lage, wartend: hinweis != nil,
                           punktSicher: anzeige.spur.last?.sicher ?? true)
                    .frame(height: 100)
            }
            .padding(.vertical, DesignSystem.Spacing.s12)
            .frame(maxWidth: .infinity)
            .background(DesignSystem.Color.bg.opacity(0.78))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt))
    }
}

/// Liest das Modell in einer eigenen Ansicht: die Bilder der Kamera werten nur diesen Body neu aus,
/// nicht den ganzen Flow-Lauf.
struct FlowKameraSchrittLive: View {
    let modell: FlowKameraModell
    let seite: FlowVideoSeite
    let name: String
    let start: KameraStart

    var body: some View {
        FlowKameraSchritt(ueberschrift: seite.ueberschrift, restS: seite.restS, name: name,
                          naechsterName: seite.naechsterName, profil: start.vorgabe.profil, ziel: modell.ziel,
                          skelett: modell.letztesSkelett,
                          anzeige: FlowKameraAnzeige(zaehler: modell.zaehler, start: start), hinweis: modell.hinweis)
    }
}

/// Im Fertig-Bildschirm: die gezaehlten Wiederholungen je Kamera-Schritt ("Liegestütze 14"); leer: nichts.
struct FlowGezaehltListe: View {
    let zeilen: [FlowFertigZeile]

    var body: some View {
        if !zeilen.isEmpty {
            VStack(spacing: DesignSystem.Spacing.s8) {
                ForEach(zeilen) { zeile in
                    HStack {
                        Text(zeile.name)
                            .foregroundStyle(DesignSystem.Color.text)
                        Spacer(minLength: DesignSystem.Spacing.s16)
                        Text("\(zeile.wiederholungen)")
                            .font(.system(size: 17, weight: .heavy).monospacedDigit())
                            .foregroundStyle(DesignSystem.Color.accent)
                    }
                    .font(DesignSystem.Typography.fliesstext)
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: 320)
            .padding(.top, DesignSystem.Spacing.s8)
        }
    }
}

#if DEBUG
@MainActor private enum FlowKameraVorschau {
    static let tempo = Uebungstempo(senken: 1, halten: 0, heben: 1, beginntMit: .senken)
    static let welle = Sollwelle(vorgabe: tempo.vorgabe)

    /// Eine Spur, die der Welle folgt, bis `sollzeit`.
    static func spur(bis sollzeit: TimeInterval) -> [KameraSatzAblauf.Spurpunkt] {
        stride(from: max(0, sollzeit - 4), through: sollzeit, by: 1.0 / 30).map {
            KameraSatzAblauf.Spurpunkt(sollzeit: $0, lage: welle.lage(bei: $0), sicher: true)
        }
    }

    static func schritt(hinweis: String?) -> some View {
        FlowKameraSchritt(ueberschrift: "SCHRITT 12 VON 20", restS: 31, name: "Liegestütze",
                          naechsterName: "Leg Drop & Pull", profil: .stuetzBoden, ziel: .leer,
                          skelett: KameraVorschau.skelett(),
                          anzeige: FlowKameraAnzeige(welle: welle, tempo: tempo, sollzeit: 9.3, spur: spur(bis: 9.3),
                                                     wiederholungen: 14),
                          hinweis: hinweis)
            .padding(.horizontal, 20)
            .padding(.vertical, DesignSystem.Spacing.s16)
            .background(DesignSystem.Color.bg)
    }
}

#Preview("Kamera-Phase") {
    FlowKameraVorschau.schritt(hinweis: nil)
}

#Preview("Kamera-Phase, nicht erkannt") {
    FlowKameraVorschau.schritt(hinweis: FlowKameraModell.hinweisText)
}

#Preview("Fertig: gezaehlte Schritte") {
    FlowGezaehltListe(zeilen: [FlowFertigZeile(schrittIndex: 1, name: "Kniebeuge", wiederholungen: 18),
                               FlowFertigZeile(schrittIndex: 11, name: "Liegestütze", wiederholungen: 14)])
        .padding(20)
        .background(DesignSystem.Color.bg)
}

#Preview("Kamera-Phase, echter Zaehler") {
    let vorgabe = Kameravorgabe(profil: .ganzkoerperStehend, signal: .knie, seite: .beide)!
    let start = KameraStart(exerciseId: "x", name: "Kniebeuge", geraet: nil, vorgabe: vorgabe,
                            tempo: FlowKameraVorschau.tempo, sollWiederholungen: nil, satzZiel: 1)
    var zaehler = FlowZaehler(vorgabe: vorgabe, tempo: FlowKameraVorschau.tempo)
    zaehler.start(t: 0)
    for i in 0..<60 { zaehler.bild(t: Double(i) / 30, skelett: KameraVorschau.skelett()) }
    return FlowKameraSchritt(ueberschrift: "SCHRITT 3 VON 20", restS: 38, name: start.name, naechsterName: nil,
                             profil: vorgabe.profil, ziel: .leer, skelett: KameraVorschau.skelett(),
                             anzeige: FlowKameraAnzeige(zaehler: zaehler, start: start), hinweis: nil)
        .padding(20)
        .background(DesignSystem.Color.bg)
}
#endif
