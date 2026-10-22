import SwiftUI

/// "Hace tiempo que no" carousel card: days since it was last eaten and the recipe name.
struct ForgottenRecipeCard: View {
    let name: String
    let days: Int
    let isFirst: Bool

    var body: some View {
        VStack(alignment: .leading) {
            Text("recipes.forgotten.days \(days)")
                .font(KodaTypography.caption.weight(.bold))
                .padding(.horizontal, KodaSpacing.s - 2)
                .padding(.vertical, KodaSpacing.xxs + 1)
                .background(isFirst ? KodaColor.taupe.opacity(0.22) : Color.white.opacity(0.45), in: Capsule())
            Spacer(minLength: KodaSpacing.s)
            Text(verbatim: name)
                .font(KodaTypography.title)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
        }
        .foregroundStyle(isFirst ? KodaColor.taupeLight : KodaColor.walnutDeep)
        .padding(KodaSpacing.m)
        .frame(width: KodaSize.carouselCardWidth, height: KodaSize.carouselCardHeight, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: KodaRadius.large - 4, style: .continuous)
                .fill(isFirst ? AnyShapeStyle(KodaGradient.signature) : AnyShapeStyle(KodaColor.taupe))
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Forgotten") {
        HStack {
            ForgottenRecipeCard(name: "Gnocchi cabrales con espinacas", days: 21, isFirst: true)
            ForgottenRecipeCard(name: "Bacalao al pil pil", days: 34, isFirst: false)
        }
        .padding()
        .kodaPreview()
    }

    #Preview("Forgotten · dark") {
        ForgottenRecipeCard(name: "Bacalao al pil pil", days: 34, isFirst: true)
            .padding()
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Forgotten · Mac", traits: .fixedLayout(width: 600, height: 240)) {
        ForgottenRecipeCard(name: "Gnocchi cabrales", days: 21, isFirst: false)
            .kodaPreview()
    }
#endif
