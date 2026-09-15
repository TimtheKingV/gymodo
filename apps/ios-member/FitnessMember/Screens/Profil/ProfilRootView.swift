import SwiftUI

/// Profil.dc.html. Der letzte Screen aus der M1-Screenliste.
struct ProfilRootView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(CatalogStore.self) private var katalog
    @Environment(VerlaufStore.self) private var verlauf

    let apiClient: APIClient

    @AppStorage(Einstellungen.vibrationBeimSichernKey) private var vibrationBeimSichern = true
    @AppStorage(Einstellungen.resttimerSekundenKey) private var resttimerSekunden =
        Einstellungen.resttimerVorgabe
    @AppStorage(Einstellungen.satzZielKey) private var satzZiel = Einstellungen.satzZielVorgabe

    @State private var nameOffen = false
    /// Die drei Picker-Felder aus "ÜBER DICH" plus "Richtung" aus
    /// "ZIELE" -- alle vier sind `AuswahlSheet`, nur mit unterschiedlichen
    /// Optionen/Spalten (Brief Step 1).
    private enum AuswahlFeld: Identifiable {
        case geschlecht, alter, richtung
        var id: Self { self }
    }
    @State private var offenesAuswahlFeld: AuswahlFeld?
    @State private var groesseOffen = false
    @State private var offenesZiel: ZielSheet.Art?
    @State private var gewichtEintragenOffen = false

    private var member: BootstrapResponse.Member? { katalog.bootstrap?.member }
    private var name: String? { member?.displayName }
    private var studioName: String? {
        katalog.bootstrap?.studios.first { $0.id == katalog.activeStudioId }?.name
    }

    var body: some View {
        List {
            kopfkarte
            ueberDich
            ziele
            beimTraining
            deineDaten
            abmelden
            fusszeile
        }
        .scrollContentBackground(.hidden)
        .background(DesignSystem.Color.bg)
        .navigationTitle("PROFIL")
        .sheet(isPresented: $nameOffen) {
            NameSheet(bisher: name) { neuerName in
                // `do throws(APIError)`, damit `error` im catch getippt ist
                // und .servertext direkt greifbar ist (siehe TrainingAbschlussView).
                do throws(APIError) {
                    _ = try await apiClient.setDisplayName(neuerName)
                    await katalog.load()
                    return nil
                } catch {
                    // .offline zuerst abfangen: APIError.servertext dokumentiert
                    // seinen eigenen .offline-Zweig als blossen Notnagel fuer die
                    // Vollstaendigkeit, nicht als durchdachten Text. Hier ist
                    // nichts fuer spaeter vorgemerkt -- der Name blieb schlicht
                    // unveraendert, und genau das sagt der Satz (designsystem.md SS5:
                    // was falsch ist und was gilt).
                    guard error != .offline else {
                        return "Keine Verbindung. Der Name wurde nicht geändert."
                    }
                    // Sonst der Servertext woertlich -- er sagt, was gilt
                    // (designsystem.md SS5).
                    return error.servertext
                }
            }
        }
        .sheet(item: $offenesAuswahlFeld) { feld in
            auswahlSheet(feld)
        }
        .sheet(isPresented: $groesseOffen) {
            GroesseSheet(bisher: member?.heightCm) { wert in
                await profilSchreiben(
                    ProfilWrite(heightCm: wert.map { .setzen($0) } ?? .loeschen),
                    offlineSatz: "Keine Verbindung. Die Größe wurde nicht geändert.")
            }
        }
        .sheet(item: $offenesZiel) { art in
            ZielSheet(
                art: art,
                aktiv: art == .tageProWoche ? member?.goals.weeklyDays : member?.goals.targetWeight,
                letzterMesswert: verlauf.messwerte.last,
                uebernehmen: { wert in
                    await ZielSchreiben.setzen(
                        kind: art.kind, targetValue: wert, apiClient: apiClient, katalog: katalog, verlauf: verlauf)
                },
                aufgeben: {
                    await ZielSchreiben.aufgeben(kind: art.kind, apiClient: apiClient, katalog: katalog, verlauf: verlauf)
                })
        }
        .sheet(isPresented: $gewichtEintragenOffen) {
            GewichtEintragenSheet(
                vorgabe: verlauf.messwerte.last?.weightKg,
                letzterMesswert: verlauf.messwerte.last,
                speichern: { body in await verlauf.gewichtSpeichern(body, katalogNeuLaden: { await katalog.load() }) })
        }
    }

    /// Antippbar, anders als im Artboard: die Registrierung erfragt den
    /// Vornamen erst seit Sub-Projekt 4, jedes Bestandsmitglied braucht
    /// einen Weg dorthin.
    ///
    /// Ohne gesetzten Namen steht hier die Mailadresse allein -- keine
    /// Initialen aus dem Mail-Praefix.
    private var kopfkarte: some View {
        Section {
            Button { nameOffen = true } label: {
                HStack(spacing: DesignSystem.Spacing.s12) {
                    if let initialen = HomeZeilen.initialen(name) {
                        // Kein Akzentfuellung hier: die drei Schalter unten markieren
                        // bereits den aktiven Wert (SS2, "wo es keine Hauptaktion gibt,
                        // markiert der Akzent den aktiven Wert") -- eine zweite,
                        // dekorative Akzentflaeche wuerde mit ihnen konkurrieren.
                        // Artboard-Farben statt dessen.
                        Text(initialen)
                            .font(DesignSystem.Typography.label)
                            .foregroundStyle(DesignSystem.Color.textMuted)
                            .frame(width: 44, height: 44)
                            .background(DesignSystem.Color.surfaceRaised)
                            .clipShape(Circle())
                    }
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                        if let name {
                            Text(name)
                                .font(DesignSystem.Typography.uebungsname)
                                .foregroundStyle(DesignSystem.Color.text)
                        }
                        if let email = sessionStore.session?.email {
                            Text(email)
                                .font(DesignSystem.Typography.fliesstext)
                                .foregroundStyle(DesignSystem.Color.textMuted)
                        }
                    }
                }
            }
        }
        .listRowBackground(DesignSystem.Color.surface)
    }

    /// Profil.dc.html -- Geschlecht, Alter, Größe. Jede Zeile oeffnet ein
    /// Sheet, das den Wert setzt ODER entfernt (Brief Step 2); "—" ohne
    /// Angabe (`ProfilZeilen`, auch bei einem Rohwert, den dieser Client
    /// nicht kennt).
    private var ueberDich: some View {
        Section("ÜBER DICH") {
            ProfilZeile(label: "Geschlecht", wert: ProfilZeilen.geschlechtText(member?.sex)) {
                offenesAuswahlFeld = .geschlecht
            }
            ProfilZeile(label: "Alter", wert: ProfilZeilen.altersspanneText(member?.ageBand)) {
                offenesAuswahlFeld = .alter
            }
            ProfilZeile(label: "Größe", wert: ProfilZeilen.groesseText(member?.heightCm)) {
                groesseOffen = true
            }
        }
        .listRowBackground(DesignSystem.Color.surface)
    }

    /// Profil.dc.html -- Richtung, Tage pro Woche, Zielgewicht, dann die
    /// beiden Aktionszeilen aus Aufgabe 9 (Eintragen) und dem Verlauf.
    private var ziele: some View {
        Section("ZIELE") {
            ProfilZeile(label: "Richtung", wert: ProfilZeilen.richtungText(member?.trainingGoal)) {
                offenesAuswahlFeld = .richtung
            }
            ProfilZeile(
                label: "Tage pro Woche", wert: ProfilZeilen.tageProWocheText(member?.goals.weeklyDays)
            ) {
                offenesZiel = .tageProWoche
            }
            ProfilZeile(
                label: "Zielgewicht", wert: ProfilZeilen.zielgewichtText(member?.goals.targetWeight)
            ) {
                offenesZiel = .zielgewicht
            }
            // `profil_zeile(u'Gewicht eintragen', links=PLUS, chevron=False)`
            // -- dasselbe Sheet wie Aufgabe 9 auf Home, hier zusaetzlich
            // aus dem Profil erreichbar.
            Button { gewichtEintragenOffen = true } label: { ProfilGewichtEintragenInhalt() }
                .buttonStyle(.plain)
            // `NavigationLink` in `GewichtsverlaufView`, rechts
            // "82,5 kg · gestern" -- ein Chevron ohne Detail fuehrt hier
            // trotzdem zum -- dann leeren -- Verlauf, keinem
            // Sackgassen-Sheet.
            NavigationLink {
                GewichtsverlaufView(apiClient: apiClient)
            } label: {
                ProfilGewichtsverlaufInhalt(
                    detail: ProfilZeilen.gewichtsverlaufDetailText(verlauf.messwerte.last, jetzt: Date()))
            }
        }
        .listRowBackground(DesignSystem.Color.surface)
    }

    @ViewBuilder
    private func auswahlSheet(_ feld: AuswahlFeld) -> some View {
        switch feld {
        case .geschlecht:
            AuswahlSheet(
                titel: "Geschlecht",
                optionen: Geschlecht.alle.map { ($0, $0.wort) },
                gewaehlt: member?.sex.flatMap(Geschlecht.init(rawValue:)),
                spalten: 3
            ) { wahl in
                await profilSchreiben(
                    ProfilWrite(sex: wahl.map { .setzen($0.rawValue) } ?? .loeschen),
                    offlineSatz: "Keine Verbindung. Das Geschlecht wurde nicht geändert.")
            }
        case .alter:
            AuswahlSheet(
                titel: "Alter", hinweis: "Als Spanne. Ändert sich nicht von selbst.",
                optionen: Altersspanne.alle.map { ($0, $0.wort) },
                gewaehlt: member?.ageBand.flatMap(Altersspanne.init(rawValue:)),
                spalten: 4
            ) { wahl in
                await profilSchreiben(
                    ProfilWrite(ageBand: wahl.map { .setzen($0.rawValue) } ?? .loeschen),
                    offlineSatz: "Keine Verbindung. Das Alter wurde nicht geändert.")
            }
        case .richtung:
            AuswahlSheet(
                titel: "Richtung",
                optionen: Trainingsrichtung.alle.map { ($0, $0.wort) },
                gewaehlt: member?.trainingGoal.flatMap(Trainingsrichtung.init(rawValue:)),
                spalten: 2
            ) { wahl in
                await profilSchreiben(
                    ProfilWrite(trainingGoal: wahl.map { .setzen($0.rawValue) } ?? .loeschen),
                    offlineSatz: "Keine Verbindung. Die Richtung wurde nicht geändert.")
            }
        }
    }

    /// Der eine Schreibweg der vier Picker-Felder -- `NameSheet` oben
    /// macht dasselbe fuer den Namen. `offlineSatz` kommt vom Aufrufer,
    /// weil SS5 verlangt, dass der Satz sagt, WAS unveraendert blieb.
    private func profilSchreiben(_ body: ProfilWrite, offlineSatz: String) async -> String? {
        do throws(APIError) {
            _ = try await apiClient.updateProfile(body)
            await katalog.load()
            return nil
        } catch {
            guard error != .offline else { return offlineSatz }
            return error.servertext
        }
    }

    private var beimTraining: some View {
        Section("BEIM TRAINING") {
            Picker("Pause zwischen Sätzen", selection: $resttimerSekunden) {
                ForEach(Einstellungen.resttimerStufen, id: \.self) { stufe in
                    Text("\(stufe) s").tag(stufe)
                }
            }
            Picker("Sätze pro Gerät", selection: $satzZiel) {
                ForEach(Einstellungen.satzZielStufen, id: \.self) { stufe in
                    Text("\(stufe)").tag(stufe)
                }
            }
            Toggle("Vibration beim Sichern", isOn: $vibrationBeimSichern)

            NavigationLink("Passwort ändern") { MemberPasswortAendernView() }
            NavigationLink("Studios") { MemberStudiosView() }
        }
        .tint(DesignSystem.Color.accent)
        .listRowBackground(DesignSystem.Color.surface)
    }

    private var deineDaten: some View {
        Section("DEINE DATEN") {
            Text(
                "gymodo misst nichts. Gespeichert wird nur, was du selbst bestätigst — Einstellwerte, Sätze, ob ein Trainer dabei war."
            )
            .font(DesignSystem.Typography.fliesstext)
            .foregroundStyle(DesignSystem.Color.textMuted)

            // Zweiter Satz seit Aufgabe 10 (Brief Step 2), woertlich aus
            // dem Artboard: die Produktgrenze gilt jetzt auch fuer
            // Koerperdaten und Ziele -- eine eigene Zeile, kein
            // angehaengter Halbsatz an der Zeile ueber Einstellwerten und
            // Saetzen, die etwas anderes meint.
            Text(
                "Deine Körperdaten und Ziele sieht niemand außer dir — auch dein Studio nicht. Jede Angabe lässt sich einzeln entfernen."
            )
            .font(DesignSystem.Typography.fliesstext)
            .foregroundStyle(DesignSystem.Color.textMuted)

            // Nur mit hinterlegter Adresse -- ein Bedienelement ohne Ziel
            // ist schlechter als keines.
            if let url = AppConfig.datenschutzURL {
                Link("Datenschutzerklärung", destination: url)
            }
        }
        .listRowBackground(DesignSystem.Color.surface)
    }

    private var abmelden: some View {
        Section {
            Button("Abmelden", role: .destructive) {
                // Der Verlauf-Reset laeuft bereits zentral in RootView.swift
                // (Aufgabe 5), sobald sessionStore.session auf nil wechselt --
                // ein zweiter Aufruf hier waere ein zweiter Abmeldepfad.
                Task { await sessionStore.signOut() }
            }
        }
        .listRowBackground(DesignSystem.Color.surface)
    }

    private var fusszeile: some View {
        Section {
            Text(
                [
                    "gymodo \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")",
                    studioName,
                ]
                .compactMap { $0 }
                .joined(separator: " · ")
            )
            .font(DesignSystem.Typography.fliesstext)
            .foregroundStyle(DesignSystem.Color.textFaint)
        }
        .listRowBackground(DesignSystem.Color.bg)
    }
}

