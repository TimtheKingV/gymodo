import SwiftUI

/// Profil.dc.html. Der letzte Screen aus der M1-Screenliste.
struct ProfilRootView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(CatalogStore.self) private var katalog

    let apiClient: APIClient

    @AppStorage(Einstellungen.vibrationBeimSichernKey) private var vibrationBeimSichern = true
    @AppStorage(Einstellungen.resttimerSekundenKey) private var resttimerSekunden =
        Einstellungen.resttimerVorgabe
    @AppStorage(Einstellungen.satzZielKey) private var satzZiel = Einstellungen.satzZielVorgabe

    @State private var nameOffen = false

    private var name: String? { katalog.bootstrap?.member.displayName }
    private var studioName: String? {
        katalog.bootstrap?.studios.first { $0.id == katalog.activeStudioId }?.name
    }

    var body: some View {
        List {
            kopfkarte
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
