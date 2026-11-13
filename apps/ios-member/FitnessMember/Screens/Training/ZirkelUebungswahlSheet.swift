import SwiftUI

/// Die offene Frage "Welche Übung?" einer Station mit mehreren Uebungen
/// (Finding I-2): `offen` steht zur Wahl, `schonDabei` nur im Hinweis.
struct ZirkelUebungswahl: Identifiable, Hashable {
    let station: Station
    let offen: [ZirkelUebung]
    let schonDabei: [ZirkelUebung]

    var id: String { station.schluessel }

    // Station selbst ist nicht Hashable; Schluessel und Listen genuegen, damit
    // die Wahl als Wert im Navigationspfad reisen kann.
    static func == (a: Self, b: Self) -> Bool {
        a.station.schluessel == b.station.schluessel && a.offen == b.offen && a.schonDabei == b.schonDabei
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(station.schluessel)
        hasher.combine(offen)
        hasher.combine(schonDabei)
    }

    func name(_ uebung: ZirkelUebung) -> String {
        station.exercises.first { $0.id == uebung.exerciseId }?.name ?? "Übung"
    }

    var hinweis: String? {
        schonDabei.isEmpty ? nil : "Schon im Zirkel: " + schonDabei.map(name).joined(separator: ", ")
    }

    /// Die offenen Uebungen im Format der normalen Uebungsauswahl, in
    /// Katalogreihenfolge. Zuordnung wie `GeraetModel.uebungen` aus dem
    /// Bootstrap (ohne Video: die Zeile zeigt das Video ueber die Kachel).
    var geraetUebungen: [GeraetUebung] {
        offen.compactMap { uebung in
            station.exercises.first { $0.id == uebung.exerciseId }.map {
                GeraetUebung(id: $0.id, name: $0.name, volumeKind: $0.volumeKind,
                             targetMin: $0.targetMin, targetMax: $0.targetMax,
                             videoURL: nil, muscles: $0.muscles)
            }
        }
    }

    /// Die Bloecke von heute an dieser Station -- ein Geraet kann dieselbe
    /// Uebung an zwei Stationen haben, und die Wahl betrifft nur diese.
    func heutigeBloecke(_ bloecke: [LokalerBlock]) -> [LokalerBlock] {
        bloecke.filter { $0.stationSchluessel == station.schluessel && !$0.saetze.isEmpty }
    }

    /// Heute schon gemachte Uebungen zuerst, sonst die Katalogreihenfolge.
    func sortiert(bloecke: [LokalerBlock]) -> [GeraetUebung] {
        let heute = Set(heutigeBloecke(bloecke).map(\.exerciseId))
        let alle = geraetUebungen
        return alle.filter { heute.contains($0.id) } + alle.filter { !heute.contains($0.id) }
    }

    /// Wie im freien Training (Testnotiz 10.11., #14): heute an dieser
    /// Station gemacht "Heute · 2 Sätze · 7,5 kg", sonst der letzte Satz
    /// aus dem Bootstrap "vor 3 Tagen · 10,0 kg", ohne beides "Noch nie ·
    /// Ziel 8 – 12 Wdh.". `hatHistorie` ist zugleich der Favorit.
    static func untertitel(_ uebung: GeraetUebung, station: Station, bloecke: [LokalerBlock],
                           bootstrap: BootstrapResponse?, jetzt: Date = Date()) -> (text: String, hatHistorie: Bool) {
        if let block = bloecke.first(where: {
            $0.stationSchluessel == station.schluessel && $0.exerciseId == uebung.id && !$0.saetze.isEmpty
        }) {
            return ("Heute · \(TrainingTab.blockzeile(block))", true)
        }
        if let bootstrap,
           let letzter = UebungsHistorie.letzterSatz(an: station, uebungId: uebung.id, in: bootstrap),
           let zeile = UebungsHistorie.zeile(letzter, loadUnit: station.equipmentModel.loadUnit, jetzt: jetzt) {
            return (zeile, true)
        }
        return (UebungsHistorie.nochNie(uebung), false)
    }
}

/// Blatt statt Aktionsdialog: der Dialog hing an der Wurzel des Auswahl-
/// Stacks und blieb unter der Kategorie-Seite unsichtbar.
struct ZirkelUebungswahlSheet: View {
    let wahl: ZirkelUebungswahl
    /// Als Seite im Stack des Auswahl-Sheets: dessen Leiste und Detents gelten.
    var eingebettet = false
    /// Die Bloecke der laufenden Einheit: Untertitel und Reihenfolge kommen von heute.
    var bloecke: [LokalerBlock] = []
    /// Die Historie an der Station fuer Favorit und Untertitel.
    var bootstrap: BootstrapResponse?
    let beiWahl: (ZirkelUebung) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage(Einstellungen.uebungsansichtKey) private var ansichtRoh = Uebungsansicht.muskel.rawValue

    private var ansicht: Binding<Uebungsansicht> {
        Binding(get: { Uebungsansicht(rawValue: ansichtRoh) ?? .muskel },
                set: { ansichtRoh = $0.rawValue })
    }

    var body: some View {
        if eingebettet {
            liste
        } else {
            NavigationStack {
                liste
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Abbrechen") { dismiss() }
                                .foregroundStyle(DesignSystem.Color.textMuted)
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var liste: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
                Text(untertitelDerStation(wahl.station))
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                UebungsAnsichtBereich(uebungen: wahl.sortiert(bloecke: bloecke),
                                      hatHistorie: { untertitel($0).hatHistorie },
                                      ansicht: ansicht) { uebung in
                    Button { waehlen(uebung.id) } label: { zeile(uebung) }
                        .buttonStyle(PressButtonStyle())
                }
                if let hinweis = wahl.hinweis {
                    Text(hinweis)
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Color.textFaint)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, DesignSystem.Spacing.s24)
        }
        .background(DesignSystem.Color.bg)
        .navigationTitle("Welche Übung?")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Wie auf der Uebungsliste am Geraet: Typ und, am Geraet, das Label.
    private func untertitelDerStation(_ station: Station) -> String {
        [station.equipmentModel.name, station.machineId == nil ? nil : station.label]
            .compactMap { $0 }.joined(separator: " · ")
    }

    private func waehlen(_ exerciseId: String) {
        guard let uebung = wahl.offen.first(where: { $0.exerciseId == exerciseId }) else { return }
        beiWahl(uebung)
    }

    private func untertitel(_ uebung: GeraetUebung) -> (text: String, hatHistorie: Bool) {
        ZirkelUebungswahl.untertitel(uebung, station: wahl.station, bloecke: bloecke, bootstrap: bootstrap)
    }

    private func zeile(_ uebung: GeraetUebung) -> some View {
        let untertitel = untertitel(uebung)
        return HStack(spacing: DesignSystem.Spacing.s12) {
            UebungsVideoKachel(exerciseId: uebung.id) { Uebungsbild() }
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text(uebung.name)
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.text)
                UebungsUntertitel(text: untertitel.text, hatHistorie: untertitel.hatHistorie)
            }
            Spacer()
        }
        .padding(DesignSystem.Spacing.s12)
        .frame(minHeight: 44)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .accessibilityElement(children: .combine)
    }
}
