import SwiftUI

/// Eine Kurszeile des Wochenplans -- herausgeloest aus `KurseWochenView`,
/// damit der Plan-Tab (Filter "Kurse", gebuchte Kurse unter "Alle") dieselbe
/// Zeile zeigt statt einer Kopie.
/// Jede Zeile ist antippbar und traegt denselben Chevron (Abweichung 4
/// oben) -- unabhaengig vom Zustand, damit keine der vier Zeilen wie
/// tote Information wirkt.
///
/// `jetzt` kommt aus dem 60-Sekunden-Tick der TimelineView in `body`,
/// nicht aus einem frisch erzeugten Date(): sonst blieb ein bereits
/// begonnener Kurs als buchbar samt Belegungszahl stehen, bis
/// irgendein unabhaengiger Grund den Screen neu zeichnete.
///
/// Eine vergangene Zeile ist zurueckgenommen, aber lesbar: die
/// Abblendung liegt auf der FLAECHE (surface), nicht auf der ganzen
/// Karte. `.opacity(0.5)` ueber allem traf zuvor auch "VORBEI" (10pt)
/// und die Dauer (11pt), die ohnehin in textFaint standen -- rund
/// 1,7 : 1, weit unter jeder Schwelle, in einem Keller gelesen.
/// Zurueckgenommen wird jetzt ueber die Flaeche und ueber den Wechsel
/// des Kursnamens von `text` nach `textMuted`; jede Schrift der Zeile
/// bleibt dabei ueber der Schwelle.
struct KursTerminZeile: View {
    let termin: CourseWeekSession
    /// `jetzt` aus dem 60-Sekunden-Tick des Aufrufers (siehe oben).
    let jetzt: Date
    let herkunft: KurseHerkunft
    /// Die Zeitzone des Studios DIESES Termins, nicht die des Plans --
    /// der traegt die des ersten Studios (Testnotiz 11.10., #15). Ein
    /// Kurstermin gehoert dem Studio, nicht dem Geraet (KursZeit-Kommentar).
    let zeitzone: String
    /// "Trainer · Raum · Studio" (`trainerUndRaum(_:studioName:)`).
    let trainerUndRaum: String?
    let beiAuswahl: (String) -> Void

    /// Mit dem Studio, sobald mehr als eines sichtbar ist -- sonst saehe
    /// man nicht, wohin man faehrt (Testnotiz 11.10., #15). `studioName`
    /// ist nil, solange nur eines sichtbar ist.
    static func trainerUndRaum(_ termin: CourseWeekSession, studioName: ((String) -> String)?) -> String? {
        let studio = studioName.flatMap { name in termin.studioId.map(name) }
        let teile = [termin.instructorName, termin.room, studio].compactMap { $0 }
        return teile.isEmpty ? nil : teile.joined(separator: " · ")
    }

