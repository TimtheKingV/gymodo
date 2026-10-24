import SwiftUI

/// Die Pause zwischen zwei Zirkel-Uebungen (Spec Mini-Zirkel 21.10.,
/// Entscheidungen 5 und 6).
///
/// Anders als das PausenRad am Geraet ist hier nicht die Uhr das
/// Wichtigste, sondern die naechste Uebung: wer im Zirkel trainiert, geht
/// in der Pause zum naechsten Geraet und muss es auf einen Blick erkennen.
/// Deshalb ein kleinerer Ring oben und darunter die Karte "Als Nächstes"
/// mit Video (Anti-Ziel "Pausenscreen nicht ueberladen").
///
/// Der Screen haelt selbst keinen Zirkelstand. Er liest ZirkelAblauf und
/// meldet nur Absichten nach oben; navigiert wird in TrainingRootView,
/// damit Ablauf der Uhr und Tipp denselben, gegen doppelten Aufruf
/// gesperrten Weg nehmen (zirkelWeiter).
struct ZirkelPauseView: View {
    let ablauf: ZirkelAblauf
    let uebungsname: (ZirkelUebung) -> String
    /// Die Zeile "Letztes Mal …" -- dieselbe Quelle wie die Startwerte der
    /// Uebung. nil ohne Historie: dann steht nichts da statt "Noch nie".
    let letztesMal: (ZirkelUebung) -> String?
    /// Ende der Pause oder Tipp auf "<Name> starten".
    let beiStarten: () -> Void
    /// "+ Übung zum Zirkel" -- nur gesetzt, solange Erweitern offen ist
    /// (Task 7). nil blendet den Knopf aus.
    let beiErweitern: (() -> Void)?
    let beiBeenden: () -> Void

    @Environment(WorkoutSessionStore.self) private var sessions

