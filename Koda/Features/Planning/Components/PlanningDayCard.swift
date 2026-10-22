import SwiftUI

/// One day of the iPhone planning: its slots with the meal, the time and the eaten state.
struct PlanningDayCard: View {
    let day: DayPlan
    let title: String
    let slots: [MealSlot]
    let slotTimes: SlotTimes
    let isEaten: (MealPlanEntry) -> Bool
    let onAdd: (MealSlot) -> Void
    let onEdit: (MealPlanEntry) -> Void
    let onRemove: (MealPlanEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: KodaSpacing.s - 2) {
            Text(verbatim: title)
                .font(KodaTypography.sectionTitle)
                .foregroundStyle(KodaColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                let rows = rowsToShow
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    Group {
                        switch row {
                        case .meal(let entry):
                            PlanningMealRow(
                                entry: entry,
                                time: entry.time(using: slotTimes),
                                isEaten: isEaten(entry),
                                onEdit: { onEdit(entry) },
                                onRemove: { onRemove(entry) }
                            )
                        case .empty(let slot):
                            PlanningAddRow(slot: slot) { onAdd(slot) }
                        }
                    }
                    if index < rows.count - 1 {
                        Divider().overlay(KodaColor.chip)
                    }
                }
            }
            .background(KodaColor.surface, in: RoundedRectangle(cornerRadius: KodaRadius.medium, style: .continuous))
        }
        .id(day.day)
    }

    private enum Row: Identifiable {
        case meal(MealPlanEntry)
        case empty(MealSlot)

        var id: String {
            switch self {
            case .meal(let entry): entry.id.uuidString
            case .empty(let slot): "empty-\(slot.rawValue)"
            }
        }
    }

    /// Planned meals in slot order, and an "Añadir" row for lunch and dinner when they are empty.
    private var rowsToShow: [Row] {
        slots.flatMap { slot -> [Row] in
            let meals = day.meals(in: slot)
            if meals.isEmpty {
                return slot == .lunch || slot == .dinner ? [.empty(slot)] : []
            }
            return meals.map(Row.meal)
        }
    }
}

/// "COMIDA · Curry de garbanzos · 14:30 · hecha".
struct PlanningMealRow: View {
    let entry: MealPlanEntry
    let time: LocalTime
    let isEaten: Bool
    let onEdit: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: KodaSpacing.s) {
                Text(entry.slot.titleKey)
                    .kodaEyebrow()
                    .frame(width: KodaSize.slotLabelWidth, alignment: .leading)
                if entry.isRecipe {
                    Text(verbatim: entry.title)
                        .font(KodaTypography.body.weight(isEaten ? .semibold : .bold))
                        .foregroundStyle(isEaten || entry.isSkipped ? KodaColor.textSecondary : KodaColor.textPrimary)
                        .strikethrough(isEaten || entry.isSkipped)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    TagView(text: entry.title)
                    Spacer(minLength: 0)
                }
                Text(trailingKey)
                    .font(KodaTypography.caption.weight(isEaten ? .bold : .semibold))
                    .foregroundStyle(isEaten ? KodaColor.brandText : KodaColor.textSecondary)
            }
            .padding(.horizontal, KodaSpacing.m)
            .padding(.vertical, KodaSpacing.s + 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("planning.meal.change", systemImage: "pencil", action: onEdit)
            Button("planning.meal.remove", systemImage: "trash", role: .destructive, action: onRemove)
        }
        .accessibilityIdentifier("planning-meal-\(entry.id)")
    }

    private var trailingKey: LocalizedStringKey {
        if entry.isSkipped { return "planning.meal.skipped \(time.description)" }
        return isEaten ? "planning.meal.eaten \(time.description)" : "planning.meal.time \(time.description)"
    }
}

/// "+ Añadir cena".
struct PlanningAddRow: View {
    let slot: MealSlot
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: KodaSpacing.s) {
                Text(slot.titleKey)
                    .kodaEyebrow()
                    .frame(width: KodaSize.slotLabelWidth, alignment: .leading)
                Text("planning.add-to-slot \(String(localized: slot.titleResource).lowercased())")
                    .font(KodaTypography.subheadline)
                    .foregroundStyle(KodaColor.brandText)
                Spacer()
            }
            .padding(.horizontal, KodaSpacing.m)
            .padding(.vertical, KodaSpacing.s + 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Day card") {
        ScrollView {
            PlanningDayCard(
                day: PlanningPreviewFactory.dayPlan,
                title: "Hoy, jueves 22",
                slots: [.breakfast, .lunch, .dinner],
                slotTimes: .default,
                isEaten: { $0.slot == .breakfast },
                onAdd: { _ in },
                onEdit: { _ in },
                onRemove: { _ in }
            )
            .padding()
        }
        .kodaPreview()
    }

    #Preview("Day card · dark") {
        PlanningDayCard(
            day: PlanningPreviewFactory.dayPlan,
            title: "Viernes 23",
            slots: [.breakfast, .lunch, .dinner],
            slotTimes: .default,
            isEaten: { _ in false },
            onAdd: { _ in },
            onEdit: { _ in },
            onRemove: { _ in }
        )
        .padding()
        .kodaPreview()
        .preferredColorScheme(.dark)
    }

    #Preview("Day card · Mac", traits: .fixedLayout(width: 800, height: 400)) {
        PlanningDayCard(
            day: PlanningPreviewFactory.dayPlan,
            title: "Sábado 24",
            slots: MealSlot.allCases,
            slotTimes: .default,
            isEaten: { _ in true },
            onAdd: { _ in },
            onEdit: { _ in },
            onRemove: { _ in }
        )
        .frame(width: 520)
        .kodaPreview()
    }
#endif
