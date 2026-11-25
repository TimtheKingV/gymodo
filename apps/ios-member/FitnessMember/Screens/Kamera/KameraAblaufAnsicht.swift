import Koerperbild
import SwiftUI
import UIKit

/// Der Inhalt des Vollbilds: haelt genau ein `KameraAblaufModell` je Oeffnung. Das Modell entsteht erst beim
/// Erscheinen (nicht in `init`, das SwiftUI bei jeder Auswertung des Elternbodys neu aufruft) und lebt in `@State`.
struct KameraAblaufCover: View {
    @State private var modell: KameraAblaufModell?
    @State private var start: KameraStart?
    private let naht: any KameraNaht

    init(naht: any KameraNaht) {
        self.naht = naht
    }

    var body: some View {
        Group {
            if let modell {
                KameraAblaufAnsicht(modell: modell, start: start, satz: naht.anzeigeSatz)
            } else {
                DesignSystem.Color.bg.ignoresSafeArea()
            }
        }
        .onAppear {
            guard modell == nil else { return }
            start = naht.kameraStart
            modell = KameraAblaufModell(naht: naht)
        }
    }
}

/// Die Wurzel: schaltet nach `ansicht` und `schritt`.
struct KameraAblaufAnsicht: View {
    let modell: KameraAblaufModell
    let start: KameraStart?
    let satz: Int
    @Environment(\.scenePhase) private var szenenphase

    var body: some View {
        Group {
            if let start { inhalt(start) } else { DesignSystem.Color.bg.ignoresSafeArea() }
        }
        .task { await modell.erscheint() }
        .onDisappear { modell.verschwindet() }
        .onChange(of: szenenphase) { _, neu in modell.szene(aktiv: neu == .active) }
        .preferredColorScheme(.dark)
    }

    private var ziel: Livebildziel {
        Livebildziel(ebene: modell.quelle?.anzeige, gespiegelt: modell.quelle is FrontkameraQuelle)
    }

    @ViewBuilder private func inhalt(_ start: KameraStart) -> some View {
        switch modell.ansicht {
        case .erlaubnisFehlt:
            ErlaubnisFehltSchritt(beiEinstellungen: Self.einstellungenOeffnen, beiOhneKamera: { modell.ohneKamera() })
        case .kameraFehlt:
            KameraFehltSchritt(beiOhneKamera: { modell.ohneKamera() })
        case .rueckblick:
            // Task 9 ersetzt das durch den Rueckblick.
            PlatzhalterSchritt(text: "Satz geschafft", beiOhneKamera: { modell.rueckblickSchliessen() })
        case .ablauf:
            if let ablauf = modell.ablauf { ablaufInhalt(ablauf, start: start) } else { DesignSystem.Color.bg.ignoresSafeArea() }
        }
    }

    /// Die Schritte mit Kamerabild.
    private func zeigtKamera(_ schritt: KameraSatzAblauf.Schritt) -> Bool {
        switch schritt {
        case .aufstellen, .countdown, .satz, .verloren, .vorlauf, .keineBewegung, .bewegungZuKlein: true
        case .video, .fertig: false
        }
    }

    /// EIN Livebild unter allen Kamera-Schritten, die Schritte liegen als Ueberlagerung darauf: so wechselt die
    /// geteilte Ebene der Quelle nie die Ansicht (Aufstellen -> Countdown -> Satz).
    @ViewBuilder private func ablaufInhalt(_ ablauf: KameraSatzAblauf, start: KameraStart) -> some View {
        ZStack {
            if zeigtKamera(ablauf.schritt) {
                KameraBildflaeche(ziel: ziel, skelett: modell.letztesSkelett, profil: start.vorgabe.profil,
                                  bestanden: bestanden(ablauf.schritt), warnend: ablauf.schritt == .aufstellen && ablauf.anweisung != .passt)
            }
            schritt(ablauf, start: start)
        }
    }

    private func bestanden(_ schritt: KameraSatzAblauf.Schritt) -> Bool {
        switch schritt {
        case .aufstellen, .video, .fertig: false
        default: true
        }
    }

    @ViewBuilder private func schritt(_ ablauf: KameraSatzAblauf, start: KameraStart) -> some View {
        switch ablauf.schritt {
        case .video:
            UebungsvideoSchritt(start: start, welle: ablauf.welle,
                                beiHandyAufstellen: { await modell.handyAufstellen() },
                                beiOhneKamera: { modell.ohneKamera() })
        case .aufstellen:
            AufstellSchritt(start: start, anweisung: ablauf.anweisung, fehlendeGruppen: ablauf.fehlendeGruppen,
                            beiOhneKamera: { modell.ohneKamera() })
        case .countdown(let rest):
            CountdownSchritt(start: start, satz: satz, rest: rest,
                             beiAbbrechen: { modell.abbrechen() }, beiOhneKamera: { modell.ohneKamera() })
        case .satz, .verloren, .vorlauf, .keineBewegung, .bewegungZuKlein, .fertig:
            // Task 9 baut Satz, Tracking verloren, Vorlauf und die Fehlerfaelle.
            PlatzhalterSchritt(text: "Satz läuft", beiOhneKamera: { modell.ohneKamera() })
        }
    }

    private static func einstellungenOeffnen() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

/// Bis Task 9 die Schritte baut: eine schlichte Flaeche mit Ausweg.
private struct PlatzhalterSchritt: View {
    let text: String
    let beiOhneKamera: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.s16) {
            Spacer()
            Text(text).font(.system(size: 22, weight: .heavy))
            Spacer()
            PrimaryButton(title: "Weiter") { beiOhneKamera() }
        }
        .padding(DesignSystem.Spacing.s16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Color.bg.ignoresSafeArea())
        .foregroundStyle(DesignSystem.Color.text)
    }
}
