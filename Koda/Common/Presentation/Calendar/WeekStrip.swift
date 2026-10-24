import SwiftUI

// MARK: - Week Strip

/// Revolut-style week selector: seven day buttons with a dot for planned days.
struct WeekStrip: View {
    struct Day: Identifiable, Equatable {
        let day: LocalDay
        let isToday: Bool
        /// 0 = nothing planned, 1 = partially, 2 = every main meal planned.
        let fill: Int

        var id: LocalDay { day }
    }

    let days: [Day]
    let selected: LocalDay?
    let onSelect: (LocalDay) -> Void

    var body: some View {
        HStack(spacing: KodaSpacing.xxs + 2) {
            ForEach(days) { day in
                WeekStripDayButton(day: day, isSelected: day.day == selected) { onSelect(day.day) }
            }
        }
        // Seven columns cannot grow with the largest text sizes; VoiceOver reads the full date of each day.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .contain)
    }
}

private struct WeekStripDayButton: View {
    let day: WeekStrip.Day
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: KodaSpacing.xxs) {
                Text(verbatim: KodaFormat.weekdayInitial(day.day).uppercased())
                    .font(KodaTypography.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? KodaColor.taupeLight : KodaColor.textSecondary)
                Text(verbatim: KodaFormat.dayNumber(day.day))
                    .font(KodaTypography.headline.weight(.heavy))
                    .foregroundStyle(isSelected ? KodaColor.cream : KodaColor.textPrimary)
                Circle()
                    .fill(day.fill == 2 ? KodaColor.brand : KodaColor.taupe)
                    .frame(width: KodaSize.dot, height: KodaSize.dot)
                    .opacity(day.fill == 0 ? 0 : 1)
            }
            .frame(maxWidth: .infinity, minHeight: KodaSize.weekDayHeight)
            .background(
                isSelected ? KodaColor.brand : (day.fill == 0 ? Color.clear : KodaColor.surface),
                in: RoundedRectangle(cornerRadius: KodaRadius.tile, style: .continuous)
            )
            .overlay {
                if day.fill == 0, !isSelected {
                    RoundedRectangle(cornerRadius: KodaRadius.tile, style: .continuous)
                        .strokeBorder(KodaColor.brand.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: KodaRadius.tile, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: KodaFormat.longDay(day.day)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Week strip") {
        @Previewable @State var selected = PresentationPreviewFactory.today
        WeekStrip(
            days: PresentationPreviewFactory.week.enumerated().map { index, day in
                WeekStrip.Day(
                    day: day,
                    isToday: day == PresentationPreviewFactory.today,
                    fill: index == 6 ? 0 : 1 + index % 2
                )
            },
            selected: selected
        ) { selected = $0 }
        .padding()
        .kodaPreview()
    }

    #Preview("Week strip · dark") {
        WeekStrip(
            days: PresentationPreviewFactory.week.map { WeekStrip.Day(day: $0, isToday: false, fill: 1) },
            selected: PresentationPreviewFactory.today
        ) { _ in }
        .padding()
        .kodaPreview()
        .preferredColorScheme(.dark)
    }

    #Preview("Week strip · Mac", traits: .fixedLayout(width: 700, height: 200)) {
        WeekStrip(
            days: PresentationPreviewFactory.week.map { WeekStrip.Day(day: $0, isToday: false, fill: 2) },
            selected: nil
        ) { _ in }
        .padding()
        .kodaPreview()
    }
#endif
