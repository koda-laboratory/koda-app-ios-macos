import SwiftUI

/// The Mac planning (approved mockup `MacPlanning`): seven day columns by slot rows. Meals can be dragged
/// between cells; empty cells offer "+ Añadir".
struct WeekGrid: View {
    let week: WeekPlan
    let slots: [MealSlot]
    let today: LocalDay
    let nextEntryID: UUID?
    let isEaten: (MealPlanEntry) -> Bool
    let onAdd: (LocalDay, MealSlot) -> Void
    let onEdit: (MealPlanEntry) -> Void
    let onRemove: (MealPlanEntry) -> Void
    let onMove: (UUID, LocalDay, MealSlot) -> Void

    var body: some View {
        Grid(horizontalSpacing: KodaSpacing.s - 2, verticalSpacing: KodaSpacing.s - 2) {
            GridRow {
                Color.clear.frame(width: KodaSize.slotLabelWidth, height: 1)
                ForEach(week.days) { day in
                    WeekGridDayHeader(day: day.day, isToday: day.day == today, isPast: day.day < today)
                }
            }
            ForEach(slots, id: \.self) { slot in
                GridRow {
                    Text(slot.titleKey)
                        .kodaEyebrow()
                        .frame(width: KodaSize.slotLabelWidth, alignment: .leading)
                    ForEach(week.days) { day in
                        WeekGridCell(
                            meals: day.meals(in: slot),
                            isPast: day.day < today,
                            nextEntryID: nextEntryID,
                            isEaten: isEaten,
                            onAdd: { onAdd(day.day, slot) },
                            onEdit: onEdit,
                            onRemove: onRemove
                        )
                        .dropDestination(for: String.self) { items, _ in
                            guard let id = items.first.flatMap(UUID.init(uuidString:)) else { return false }
                            onMove(id, day.day, slot)
                            return true
                        }
                    }
                }
            }
        }
    }
}

private struct WeekGridDayHeader: View {
    let day: LocalDay
    let isToday: Bool
    let isPast: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: weekdayText)
                .font(KodaTypography.caption.weight(.bold))
                .foregroundStyle(isToday ? KodaColor.taupe : KodaColor.textSecondary)
            Text(verbatim: KodaFormat.dayNumber(day))
                .font(KodaTypography.headline.weight(.heavy))
                .foregroundStyle(isToday ? KodaColor.cream : (isPast ? KodaColor.textSecondary : KodaColor.textPrimary))
        }
        .padding(.horizontal, isToday ? KodaSpacing.s - 2 : 0)
        .padding(.vertical, KodaSpacing.xs - 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isToday ? KodaColor.walnut : .clear, in: RoundedRectangle(cornerRadius: KodaRadius.small))
    }

    private var weekdayText: String {
        let weekday = KodaFormat.day(day, .dateTime.weekday(.abbreviated)).uppercased()
        return isToday ? String(localized: "planning.grid.today \(weekday)") : weekday
    }
}

