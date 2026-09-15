import SwiftUI

/// Die reinen Ableitungen des Eintragen-Sheets -- getrennt vom View, damit
/// sie ohne SwiftUI pruefbar bleiben (wie `HomeZiele`/`HomeZeilen`).
enum GewichtEintragenHilfen {
    /// "yyyy-MM-dd" eines Tages, gebaut ueber Calendar-Komponenten in
    /// `zeitzone` statt ueber einen UTC-verankerten `DateFormatter`. Das
    /// ist in dieser Aufgabe die EINE Stelle, an der `TimeZone.current`
    /// richtig ist (Ruling R9): der Messtag gehoert der Person, die ihn
    /// eintraegt, nicht dem Studio -- anders als ein Kurstermin oder eine
    /// Trainingseinheit, die dem Studio gehoeren (siehe HomeRootView.zeitzone).
    static func ortsdatum(_ tag: Date, zeitzone: TimeZone = .current) -> String {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = zeitzone
        let teile = kalender.dateComponents([.year, .month, .day], from: tag)
        guard let jahr = teile.year, let monat = teile.month, let t = teile.day else { return "" }
        return String(format: "%04d-%02d-%02d", jahr, monat, t)
    }

    /// Die Vorgabe fuer `tag:` -- "heute" als Ortsdatum des Geraets.
    static func heute(jetzt: Date = Date(), zeitzone: TimeZone = .current) -> String {
        ortsdatum(jetzt, zeitzone: zeitzone)
    }

    /// Die Umkehrung von `ortsdatum` -- fuer die Vorbelegung des
    /// DatePicker aus einem gespeicherten Ortsdatum (Tippen auf eine
    /// Verlaufszeile in `GewichtsverlaufView`).
    static func datum(von tag: String, zeitzone: TimeZone = .current) -> Date? {
        let teile = tag.split(separator: "-").compactMap { Int($0) }
        guard teile.count == 3 else { return nil }
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = zeitzone
        var komponenten = DateComponents()
        komponenten.year = teile[0]
        komponenten.month = teile[1]
        komponenten.day = teile[2]
        return kalender.date(from: komponenten)
    }

    /// "Heute, 13. September" / "Donnerstag, 27. August" -- ob der Tag
    /// "heute" ist, kommt aus `HomeZeilen.tageHerVonTag` (== 0) statt aus
    /// einem zweiten, selbst geschriebenen Vergleich derselben Rechnung.
    static func datumsZeile(_ tag: Date, jetzt: Date = Date(), zeitzone: TimeZone = .current) -> String {
        let tagString = ortsdatum(tag, zeitzone: zeitzone)
        guard HomeZeilen.tageHerVonTag(tagString, jetzt: jetzt, zeitzone: zeitzone) == 0 else {
            return Zahlformat.wochentagDatum(tag)
        }
        return "Heute, \(tagMonatOrtszeit(tag))"
    }

    /// "13. September" -- anders als `Zahlformat.tagMonat` (UTC-verankert
    /// fuer aus einem Ortsdatum-String geparste Zeitpunkte) hier bewusst
    /// OHNE explizite Zeitzone: `tag` ist bereits ein echter, lokaler
    /// `Date`-Wert aus dem DatePicker, kein UTC-Mittag-Konstrukt.
    private static func tagMonatOrtszeit(_ tag: Date) -> String {
        let formatierer = DateFormatter()
        formatierer.locale = Locale(identifier: "de_DE")
        formatierer.setLocalizedDateFormatFromTemplate("ddMMMM")
        return formatierer.string(from: tag)
    }

    /// "Schritt 0,5 kg · zuletzt 83,0 am 10. Sep" -- ohne letzten Messwert
    /// nur der erste Teil (SS5: keine erfundene Angabe).
    static func kontextZeile(letzterMesswert: Messwert?) -> String {
        guard let letzterMesswert, let tag = Zeitpunkt.parse("\(letzterMesswert.measuredOn)T12:00:00Z")
        else { return "Schritt 0,5 kg" }
        return "Schritt 0,5 kg · zuletzt \(Zahlformat.gewicht(letzterMesswert.weightKg)) am \(Zahlformat.tagMonatKurz(tag))"
    }
}

/// Der Sheet-Inhalt ohne ScrollView-Huelle -- eigener Typ statt einer
/// privaten `body`-Rechnung, aus zwei Gruenden: (1) `GewichtEintragenSheet`
/// selbst bleibt eine ScrollView (Dynamic Type XXL, kleine Geraete --
/// designsystem.md SS12), und `ImageRenderer` kann eine ScrollView nicht
/// zeichnen (Sichtpruefung Task 9, Kaltbau-Bericht); dieser Typ schon,
/// direkt instanziiert. (2) Das Rad kommt als `@ViewBuilder`-Slot: die
/// Sichtpruefung ersetzt es durch `EmptyView()` ("Inhalt minus Rad"), ohne
/// dass irgendwo Layout dafuer dupliziert werden muesste.
struct GewichtEintragenInhalt<Rad: View>: View {
    @Binding var tag: Date
    @Binding var datumOffen: Bool
    let kontextZeile: String
    let fehler: String?
    let laeuft: Bool
    @ViewBuilder let rad: () -> Rad
    let eintragen: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
            Text("GEWICHT EINTRAGEN")
                .font(.system(size: 22, weight: .black))
                .tracking(-0.4)
                .foregroundStyle(DesignSystem.Color.text)

            datumsZeile

            rad()

            Text(kontextZeile)
                .font(DesignSystem.Typography.label)
                .tracking(1)
                .textCase(.uppercase)
                .monospacedDigit()
                .foregroundStyle(DesignSystem.Color.textFaint)
                .frame(maxWidth: .infinity, alignment: .center)