// MARK: - Zeilen (eigene Typen, siehe GewichtsverlaufKopf/-Zeile in Aufgabe 9:
// so lassen sich "ÜBER DICH" und "ZIELE" ausserhalb jeder List rendern --
// Sichtpruefung Aufgabe 10)

/// Label links, Wert rechts in `textMuted`, Chevron -- `profil_zeile` aus
/// gen.py. Kein `NavigationLink`: das Ziel ist ein Sheet, kein
/// Folgescreen, der Chevron zeigt trotzdem "hier tut sich etwas".
struct ProfilZeile: View {
    let label: String
    let wert: String
    let aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            HStack(spacing: DesignSystem.Spacing.s12) {
                // gen.py profil_zeile(): font-size 15px/700 fuers Label --
                // nicht `uebungsname` (17/600), das ist eine andere Rolle
                // (Sichtpruefung, Aufgabe 10).
                Text(label)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DesignSystem.Color.text)
                Spacer(minLength: DesignSystem.Spacing.s8)
                Text(wert)
                    .font(.system(size: 14, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(DesignSystem.Color.textMuted)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// `profil_zeile(u'Gewicht eintragen', links=PLUS, chevron=False)` -- der
/// Inhalt ohne den `Button`, den `ProfilRootView` selbst um die Aktion
/// legt (derselbe Schnitt wie bei `GewichtEintragenInhalt`, Aufgabe 9).
/// Plus-Symbol wie `HomeZieleView.eintragenZeile` (17/semibold) -- dieselbe
/// Aktion, derselbe Knopf.
struct ProfilGewichtEintragenInhalt: View {
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.text)
            Text("Gewicht eintragen")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(DesignSystem.Color.text)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}

/// Rechts "82,5 kg · gestern" -- der Inhalt des `NavigationLink` in
/// "ZIELE", ohne Detail ohne Messwerte (`ProfilZeilen.gewichtsverlaufDetailText`
/// unterscheidet das von "—": der Chevron fuehrt trotzdem zum -- dann
/// leeren -- Verlauf, keinem Sackgassen-Sheet).
struct ProfilGewichtsverlaufInhalt: View {
    let detail: String?

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            Text("Gewichtsverlauf")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(DesignSystem.Color.text)
            Spacer(minLength: DesignSystem.Spacing.s8)
            if let detail {
                Text(detail)
                    .font(.system(size: 14, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
        }
    }
}
