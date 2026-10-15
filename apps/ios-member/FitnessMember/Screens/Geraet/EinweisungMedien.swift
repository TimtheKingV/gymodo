import Foundation

/// Was die Einweisung an Medien zeigt (Offline-Spec 3c).
///
/// Vorher hing die Videokachel an der URL aus dem Geraetekontext -- offline
/// gibt es keinen, und die Einweisung sagte "braucht Empfang", obwohl die
/// Schleife laengst auf der Platte lag. Die Kachel sucht jetzt selbst in
/// der Ablage; nur wenn der Kontext feststeht und es nirgends ein Video
/// gibt, kommt die Fotovariante.
enum EinweisungMedien {
    static func zeigtVideokachel(kontextGeladen: Bool, kontextVideo: URL?, vorratKennt: Bool) -> Bool {
        kontextVideo != nil || vorratKennt || !kontextGeladen
    }
}
