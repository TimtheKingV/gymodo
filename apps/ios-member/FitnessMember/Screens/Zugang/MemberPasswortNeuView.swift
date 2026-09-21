import SwiftUI

/// Schritt 3 von 3 des Passwort-Zuruecksetzen-Flows: das neue Passwort.
///
/// Ein Feld, keine Wiederholung (Testnotiz 21.09., Eintrag 3). Die
/// Wiederholung soll Tippfehler abfangen, wird aber ueblicherweise aus dem
/// ersten Feld hineinkopiert und kostet dann jeden eine zweite Eingabe,
/// ohne irgendetwas zu pruefen. Wer sich doch vertippt, kommt ueber
/// denselben Weg noch einmal hierher -- die Mail ist eine Minute entfernt.
///
/// Die Adresse steht oben als ausgefuelltes, nicht editierbares Feld: sie
/// beantwortet "fuer welches Konto gilt das gerade?", ohne eine Entscheidung
/// anzubieten, die an dieser Stelle keine mehr ist. `textContentType(.username)`
/// ist dabei nicht Zierde -- erst damit legt der Passwortmanager das neue
/// Passwort unter dem richtigen Konto ab.
struct MemberPasswortNeuView: View {
    let email: String

    @Environment(SessionStore.self) private var sessionStore

    @State private var newPassword = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("NEUES PASSWORT").font(DesignSystem.Typography.screentitel)
                    Text("Ab jetzt meldest du dich damit an.")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }

                LabeledField(label: "E-Mail-Adresse") {
                    TextField("", text: .constant(email))
                        .textContentType(.username)
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .disabled(true)
                }

                LabeledField(label: "Neues Passwort") {
                    SecureField("••••••••••", text: $newPassword)
                        .textContentType(.newPassword)
                }
                Text("Mindestens zehn Zeichen. Länge zählt mehr als Sonderzeichen.")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)

                if let errorMessage {
                    InlineBanner(tone: .danger, message: errorMessage)
                }
            }
            .padding(28)
        }
        .background(DesignSystem.Color.bg)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(
                title: "Passwort speichern",
                isEnabled: PasswordPolicy.isValid(newPassword),
                isLoading: isSaving,
                disabledHint: PasswordPolicy.isValid(newPassword)
                    ? nil : "Noch mindestens \(PasswordPolicy.minimumLength - newPassword.count) Zeichen"
            ) {
                await save()
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
            .background(DesignSystem.Color.bg)
        }
        // Der geprüfte Code liegt als noch nicht veroeffentlichte Session im
        // SessionStore. Wer hier wieder rausgeht, ohne gespeichert zu haben,
        // soll nicht mit halber Wiederherstellung im Keychain zurueckbleiben
        // -- sonst meldete ihn der naechste Kaltstart an, obwohl nie ein
        // Passwort gesetzt wurde.
        //
        // Kein eigenes "schon gespeichert"-Flag: nach dem Speichern gibt es
        // nichts Offenes mehr, und `cancelPasswordReset` tut dann nichts.
        // Der erfolgreiche Weg loest dieselbe onDisappear aus (die Wurzel
        // tauscht den ganzen Baum gegen Home) -- er darf hier also gar nicht
        // erst unterschieden werden muessen.
        .onDisappear {
            Task { await sessionStore.cancelPasswordReset() }
        }
        .testnotizScreen()
    }

    private func save() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await sessionStore.completePasswordReset(newPassword: newPassword)
        } catch {
            errorMessage = AuthCopy.passwortNichtGespeichert
        }
    }
}