            if let fehler {
                InlineBanner(tone: .danger, message: fehler)
            }

            VStack(spacing: DesignSystem.Spacing.s12) {
                PrimaryButton(title: "Eintragen", isLoading: laeuft) {
                    await eintragen()
                }
                Text("Ein Wert je Tag. Ein zweiter am selben Tag ersetzt den ersten.")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, DesignSystem.Spacing.s8)
        }
    }

    /// Die Datumszeile -- Anzeige plus, bei Antippen, das `DatePicker` IM
    /// Sheet (Brief Step 2): kein zweiter Screen fuer eine einzige Angabe.
    /// `in: ...Date()`, weil `measuredOn` nicht in der Zukunft liegen darf
    /// (Spec 4.3).
    private var datumsZeile: some View {
        VStack(spacing: DesignSystem.Spacing.s8) {
            Button {
                datumOffen.toggle()
            } label: {
                HStack(spacing: DesignSystem.Spacing.s12) {
                    Text(GewichtEintragenHilfen.datumsZeile(tag))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DesignSystem.Color.text)
                    Spacer(minLength: 0)
                    Image(systemName: datumOffen ? "chevron.down" : "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DesignSystem.Color.textFaint)
                }
                .padding(.horizontal, DesignSystem.Spacing.s16)
                .frame(height: 52)
                .frame(minHeight: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.neben)
                        .stroke(DesignSystem.Color.line, lineWidth: 1)
                )
            }
            .buttonStyle(PressButtonStyle())
            .accessibilityLabel("Datum")
            .accessibilityValue(GewichtEintragenHilfen.datumsZeile(tag))

            if datumOffen {
                DatePicker(
                    "Datum", selection: $tag, in: ...Date(), displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(DesignSystem.Color.accent)
            }
        }
    }
}

/// GewichtEintragen.dc.html -- der einzige Schreibweg des Gewichts nach
/// dem Onboarding (Brief). Von Home aus immer mit dem heutigen Tag
/// vorbelegt; aus `GewichtsverlaufView` (Tippen auf eine Zeile) mit dem
/// Tag und Wert dieser Zeile -- ein zweites Speichern desselben Tages
/// ersetzt den ersten Eintrag serverseitig (Upsert, Spec 4.3).
///
/// Nimmt `letzterMesswert` zusaetzlich zu `vorgabe` entgegen (Abweichung
/// vom Brief-Pseudocode, das nur `vorgabe: Double?` nennt): die
/// Kontextzeile "zuletzt X am Y" braucht Wert UND Datum des wirklich
/// juengsten Eintrags -- unabhaengig davon, welcher (womoeglich aeltere)
/// Tag hier gerade bearbeitet wird.
struct GewichtEintragenSheet: View {
    let vorgabe: Double?
    let tag: String
    let letzterMesswert: Messwert?
    let speichern: (MesswertWrite) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var ausgewaehlterTag: Date
    @State private var gewicht: Double
    @State private var datumOffen = false
    @State private var fehler: String?
    @State private var laeuft = false

    /// 20-400 kg, Schritt 0,5 -- wie `KoerperSchritt` im Onboarding
    /// (OnboardingSchritte.swift): dasselbe Rad, derselbe Bereich, kein
    /// Geraet mit eigener Rasterung dahinter.
    private static let gewichtswerte = Rastwerte.gewichte(min: 20, max: 400, schritt: 0.5)

    init(
        vorgabe: Double?,
        tag: String = GewichtEintragenHilfen.heute(),
        letzterMesswert: Messwert?,
        speichern: @escaping (MesswertWrite) async -> String?
    ) {
        self.vorgabe = vorgabe
        self.tag = tag
        self.letzterMesswert = letzterMesswert
        self.speichern = speichern
        _ausgewaehlterTag = State(initialValue: GewichtEintragenHilfen.datum(von: tag) ?? Date())
        _gewicht = State(initialValue: vorgabe ?? 75.0)
    }

    var body: some View {
        ScrollView {
            GewichtEintragenInhalt(
                tag: $ausgewaehlterTag,
                datumOffen: $datumOffen,
                kontextZeile: GewichtEintragenHilfen.kontextZeile(letzterMesswert: letzterMesswert),
                fehler: fehler,
                laeuft: laeuft,
                rad: {
                    RastRad(
                        werte: Self.gewichtswerte,
                        auswahl: $gewicht,
                        unterstrich: .held,
                        voLabel: "Gewicht",
                        voWert: Zahlformat.gewichtGesprochen,
                        anschlagText: nil,
                        text: Zahlformat.gewicht
                    )
                },
                eintragen: eintragen
            )
            .padding(.horizontal, 20)
            .padding(.top, DesignSystem.Spacing.s24)
            .padding(.bottom, DesignSystem.Spacing.s24)
        }
        .background(DesignSystem.Color.bg)
        .scrollContentBackground(.hidden)
    }

    private func eintragen() async {
        laeuft = true
        let body = MesswertWrite(
            measuredOn: GewichtEintragenHilfen.ortsdatum(ausgewaehlterTag), weightKg: gewicht)
        fehler = await speichern(body)
        laeuft = false
        if fehler == nil { dismiss() }
    }
}

// MARK: - Vorschau

#Preview("Neuer Eintrag, heute") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            GewichtEintragenSheet(
                vorgabe: 83.0,
                letzterMesswert: Messwert(measuredOn: "2026-09-10", weightKg: 83.0),
                speichern: { _ in nil })
        }
}

#Preview("Einen aelteren Tag bearbeiten") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            GewichtEintragenSheet(
                vorgabe: 84.5,
                tag: "2026-08-01",
                letzterMesswert: Messwert(measuredOn: "2026-09-13", weightKg: 82.5),
                speichern: { _ in nil })
        }
}