private struct WeekGridCell: View {
    let meals: [MealPlanEntry]
    let isPast: Bool
    let nextEntryID: UUID?
    let isEaten: (MealPlanEntry) -> Bool
    let onAdd: () -> Void
    let onEdit: (MealPlanEntry) -> Void
    let onRemove: (MealPlanEntry) -> Void
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: KodaSpacing.xs - 2) {
            if meals.isEmpty {
                Button(action: onAdd) {
                    Text("planning.grid.add")
                        .font(KodaTypography.footnote.weight(.semibold))
                        .foregroundStyle(KodaColor.brandText)
                        .opacity(isPast ? 0 : (isHovering ? 1 : 0.7))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isPast)
                .background {
                    RoundedRectangle(cornerRadius: KodaSpacing.s + 2, style: .continuous)
                        .strokeBorder(
                            KodaColor.brandText.opacity(isPast ? 0.18 : 0.35),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                        )
                }
            } else {
                ForEach(meals) { entry in
                    WeekGridMeal(
                        entry: entry,
                        isEaten: isEaten(entry),
                        isNext: entry.id == nextEntryID,
                        isPast: isPast,
                        onEdit: { onEdit(entry) },
                        onRemove: { onRemove(entry) }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: KodaSize.gridCellHeight, maxHeight: .infinity)
        .onHover { isHovering = $0 }
    }
}

private struct WeekGridMeal: View {
    let entry: MealPlanEntry
    let isEaten: Bool
    let isNext: Bool
    let isPast: Bool
    let onEdit: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: KodaSpacing.xxs) {
                if isNext {
                    Text("planning.grid.now").kodaEyebrow(color: KodaColor.taupe)
                }
                Text(verbatim: entry.title)
                    .font(KodaTypography.subheadline.weight(.bold))
                    .foregroundStyle(foreground)
                    .multilineTextAlignment(.leading)
                if isEaten {
                    // A past meal reads as done through this label instead of a dimmed strikethrough,
                    // which was illegible on the dark surface.
                    Text("planning.grid.eaten")
                        .font(KodaTypography.caption.weight(.semibold))
                        .foregroundStyle(KodaColor.brandText)
                } else if let servings = entry.servings, !isPast, !isNext {
                    Text("planning.grid.servings \(Int(servings))")
                        .font(KodaTypography.caption)
                        .foregroundStyle(isUpcomingRecipe ? KodaColor.taupeLight : KodaColor.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(KodaSpacing.s)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(background, in: RoundedRectangle(cornerRadius: KodaSpacing.s + 2, style: .continuous))
            .overlay {
                if isEaten, !isPast {
                    RoundedRectangle(cornerRadius: KodaSpacing.s + 2, style: .continuous)
                        .strokeBorder(KodaColor.brand, lineWidth: 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .draggable(entry.id.uuidString)
        .contextMenu {
            Button("planning.meal.change", systemImage: "pencil", action: onEdit)
            Button("planning.meal.remove", systemImage: "trash", role: .destructive, action: onRemove)
        }
        .accessibilityIdentifier("grid-meal-\(entry.id)")
    }

    private var isUpcomingRecipe: Bool { entry.isRecipe && !isEaten && !isNext && !isPast }

    private var background: Color {
        if isNext { return KodaColor.onyx }
        if isPast { return KodaColor.surface }
        if !entry.isRecipe { return KodaColor.accentSoft }
        if isEaten { return KodaColor.surface }
        return KodaColor.walnut
    }

    private var foreground: Color {
        if isNext || isUpcomingRecipe { return KodaColor.cream }
        if isPast { return KodaColor.textSecondary }
        return KodaColor.textPrimary
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Week grid · Mac", traits: .fixedLayout(width: 1100, height: 600)) {
        WeekGrid(
            week: PlanningPreviewFactory.week,
            slots: [.breakfast, .lunch, .dinner],
            today: PlanningPreviewFactory.week.days[3].day,
            nextEntryID: PlanningPreviewFactory.week.days[3].meals.last?.id,
            isEaten: { $0.day < PlanningPreviewFactory.week.days[3].day },
            onAdd: { _, _ in },
            onEdit: { _ in },
            onRemove: { _ in },
            onMove: { _, _, _ in }
        )
        .padding()
        .kodaPreview()
    }

    #Preview("Week grid · dark", traits: .fixedLayout(width: 1100, height: 600)) {
        WeekGrid(
            week: PlanningPreviewFactory.week,
            slots: [.breakfast, .lunch, .dinner],
            today: PlanningPreviewFactory.week.days[1].day,
            nextEntryID: nil,
            isEaten: { _ in false },
            onAdd: { _, _ in },
            onEdit: { _ in },
            onRemove: { _ in },
            onMove: { _, _, _ in }
        )
        .padding()
        .kodaPreview()
        .preferredColorScheme(.dark)
    }

    #Preview("Week grid · iPhone width") {
        ScrollView(.horizontal) {
            WeekGrid(
                week: PlanningPreviewFactory.week,
                slots: [.lunch, .dinner],
                today: PlanningPreviewFactory.week.days[0].day,
                nextEntryID: nil,
                isEaten: { _ in false },
                onAdd: { _, _ in },
                onEdit: { _ in },
                onRemove: { _ in },
                onMove: { _, _, _ in }
            )
            .frame(width: 900)
        }
        .kodaPreview()
    }
#endif
