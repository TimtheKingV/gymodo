import SwiftUI

struct MemberScannerView: View {
    let onScanned: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showManualEntry = false

    var body: some View {
        ZStack(alignment: .top) {
            QRScannerController(onCode: onScanned)
                .ignoresSafeArea()

            VStack {
                Capsule()
                    .fill(DesignSystem.Color.line)
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)

                HStack {
                    Text("CODE SCANNEN")
                        .font(DesignSystem.Typography.label)
                        .foregroundStyle(DesignSystem.Color.text)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(DesignSystem.Color.text)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Schließen")
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer()

                Button("Code stattdessen eingeben") {
                    showManualEntry = true
                    dismiss()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.text)
                .padding(.bottom, 24)
            }
        }
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(DesignSystem.Radius.haupt)
    }
}
