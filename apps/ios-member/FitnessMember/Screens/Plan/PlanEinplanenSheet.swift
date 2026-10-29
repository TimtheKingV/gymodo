import SwiftUI

/// Die Wochentage der drei Arten, wie das Sheet sie bearbeitet -- rein, damit
/// die Umverteilung ohne UI pruefbar bleibt.
struct PlanWochentage: Equatable {
    var kraft: Set<Int>
    var kurs: Set<Int>
    var cardio: Set<Int>

    init(kraft: Set<Int> = [], kurs: Set<Int> = [], cardio: Set<Int> = []) {
        self.kraft = kraft
        self.kurs = kurs
        self.cardio = cardio
    }

    /// Aus dem Raster, das der Tab gerade zeigt (`PlanTabZustand.anzeigeRaster`).
    init(raster: [Rasterplatz]) {
        self.init(
            kraft: Set(raster.filter { $0.art == .kraft }.map(\.tag)),
            kurs: Set(raster.filter { $0.art == .kurs }.map(\.tag)),
            cardio: Set(raster.filter { $0.art == .cardio }.map(\.tag)))
    }

    func tage(_ art: Wochenart) -> Set<Int> {
        switch art {
        case .kraft: kraft
        case .kurs: kurs
        case .cardio: cardio
        }
    }

    func art(an tag: Int) -> Wochenart? {
        if kraft.contains(tag) { return .kraft }
        if kurs.contains(tag) { return .kurs }
        if cardio.contains(tag) { return .cardio }
        return nil
    }

    /// Schaltet `tag` fuer `art` um. Ein Tag gehoert hoechstens einer Art
    /// (E4, der Server lehnt Ueberschneidungen ab): wer ihn einer Art gibt,
    /// nimmt ihn der bisherigen weg.
    mutating func umschalten(_ tag: Int, fuer art: Wochenart) {
        if tage(art).contains(tag) {
            setze(art, tage(art).subtracting([tag]))
            return
        }
        for andere in [Wochenart.kraft, .kurs, .cardio] where andere != art {
            setze(andere, tage(andere).subtracting([tag]))
        }
        setze(art, tage(art).union([tag]))
    }

    private mutating func setze(_ art: Wochenart, _ neu: Set<Int>) {
        switch art {
        case .kraft: kraft = neu
        case .kurs: kurs = neu
        case .cardio: cardio = neu
        }
    }

    /// Der Plan braucht mindestens einen Krafttag (Ruling Task 3: Kurs und
    /// Cardio duerfen nicht alle sieben Tage belegen).
    var istGueltig: Bool { !kraft.isEmpty }

    /// Das Profil fuer das PUT: alle drei Tagesfelder, damit ein umverteilter
    /// Tag nicht gegen das gespeicherte Feld der anderen Art prallt. Die
    /// Cardio-Arten bleiben, wie sie sind (nil = nicht senden).
    func profil(aus alt: TrainingsplanProfil) -> TrainingsplanProfil {
        TrainingsplanProfil(
            minutes: alt.minutes, experience: alt.experience, focus: alt.focus,
            kursTage: kurs.sorted(), cardioTage: cardio.sorted(), cardioArten: alt.cardioArten,
            kraftTage: kraft.sorted())
    }
}

/// "Einplanen" (Leinwand 2b): welche Art an welchen Wochentagen. Schreibt nur
/// die Tage ins Trainingsprofil -- der Plan selbst bleibt stabil (F14), die
/// Folge der Einheiten aendert sich nicht.
///
/// Uhrzeit und Erinnerung aus der Leinwand fehlen bewusst: dafuer gibt es
/// weder Profilfeld noch Benachrichtigung.
struct PlanEinplanenSheet: View {
    let profil: TrainingsplanProfil
    let raster: [Rasterplatz]
    let einheiten: [String]
    let hatKurse: Bool
    var vorauswahl: Wochenart = .kraft
    /// Liefert einen Fehlertext oder nil (dann schliesst das Sheet).
    let speichern: (TrainingsplanProfil) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var art: Wochenart = .kraft
    @State private var tage = PlanWochentage()
    @State private var fehler: String?
    @State private var laeuft = false
    @State private var bereit = false