    var body: some View {
        // Ohne Zirkel (beendet, waehrend der Screen noch auf dem Stapel
        // liegt) bleibt die Flaeche leer statt einen Absturz zu riskieren.
        Group {
            if let zirkel = ablauf.zirkel, let naechste = zirkel.naechste {
                inhalt(zirkel, naechste: naechste)
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Color.bg)
        .navigationBarTitleDisplayMode(.inline)
        // Unter der Pause liegt der Geraete-Screen der eben gemachten Uebung,
        // und dort ist Sichern fuer diesen Zirkel-Slot gesperrt
        // (zirkelSatzAbgegeben). Zurueck fuehrte also auf eine Seite, auf der
        // nichts mehr geht. Ohne Zurueck-Knopf sperrt SwiftUI auch das
        // Wischen vom Rand; heraus kommt man nur ueber die Knoepfe unten
        // oder den Ablauf der Uhr.
        .navigationBarBackButtonHidden(true)
        // Wie GeraetView: der Endzeitpunkt ist die id, damit "+30 s" den Task
        // neu aufsetzt statt zu frueh zu feuern. Kommt die App aus dem
        // Hintergrund und die Frist ist um, feuert er sofort. Dies ist die
        // einzige Stelle, die das Ende der Zirkel-Pause ausloest.
        .task(id: ablauf.pause?.endetAm) {
            guard let ende = ablauf.pause?.endetAm else { return }
            let rest = ende.timeIntervalSinceNow
            if rest > 0 { try? await Task.sleep(for: .seconds(rest)) }
            guard !Task.isCancelled else { return }
            beiStarten()
        }
        .testnotizScreen()
    }

    private func inhalt(_ zirkel: Zirkel, naechste: ZirkelUebung) -> some View {
        GeometryReader { sichtbar in
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.s16) {
                    Text(ZirkelPauseText.kopf(zirkel).uppercased())
                        .font(DesignSystem.Typography.label)
                        .tracking(1.5)
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let pause = ablauf.pause {
                        uhr(pause)
                    }
                    if zirkel.naechsterSchrittIstRundenwechsel, let runde = ablauf.geschaffteRunde {
                        rundenzusammenfassung(zirkel, runde: runde)
                    }
                    reihenfolge(zirkel, naechste: naechste)
                    Spacer(minLength: 0)
                    knoepfe(naechste)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, DesignSystem.Spacing.s8)
                .frame(minHeight: sichtbar.size.height, alignment: .top)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    /// 140 statt 240 pt: gross genug fuer die Ziffern aus einem Meter, klein
    /// genug, dass die Karte darunter das Auge zuerst bekommt.
    private func uhr(_ pause: Resttimer) -> some View {
        Zeitring(timer: pause, beschriftung: "PAUSE", kante: 140) {
            String(format: "%02d:%02d", $0 / 60, $0 % 60)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pause.gesprochen())
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// Entscheidung 6: in der Rundenpause, was die Runde gebracht hat --
    /// knapp, je Uebung eine Zeile.
    @ViewBuilder
    private func rundenzusammenfassung(_ zirkel: Zirkel, runde: DateInterval) -> some View {
        let zeilen = ZirkelPauseText.rundenzeilen(zirkel, bloecke: sessions.aktiveSession()?.bloecke ?? [],
                                                  in: runde, name: uebungsname)
        if !zeilen.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                    ForEach(Array(zeilen.enumerated()), id: \.offset) { _, zeile in
                        Text(zeile)
                            .font(DesignSystem.Typography.fliesstext)
                            .foregroundStyle(DesignSystem.Color.text)
                            .monospacedDigit()
                    }
                }
                .padding(DesignSystem.Spacing.s12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
            .testnotizElement("zirkel.pause.runde", typ: "Card")
        }
    }

    /// Die ganze Reihenfolge im Stil des Katalogs, rechts je Uebung der
    /// Fortschritt. Das Video steht in der Kachel; nur die naechste Zeile
    /// traegt "Letztes Mal" und den Akzentrand (Anti-Ziel: nicht ueberladen).
    private func reihenfolge(_ zirkel: Zirkel, naechste: ZirkelUebung) -> some View {
        Card {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
                ForEach(Array(zirkel.uebungen.enumerated()), id: \.element) { index, uebung in
                    zeile(uebung, stand: zirkel.stand(an: index), istNaechste: uebung == naechste)
                }
            }
            .padding(DesignSystem.Spacing.s12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .testnotizElement("zirkel.pause.reihenfolge", typ: "Card")
    }

    private func zeile(_ uebung: ZirkelUebung, stand: ZirkelStand, istNaechste: Bool) -> some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            UebungsVideoKachel(exerciseId: uebung.exerciseId, kante: 56) { Uebungsbild(kante: 56) }
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text(uebungsname(uebung))
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.text)
                if istNaechste, let zuletzt = letztesMal(uebung) {
                    Text("Letztes Mal \(zuletzt)")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .monospacedDigit()
                }
            }
            Spacer(minLength: 0)
            standAnzeige(stand)
        }
        .padding(DesignSystem.Spacing.s8)
        .overlay {
            if istNaechste {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                    .strokeBorder(DesignSystem.Color.accent, lineWidth: 2)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(uebungsname(uebung)), \(ZirkelPauseText.standSprache(stand))")
    }

    /// Das Gruen der App ist der Akzent; ein zweites Gruen gibt es nicht.
    @ViewBuilder
    private func standAnzeige(_ stand: ZirkelStand) -> some View {
        switch stand {
        case .abgeschlossen:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(DesignSystem.Color.accent)
        case .naechste:
            Text("Nächste")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DesignSystem.Color.onAccent)
                .padding(.horizontal, DesignSystem.Spacing.s8)
                .padding(.vertical, DesignSystem.Spacing.s4)
                .background(DesignSystem.Color.accent, in: Capsule())
        case .dran:
            Text(ZirkelPauseText.standText(stand) ?? "")
                .font(.system(size: 15, weight: .bold).monospacedDigit())
                .foregroundStyle(DesignSystem.Color.accent)
        case .offen:
            Text(ZirkelPauseText.standText(stand) ?? "")
                .font(.system(size: 15, weight: .semibold).monospacedDigit())
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
    }

    private func knoepfe(_ naechste: ZirkelUebung) -> some View {
        VStack(spacing: DesignSystem.Spacing.s12) {
            PrimaryButton(title: ZirkelPauseText.startTitel(uebungsname: uebungsname(naechste))) { beiStarten() }
                .accessibilityHint("Beendet die Pause und öffnet die nächste Übung")
                .testnotizElement("zirkel.pause.starten", typ: "PrimaryButton")
            // Nebeneinander, beide betreffen nur diese Pause bzw. diesen Slot.
            HStack(spacing: DesignSystem.Spacing.s8) {
                SecondaryButton(title: "+30 s") { ablauf.pauseVerlaengern() }
                    .accessibilityLabel("Pause um 30 Sekunden verlängern")
                    .testnotizElement("zirkel.pause.verlaengern", typ: "SecondaryButton")
                // Gilt nur fuer diese Runde und sichert keinen Satz (Spec-
                // Annahme). Danach derselbe Weg wie am Ende der Pause: zur
                // dann naechsten Uebung bzw. zur Uebersicht, wenn keine mehr
                // kommt. Schloss der Slot die Runde, bleibt der Screen
                // stehen und wird zur Rundenpause; deren Uhr setzt der Task
                // ueber das neue endetAm auf.
                SecondaryButton(title: "Überspringen") {
                    ablauf.ueberspringen()
                    if let zirkel = ablauf.zirkel, ZirkelPfad.nachUeberspringenWeiter(zirkel) {
                        beiStarten()
                    }
                }
                .accessibilityLabel("\(uebungsname(naechste)) in dieser Runde überspringen")
                .testnotizElement("zirkel.pause.ueberspringen", typ: "SecondaryButton")
            }
            if let beiErweitern {
                SecondaryButton(title: "+ Übung zum Zirkel") { beiErweitern() }
                    .testnotizElement("zirkel.pause.erweitern", typ: "SecondaryButton")
            }
            // Textlink statt Knopf: Beenden ist der seltene Weg und soll
            // neben "starten" keine zweite Flaeche bekommen.
            Button(action: beiBeenden) {
                Text("Zirkel beenden")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Behält alle gesicherten Sätze")
            .testnotizElement("zirkel.pause.beenden", typ: "Button")
        }
    }
}

/// Die Texte des Pausenscreens als reine Funktionen, damit sie ohne View
/// pruefbar sind.
enum ZirkelPauseText {
    /// "Runde 1 von 3", in der Rundenpause "Runde 1 von 3 · Rundenpause".
    static func kopf(runde: Int, runden: Int, rundenwechsel: Bool) -> String {
        let kopf = "Runde \(runde) von \(runden)"
        return rundenwechsel ? "\(kopf) · Rundenpause" : kopf
    }

    /// In der Rundenpause zaehlt der Zirkel schon die naechste Runde
    /// (Zirkel.runde leitet sich aus den erledigten Slots ab). Der Kopf
    /// nennt die gerade geschaffte -- die Pause gehoert zu ihr.
    static func kopf(_ zirkel: Zirkel) -> String {
        let wechsel = zirkel.naechsterSchrittIstRundenwechsel
        return kopf(runde: wechsel ? zirkel.runde - 1 : zirkel.runde, runden: zirkel.runden, rundenwechsel: wechsel)
    }

    static func startTitel(uebungsname: String) -> String {
        "\(uebungsname) starten"
    }

    /// Rechts in der Zeile: "1/3", "Nächste"; beim Haekchen steht ein Bild.
    static func standText(_ stand: ZirkelStand) -> String? {
        switch stand {
        case .abgeschlossen: nil
        case .naechste: "Nächste"
        case .dran(let k, let r), .offen(let k, let r): "\(k)/\(r)"
        }
    }

    static func standSprache(_ stand: ZirkelStand) -> String {
        switch stand {
        case .abgeschlossen: "Abgeschlossen"
        case .naechste: "Nächste Übung"
        case .dran(let k, let r), .offen(let k, let r): "\(k) von \(r) Runden gemacht"
        }
    }

    /// Je Zirkel-Uebung "Name 12,5 kg × 10" aus ihrem Satz in der eben
    /// geschafften Runde (`runde`, ZirkelAblauf.geschaffteRunde). Nur das
    /// Fenster zaehlt: der Block traegt auch Saetze der Vorrunden und von
    /// vor dem Zirkel, und eine in dieser Runde uebersprungene Uebung zeigte
    /// sonst einen alten Satz. Ohne Satz im Fenster faellt sie weg.
    static func rundenzeilen(_ zirkel: Zirkel, bloecke: [LokalerBlock], in runde: DateInterval,
                             name: (ZirkelUebung) -> String) -> [String] {
        zirkel.uebungen.compactMap { uebung in
            guard let block = bloecke.first(where: {
                $0.stationSchluessel == uebung.station && $0.exerciseId == uebung.exerciseId
            }), let satz = block.saetze.last(where: { runde.contains($0.performedAt) }),
                  let werte = satzwerte(satz, block) else { return nil }
            return "\(name(uebung)) \(werte)"
        }
    }

    /// Der letzte Satz eines Blocks in einer Zeile: "12,5 kg × 10", bei
    /// Cardio die Cardio-Werte. nil ohne Satz oder ohne Werte.
    static func satzwerte(_ block: LokalerBlock) -> String? {
        guard let letzter = block.saetze.last else { return nil }
        return satzwerte(letzter, block)
    }

    /// Ein bestimmter Satz eines Blocks; die Zirkel-Uebersicht schreibt
    /// damit jeden Satz, nicht nur den letzten.
    static func satzwerte(_ letzter: LokalerSatz, _ block: LokalerBlock) -> String? {
        if let cardio = letzter.cardio { return Zahlformat.cardio(cardio) }
        guard let load = letzter.load, let volume = letzter.volume else { return nil }
        return Zahlformat.satz(load, block.loadUnit, neben: letzter.secondaryLoad, block.secondaryUnit,
                               umfang: volume, block.volumeKind)
    }
}
