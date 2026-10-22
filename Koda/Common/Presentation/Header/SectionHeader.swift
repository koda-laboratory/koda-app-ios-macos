import SwiftUI

// MARK: - Section Header

/// Rounded section title with an optional trailing action ("Comidas de hoy · Semana").
struct SectionHeader: View {
    let titleKey: LocalizedStringKey
    var actionKey: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titleKey)
                .font(KodaTypography.sectionTitle)
                .foregroundStyle(KodaColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let actionKey, let action {
                Button(actionKey, action: action)
                    .font(KodaTypography.subheadline)
                    .foregroundStyle(KodaColor.brandText)
                    .buttonStyle(.plain)
            }
        }
    }
}

/// Uppercase list label with an optional trailing action ("YA LO TENEMOS · 3 · Vaciar").
struct ListLabel: View {
    let text: String
    var actionKey: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: text)
                .kodaEyebrow()
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let actionKey, let action {
                Button(actionKey, action: action)
                    .font(KodaTypography.subheadline.weight(.bold))
                    .foregroundStyle(KodaColor.brandText)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, KodaSpacing.xxs)
    }
}

// MARK: - Screen Header

/// Screen hero title: a secondary line above the rounded large title, with trailing content.
struct ScreenHeader<Trailing: View>: View {
    let subtitle: String
    let title: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: subtitle)
                    .font(KodaTypography.subheadline)
                    .foregroundStyle(KodaColor.textSecondary)
                Text(verbatim: title)
                    .font(KodaTypography.display)
                    .foregroundStyle(KodaColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: KodaSpacing.s)
            trailing()
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Headers") {
        VStack(alignment: .leading, spacing: KodaSpacing.l) {
            ScreenHeader(subtitle: "Jueves, 22 de octubre", title: "Hola, Manu") { EmptyView() }
            SectionHeader(titleKey: "today.meals.title", actionKey: "today.meals.week") {}
            ListLabel(text: "YA LO TENEMOS · 3", actionKey: "shopping.clear-have") {}
        }
        .padding()
        .kodaPreview()
    }

    #Preview("Headers · dark") {
        ScreenHeader(subtitle: "Semana 43 · octubre", title: "Planning") { EmptyView() }
            .padding()
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Headers · Mac", traits: .fixedLayout(width: 800, height: 200)) {
        SectionHeader(titleKey: "today.meals.title")
            .padding()
            .kodaPreview()
    }
#endif
