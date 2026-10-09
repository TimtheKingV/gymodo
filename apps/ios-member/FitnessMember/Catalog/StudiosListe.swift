import Foundation

/// Die Zeilen der Studioliste im Profil: Freies Training zuerst, dann die
/// Studios alphabetisch. Das Haekchen folgt dem gewaehlten Ort.
enum StudiosListe {
    struct Zeile: Equatable, Identifiable {
        let ort: Ort
        let name: String
        let istAktiv: Bool
        /// Aus dem Freien Training kann man nicht austreten.
        let darfVerlassen: Bool

        var id: String {
            switch ort {
            case .freiesTraining: "freiesTraining"
            case .studio(let id): "studio-\(id)"
            }
        }
    }

    static let freiesTrainingName = "Freies Training"
    static let fusstext = "Tippen wechselt. Ein Gerätecode aus einem anderen Studio macht dich dort zum Mitglied."

    static func zeilen(studios: [BootstrapResponse.Studio], ort: Ort) -> [Zeile] {
        let sortiert = studios.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        let frei = Zeile(ort: .freiesTraining, name: freiesTrainingName,
                         istAktiv: ort == .freiesTraining, darfVerlassen: false)
        return [frei] + sortiert.map {
            Zeile(ort: .studio($0.id), name: $0.name,
                  istAktiv: ort == .studio($0.id), darfVerlassen: true)
        }
    }

    /// Fuer "Training in {Ort} beenden?". Ein unbekanntes Studio (aus der
    /// Liste verschwunden) bleibt lesbar statt leer.
    static func name(fuer ort: Ort, studios: [BootstrapResponse.Studio]) -> String {
        switch ort {
        case .freiesTraining: freiesTrainingName
        case .studio(let id): studios.first { $0.id == id }?.name ?? "Studio"
        }
    }
}
