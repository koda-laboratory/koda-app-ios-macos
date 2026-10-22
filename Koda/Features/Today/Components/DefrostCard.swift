import SwiftUI

/// "DESCONGELAR HOY · Carrilleras de cerdo · Mañana a las 14:30 toca Paella de carrilleras · Hecho".
struct DefrostCard: View {
    let item: FrozenItem
    let mealText: String
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: KodaSpacing.s + 2) {
            Image(systemName: "snowflake")
                .font(.title3)
                .foregroundStyle(KodaColor.taupe)
                .frame(width: 48, height: 48)
                .background(KodaColor.onyx, in: RoundedRectangle(cornerRadius: KodaSpacing.m, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("today.defrost.eyebrow").kodaEyebrow()
                Text(verbatim: item.productName)
                    .font(KodaTypography.subheadline.weight(.bold))
                    .foregroundStyle(KodaColor.textPrimary)
                if !mealText.isEmpty {
                    Text(verbatim: mealText)
                        .font(KodaTypography.footnote)
                        .foregroundStyle(KodaColor.textSecondary)
                }
            }
            Spacer(minLength: 0)
            Button("today.defrost.done", action: onDone)
                .buttonStyle(.kodaPill())
                .accessibilityIdentifier("defrost-done")
        }
        .padding(KodaSpacing.m)
        .kodaCardBackground(highlight: KodaColor.taupe)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Defrost") {
        DefrostCard(item: TodayPreviewFactory.frozenItem, mealText: "Mañana a las 14:30 toca Paella de carrilleras") {}
            .padding()
            .kodaPreview()
    }

    #Preview("Defrost · dark") {
        DefrostCard(item: TodayPreviewFactory.frozenItem, mealText: "Hoy a las 21:30 toca Alitas de pollo") {}
            .padding()
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Defrost · Mac", traits: .fixedLayout(width: 800, height: 240)) {
        DefrostCard(item: TodayPreviewFactory.frozenItem, mealText: "") {}
            .frame(width: 520)
            .kodaPreview()
    }
#endif
