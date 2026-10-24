import SwiftUI

/// "HOY EN CASA · 2 de 3 comidas hechas", with one arc band per meal (breakfast, lunch, dinner).
struct TodayHeroCard: View {
    let progress: TodayProgress
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // At accessibility sizes the text needs the full width: the arcs go below it.
        let layout =
            dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: KodaSpacing.m))
            : AnyLayout(HStackLayout(alignment: .center, spacing: KodaSpacing.m))
        layout {
            VStack(alignment: .leading, spacing: KodaSpacing.s - 2) {
                Text("today.hero.eyebrow").kodaEyebrow(color: KodaColor.taupe)
                if progress.totalCount > 0 {
                    HStack(alignment: .firstTextBaseline, spacing: KodaSpacing.xs - 2) {
                        Text(verbatim: "\(progress.doneCount)")
                            .font(KodaTypography.counter)
                        Text("today.hero.of \(progress.totalCount)")
                            .font(KodaTypography.title)
                            .foregroundStyle(KodaColor.taupe)
                    }
                    .foregroundStyle(KodaColor.cream)
                }
                Text(message)
                    .font(KodaTypography.callout)
                    .foregroundStyle(KodaColor.taupeLight)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 0)
            }
            KodaProgressArcs(
                bandsDone: TodayProgress.bandSlots.map(progress.isBandDone),
                doneCount: progress.doneCount,
                totalCount: progress.totalCount
            )
            .frame(width: KodaSize.heroArcsWidth)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(KodaSpacing.l - 2)
        .background(KodaGradient.signature, in: RoundedRectangle(cornerRadius: KodaRadius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: KodaRadius.large, style: .continuous)
                .strokeBorder(KodaColor.separator)
        }
        .shadow(color: KodaColor.onyx.opacity(0.22), radius: 20, y: 18)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("today-hero")
    }

    private var message: LocalizedStringKey {
        guard progress.totalCount > 0 else { return "today.hero.nothing-planned" }
        if let next = progress.nextMeal {
            return "today.hero.next \(next.entry.title)"
        }
        return "today.hero.all-done"
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Hero") {
        TodayHeroCard(progress: TodayPreviewFactory.progress(done: 2))
            .padding()
            .kodaPreview()
    }

    #Preview("Hero · nothing planned") {
        TodayHeroCard(progress: TodayProgress(meals: []))
            .padding()
            .kodaPreview()
    }

    #Preview("Hero · dark") {
        TodayHeroCard(progress: TodayPreviewFactory.progress(done: 1))
            .padding()
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Hero · accessibility size") {
        ScrollView {
            TodayHeroCard(progress: TodayPreviewFactory.progress(done: 2))
                .padding()
        }
        .dynamicTypeSize(.accessibility3)
        .kodaPreview()
    }

    #Preview("Hero · Mac", traits: .fixedLayout(width: 800, height: 300)) {
        TodayHeroCard(progress: TodayPreviewFactory.progress(done: 3))
            .frame(width: 520)
            .kodaPreview()
    }
#endif
