import SwiftUI

/// danger-Umriss auf 10 % danger-Flaeche (designsystem.md SS5).
///
/// Sichtbarkeit ist Sache des Aufrufers (GeraetView) -- dieselbe if-Kette wie
/// bei ResttimerBalken, statt sie hier in body zu verstecken.
struct OfflineLeiste: View {
    let istOnline: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.s8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 15, weight: .semibold))
            VStack(alignment: .leading, spacing: 2) {
                Text("Kein Empfang")
                    .font(.system(size: 15, weight: .semibold))
                Text("Alles hier kommt aus dem Speicher deines iPhones.")
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            Spacer()
        }
        .foregroundStyle(DesignSystem.Color.danger)
        .padding(DesignSystem.Spacing.s12)
        .background(DesignSystem.Color.danger.opacity(0.1))
        // clipShape VOR overlay: umgekehrt schneidet die Maske die
        // aeussere Haelfte der 1pt-Kontur weg und laesst eine halbe
        // uebrig (Vorlage: InlineBanner). Diese Leiste ist die Vorlage
        // fuer die Offline-Karten der Kurse-Screens -- stuende die
        // Reihenfolge hier falsch, kaeme der Fehler mit der naechsten
        // Kopie zurueck.
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .stroke(DesignSystem.Color.danger, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

/// Die Warteschlange.
///
/// Die Formulierung ist nicht verhandelbar: "gespeichert, wird gesendet",
/// nie "fehlgeschlagen" (designsystem.md SS5). Der Satz ist lokal sicher;
/// das muss die Sprache tragen.
///
/// `geradeGesendet` ist der Reconnect-Moment, der als Artboard fehlt: zwei
/// Sekunden "Gesendet", dann aus. Kein Toast, kein Haekchen-Jubel -- SS10
/// verbietet den Motivationston, und ein erfolgreicher Normalfall braucht
/// keine Feier.
struct WarteschlangeKarte: View {
    let offen: Int
    let geradeGesendet: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            Text(geradeGesendet ? "GESENDET" : "WARTET AUF EMPFANG · \(offen) \(offen == 1 ? "SATZ" : "SÄTZE")")
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
            if !geradeGesendet {
                Text("Sicher gespeichert. Sie gehen automatisch raus, sobald du wieder Netz hast — auch wenn du die App schließt.")
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textFaint)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.s16)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .accessibilityElement(children: .combine)
    }
}

/// Dauerhaft abgelehnte Schreibvorgaenge. Sie verschwinden nicht
/// stillschweigend -- SS5 verlangt, dass ein Fehler sagt, was falsch ist UND
/// was gilt.
struct AbgelehnteKarte: View {
    let anzahl: Int
    let beiQuittieren: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
            Text("\(anzahl) \(anzahl == 1 ? "Satz konnte" : "Sätze konnten") nicht gespeichert werden.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.danger)
            // Nennt keine einzelne Ursache: hinter istDauerhaft stecken vier
            // Faelle (Konto, Eingabe, Geraet/Uebung, Konflikt), und die
            // Formulierung muss fuer alle vier stimmen -- SS5 verlangt zu
            // sagen, was gilt, nicht zu raten, was falsch war.
            Text("Sie stehen nicht in deinem Verlauf. Deine übrigen Sätze sind unberührt. Frag im Studio nach, wenn du sie brauchst.")
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Color.textMuted)
                .lineSpacing(3)
            Button("Verstanden", action: beiQuittieren)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.text)
                .frame(minHeight: 44)
                .buttonStyle(PressButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.s16)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .stroke(DesignSystem.Color.danger, lineWidth: 1)
        )
        // .contain, nicht .combine: "Verstanden" bleibt ein eigener Button,
        // sonst waere die einzige Karte, die eine Aktion braucht, fuer
        // VoiceOver nicht bedienbar (Review-Fund Task 15).
        .accessibilityElement(children: .contain)
    }
}
