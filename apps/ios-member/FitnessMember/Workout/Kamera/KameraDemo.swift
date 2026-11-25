#if DEBUG
import Koerperbild
import SwiftUI

/// Nur Debug: oeffnet den Kamera-Ablauf ohne Anmeldung und ohne Datenbank, fuer
/// Vorfuehrungen im Simulator. Start: `-kameraDemo <Uebungsname>` (ein Name aus
/// KameraTestprofile.json), zusammen mit `-kameraAbspielen <Repo-Wurzel>`.
/// Gesichert wird nichts; die Naht zaehlt nur mit.
@MainActor @Observable
final class KameraDemoNaht: KameraNaht {
    let kameraStart: KameraStart?
    var kameraWahl: KameraWahl = .mitKamera
    var kameraEinstieg: KameraEinstieg = .aufstellen
    var anzeigeSatz = 1
    var satzAbgelehnt: String?
    var offen = true
    var gesichert: [Int] = []
    private var pause: Resttimer?
    var laufendePause: Resttimer? { pause.flatMap { $0.laeuft() ? $0 : nil } }

    init?(name: String) {
        guard let e = KameraTestprofile.eintraege[name],
              let profil = Kameraprofil(rawValue: e.kamera.profil),
              let signal = e.kamera.signal.flatMap(Gelenkwinkel.init(rawValue:)),
              let phase = Tempophase(rawValue: e.kamera.beginntMit),
              let vorgabe = Kameravorgabe(profil: profil, signal: signal,
                                          seite: e.kamera.seite.flatMap(Seitenwahl.init(rawValue:)) ?? .beide)
        else { return nil }
        let tempo = Uebungstempo(senken: e.tempo.senkenS, halten: e.tempo.haltenS, heben: e.tempo.hebenS, beginntMit: phase)
        kameraStart = KameraStart(exerciseId: e.key, name: name, geraet: nil, vorgabe: vorgabe, tempo: tempo,
                                  sollWiederholungen: 10, satzZiel: 3)
    }

    func kameraSatzSichern(wiederholungen: Int) async -> KameraSichern {
        gesichert.append(wiederholungen)
        let letzter = gesichert.count >= 3
        anzeigeSatz = gesichert.count + 1
        if !letzter { pause = Resttimer(dauer: 20) }
        return .gesichert(letzterSatz: letzter)
    }

    func kameraVerlassen(gezaehlt: Int?) { offen = false }
    func kameraAblaufSchliessen() { offen = false }
    func kameraWiederAufnehmen() { offen = true }
    func umfangNachtragen(_ wiederholungen: Int) {
        if !gesichert.isEmpty { gesichert[gesichert.count - 1] = wiederholungen }
    }
    func pauseBeenden() {
        pause = nil
        anzeigeSatz = gesichert.count + 1
    }
    func weitererSatz() {
        pause = nil
        anzeigeSatz = gesichert.count + 1
    }
}

struct KameraDemoAnsicht: View {
    @State private var naht: KameraDemoNaht?
    @State private var modell: KameraAblaufModell?
    let name: String

    var body: some View {
        Group {
            if let naht {
                if naht.offen, let modell {
                    KameraAblaufAnsicht(modell: modell, start: naht.kameraStart, satz: naht.anzeigeSatz)
                        .task {
                            // `-kameraDemoSatzende <s>`: beendet den Satz nach s Sekunden (Simulator ohne Tippen).
                            let s = UserDefaults.standard.double(forKey: "kameraDemoSatzende")
                            guard s > 0 else { return }
                            try? await Task.sleep(for: .seconds(s))
                            await modell.satzBeenden()
                        }
                } else if !naht.offen {
                    VStack(spacing: 16) {
                        Text("Ablauf geschlossen").font(.title2.bold())
                        Text("Gesichert: \(naht.gesichert.map(String.init).joined(separator: ", "))")
                        Button("Wieder öffnen") { naht.offen = true }
                    }
                }
            } else {
                Text("Unbekannte Übung: \(name)")
            }
        }
        .onAppear {
            guard naht == nil, let neu = KameraDemoNaht(name: name) else { return }
            naht = neu
            modell = KameraAblaufModell(naht: neu)
        }
    }

    static var name: String? {
        let wert = UserDefaults.standard.string(forKey: "kameraDemo")
        return (wert?.isEmpty ?? true) ? nil : wert
    }
}
#endif
