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
        case .rueckblick(let daten):
            RueckblickAnsicht(start: start,
                              nummern: Rueckblicknummern(anzeigeSatz: satz, gesichert: daten.abgelehnt == nil,
                                                         satzZiel: start.satzZiel), daten: daten, pauseEnde: modell.pauseEnde,
                              beiSchliessen: { modell.rueckblickSchliessen() },
                              beiNaechsterSatz: { await modell.naechsterSatz() },
                              beiKorrigieren: { modell.umfangKorrigieren($0) })
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
                                  bestanden: bestanden(ablauf.schritt), warnend: ablauf.schritt == .aufstellen && ablauf.anweisung != .passt,
                                  dezent: ablauf.schritt == .satz, hervor: signalgelenke(start))
            }
            schritt(ablauf, start: start)
        }
    }

    /// Im Satz bleibt nur das Signalgelenk kraeftig (beide Seiten, die Seite wechselt mit der Person).
    private func signalgelenke(_ start: KameraStart) -> Set<Gelenk> {
        guard let signal = start.vorgabe.signal else { return [] }
        let l = signal.gelenke(.links), r = signal.gelenke(.rechts)
        return [l.0, l.1, l.2, r.0, r.1, r.2]
    }

    private func bestanden(_ schritt: KameraSatzAblauf.Schritt) -> Bool {
        switch schritt {
        case .aufstellen, .video, .fertig, .verloren: false
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
        case .satz:
            SatzSchritt(start: start, satz: satz, anzeige: Satzanzeige(ablauf), videoOffen: Bindable(modell).videoOffen,
                        beiSatzBeenden: { await modell.satzBeenden() }, beiOhneKamera: { modell.ohneKamera() })
        case .verloren:
            VerlorenSchritt(start: start, satz: satz, wiederholungen: ablauf.wiederholungen,
                            beiOhneKamera: { modell.ohneKamera() }, beiSatzBeenden: { await modell.satzBeenden() })
        case .vorlauf(let rest):
            VorlaufSchritt(start: start, satz: satz, rest: rest, beiOhneKamera: { modell.ohneKamera() },
                           bildrateZuNiedrig: ablauf.bildrateZuNiedrig)
        case .keineBewegung:
            HinweisSchritt(start: start, satz: satz, titel: "Bereit? Tippen zum Neustart",
                           beiKarte: { modell.neuStarten() }, beiOhneKamera: { modell.ohneKamera() })
        case .bewegungZuKlein:
            HinweisSchritt(start: start, satz: satz, titel: "Wir erkennen die Bewegung nicht sicher",
                           knopf: ("Ohne Kamera weiterzählen", { modell.ohneKamera() }),
                           beiOhneKamera: { modell.ohneKamera() })
        case .fertig:
            // Das Satzende wird gerade gesichert; der Rueckblick folgt.
            Color.clear
        }
    }

    private static func einstellungenOeffnen() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