    var body: some View {
        let zustand = KursZustandRechner.zustand(fuer: termin, jetzt: jetzt)
        let beginn = Zeitpunkt.parse(termin.startsAt)
        let istVorbei = zustand == .vorbei

        let kontur = kontur(zustand)

        Button {
            beiAuswahl(termin.sessionId)
        } label: {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.s12) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                    Text(beginn.map { KursZeit.uhrzeit($0, zeitzone: zeitzone) } ?? "--:--")
                        .font(.system(size: 17, weight: .black).monospacedDigit())
                        .foregroundStyle(istVorbei ? DesignSystem.Color.textMuted : DesignSystem.Color.text)
                    // textMuted statt textFaint: die Dauer ist tragend und
                    // steht bei 11pt, also unter den 15pt, ab denen
                    // textFaint zulaessig waere (designsystem.md SS2).
                    Text("\(termin.durationMin) min")
                        .font(.system(size: 11, weight: .bold).monospacedDigit())
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
                .frame(width: 54, alignment: .leading)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                    Text(termin.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(istVorbei ? DesignSystem.Color.textMuted : DesignSystem.Color.text)
                    if let zeile = trainerUndRaum {
                        Text(zeile)
                            .font(.system(size: 12))
                            .foregroundStyle(DesignSystem.Color.textMuted)
                    }
                    if zeigtBelegung(zustand), herkunft.zeigtBelegung {
                        // Leiste UND Zahl. Die Leiste ist kein Fuellstand,
                        // sondern ein Segment je Platz -- sie macht ohne
                        // Lesen erfassbar, was die Zahl exakt sagt, und
                        // faerbt Knappheit nicht als Fehlverhalten ein
                        // (deshalb weiterhin kein warngelber Balken).
                        //
                        // herkunft.zeigtBelegung ist die zweite Bedingung:
                        // eine Zahl von vorhin ist keine Zahl mehr (Spec
                        // 5.2), und eine Leiste von vorhin erst recht
                        // nicht. Der Banner oben sagt, dass sie deshalb
                        // fehlt -- sie verschwindet nicht wortlos.
                        BelegungZeile(
                            belegt: termin.bookedCount, kapazitaet: termin.capacity,
                            // In der eigenen Zeile ist Gruen schon vergeben
                            // ("das ist deiner"): die Leiste bleibt dort
                            // gedeckt, sonst traegt eine Farbe zwei
                            // Bedeutungen nebeneinander.
                            farbe: zustand == .angemeldet
                                ? DesignSystem.Color.textMuted : DesignSystem.Color.accent)
                    }
                }

                Spacer(minLength: 0)

                if kontur != nil {
                    marke(zustand, wartelistenplatz: herkunft.zeigtBelegung ? termin.ownWaitlistPosition : nil)
                } else {
                    HStack(spacing: DesignSystem.Spacing.s8) {
                        if let chip = chipInhalt(zustand) {
                            Text(chip.text)
                                .font(.system(size: 10, weight: .heavy))
                                .tracking(0.7)
                                .foregroundStyle(chip.farbe)
                                .padding(.horizontal, DesignSystem.Spacing.s8)
                                .padding(.vertical, DesignSystem.Spacing.s4)
                                .overlay(Capsule().stroke(chip.farbe, lineWidth: 1))
                        }
                        // Der Chevron ist reine Affordanz, kein tragender
                        // Text -- textFaint ist dafuer ausdruecklich
                        // zugelassen.
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DesignSystem.Color.textFaint)
                    }
                }
            }
            .padding(DesignSystem.Spacing.s16)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Die Abblendung liegt auf der Flaeche, nicht auf der Zeile:
            // sonst traefe sie die Schrift mit (siehe Kommentar oben).
            .background(DesignSystem.Color.surface.opacity(istVorbei ? 0.5 : 1))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
            // Kontur statt Chip (Festlegung 2 oben). Als overlay, nicht als
            // border: eine Kontur veraendert die Zeilenhoehe nicht, die
            // eigene Zeile bleibt also genau so hoch wie ihre Nachbarn.
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                    .stroke(kontur?.farbe ?? .clear, lineWidth: kontur?.staerke ?? 0))
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Öffnet die Kursdetails")
    }

    /// Ob die Belegungszahl bei diesem Zustand gezeigt wird. `vorbei` und
    /// `abgesagt` lassen sie weg (wie im Artboard die Vorbei-Zeile ohne
    /// Balken/Zahl) -- eine Platzzahl ist fuer einen Termin, den man weder
    /// buchen noch stornieren kann, keine Information mehr, nur Rauschen.
    private func zeigtBelegung(_ zustand: KursZustand) -> Bool {
        switch zustand {
        case .frei, .voll, .angemeldet, .warteliste: true
        case .vorbei, .abgesagt: false
        }
    }

    /// Text und Farbe des Statuschips -- ausschliesslich als Umriss
    /// gezeichnet (siehe terminZeile), nie als Flaeche. `nil` bei frei/voll:
    /// kein Chip (Aufgabenbrief-Tabelle).
    ///
    /// "VORBEI" stand hier in `textFaint` bei 10pt und bekam von der Zeile
    /// zusaetzlich `.opacity(0.5)` -- ueber `bg` komponiert rund 1,7 : 1.
    /// `textFaint` ist laut designsystem.md SS2 nur ab 15pt oder fuer
    /// nicht tragenden Text zugelassen, und "VORBEI" ist die tragende
    /// Aussage der Zeile. Jetzt `textMuted`; die Abblendung der Zeile
    /// betrifft den Chip nicht mehr (siehe terminZeile).
    private func chipInhalt(_ zustand: KursZustand) -> (text: String, farbe: Color)? {
        switch zustand {
        case .vorbei: ("VORBEI", DesignSystem.Color.textMuted)
        case .abgesagt: ("ABGESAGT", DesignSystem.Color.warn)
        // Die eigenen Zustaende tragen keinen Chip mehr, sondern Kontur und
        // Marke (Festlegung 2 oben). Zwei Woerter waren zu wenig, um die
        // eigene Zeile von ihren Nachbarn zu unterscheiden.
        case .angemeldet, .warteliste: nil
        case .frei, .voll: nil
        }
    }

    /// Die Kontur einer eigenen Anmeldung -- `nil` fuer jede fremde Zeile.
    /// `warn` bleibt dabei Kontur und wird nie Flaeche (designsystem.md SS2).
    private func kontur(_ zustand: KursZustand) -> (farbe: Color, staerke: CGFloat)? {
        switch zustand {
        case .angemeldet: (DesignSystem.Color.accent, 1.5)
        case .warteliste: (DesignSystem.Color.warn.opacity(0.33), 1)
        case .frei, .voll, .vorbei, .abgesagt: nil
        }
    }

    /// Die Marke rechts. Sie ersetzt den Chevron nur bei den eigenen
    /// Zustaenden -- jede andere Zeile behaelt ihn, damit keine wie tote
    /// Information wirkt.
    ///
    /// Beide tragen ein `accessibilityLabel`: die Zeile fasst ihre Kinder
    /// zusammen (`children: .combine`), damit steht das Wort wieder in der
    /// Vorlesung, das mit dem Chip verschwunden ist. Ohne das haenge der
    /// Status allein an der Farbe.
    @ViewBuilder
    private func marke(_ zustand: KursZustand, wartelistenplatz: Int?) -> some View {
        switch zustand {
        case .angemeldet:
            ZStack {
                Circle().fill(DesignSystem.Color.accent)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(DesignSystem.Color.onAccent)
            }
            .frame(width: 26, height: 26)
            .accessibilityLabel("Angemeldet")
        case .warteliste:
            // Die Position steht nur, wenn sie FRISCH ist -- sie aendert
            // sich ohne Zutun des Mitglieds (jemand davor storniert, es
            // rueckt nach). Eine Zahl von vorhin koennte jemanden dazu
            // bringen, eine Warteliste zu verlassen, auf der er laengst
            // nachgerueckt ist. Sonst dieselbe Sanduhr wie im Band.
            if let platz = wartelistenplatz {
                VStack(spacing: 1) {
                    Text("\(platz)")
                        .font(.system(size: 20, weight: .black).monospacedDigit())
                    Text("PLATZ")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1)
                }
                .foregroundStyle(DesignSystem.Color.warn)
                .accessibilityLabel("Warteliste, Platz \(platz)")
            } else {
                Image(systemName: "hourglass")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.warn)
                    .accessibilityLabel("Auf der Warteliste")
            }
        case .frei, .voll, .vorbei, .abgesagt:
            EmptyView()
        }
    }

}