    private static let kurzname = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    private static let vollname = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]

    private var arten: [Wochenart] { hatKurse ? [.kraft, .cardio, .kurs] : [.kraft, .cardio] }

    private func titel(_ art: Wochenart) -> String {
        switch art {
        case .kraft: einheiten.count > 1 ? einheiten.map(EinheitKuerzel.text).joined(separator: " · ") : "Kraft"
        case .kurs: "Kurs"
        case .cardio: "Cardio"
        }
    }

    private func artName(_ art: Wochenart) -> String {
        switch art {
        case .kraft: "Krafttraining"
        case .kurs: "Kurs"
        case .cardio: "Cardio"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                    abschnitt("WAS") {
                        HStack(spacing: DesignSystem.Spacing.s8) {
                            ForEach(arten, id: \.self) { a in
                                Button { art = a } label: {
                                    Chip(text: titel(a), isActive: a == art, innenabstand: DesignSystem.Spacing.s16)
                                        .frame(minHeight: 44)
                                }
                                .buttonStyle(PressButtonStyle())
                                .accessibilityLabel(artName(a))
                                .accessibilityAddTraits(a == art ? .isSelected : [])
                            }
                        }
                    }

                    abschnitt("WANN") {
                        HStack(spacing: DesignSystem.Spacing.s4) {
                            ForEach(1...7, id: \.self) { tag in tagKnopf(tag) }
                        }
                    }

                    Text(hinweis)
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    if !tage.istGueltig {
                        InlineBanner(tone: .muted, message: "Mindestens ein Tag bleibt fürs Krafttraining.")
                    }
                    if let fehler {
                        Text(fehler)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DesignSystem.Color.danger)
                    }

                    PrimaryButton(title: "Speichern", isEnabled: tage.istGueltig && !laeuft, isLoading: laeuft) {
                        laeuft = true
                        fehler = await speichern(tage.profil(aus: profil))
                        laeuft = false
                        if fehler == nil { dismiss() }
                    }
                }
                .padding(20)
            }
            .background(DesignSystem.Color.bg)
            .navigationTitle("Einplanen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
        .onAppear {
            guard !bereit else { return }
            bereit = true
            art = vorauswahl
            tage = PlanWochentage(raster: raster)
        }
    }

    /// "Die Folge bleibt A → B, egal an welchem Tag." (F5/F14)
    private var hinweis: String {
        let folge = einheiten.map(EinheitKuerzel.text).joined(separator: " → ")
        let erster = einheiten.count > 1
            ? "Die Folge bleibt \(folge), egal an welchem Tag."
            : "Die Einheit bleibt dieselbe, egal an welchem Tag."
        return erster + " Verpasst du einen Termin, rutscht nichts nach."
    }

    private func abschnitt<Inhalt: View>(_ titel: String, @ViewBuilder _ inhalt: () -> Inhalt) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text(titel)
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .accessibilityAddTraits(.isHeader)
            inhalt()
        }
    }

    private func tagKnopf(_ tag: Int) -> some View {
        let belegt = tage.art(an: tag)
        let aktiv = belegt == art
        let index = tag - 1
        return Button { tage.umschalten(tag, fuer: art) } label: {
            VStack(spacing: DesignSystem.Spacing.s4) {
                Text(Self.kurzname[index])
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(aktiv ? DesignSystem.Color.onAccent : DesignSystem.Color.text)
                // Was der Tag sonst ist: wer ihn antippt, verlegt das dorthin.
                Text(belegt.map { $0 == art ? "✓" : kurzArt($0) } ?? " ")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(aktiv ? DesignSystem.Color.onAccent : DesignSystem.Color.textMuted)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(aktiv ? DesignSystem.Color.accent : DesignSystem.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityLabel(tagLabel(Self.vollname[index], belegt: belegt))
        .accessibilityAddTraits(aktiv ? .isSelected : [])
    }

    private func kurzArt(_ art: Wochenart) -> String {
        switch art {
        case .kraft: "KRAFT"
        case .kurs: "KURS"
        case .cardio: "CARDIO"
        }
    }

    private func tagLabel(_ name: String, belegt: Wochenart?) -> String {
        guard let belegt else { return "\(name), frei" }
        return "\(name), \(artName(belegt))"
    }
}
