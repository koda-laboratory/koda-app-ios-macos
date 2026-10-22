import SwiftUI

/// "Generar compra" (approved mockup `GenerateShopping`).
struct GenerateShoppingSheet: View {
    @State private var viewModel: GenerateShoppingViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(viewModel: GenerateShoppingViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KodaSpacing.m) {
                    Text("generate.subtitle \(weekdayName)")
                        .font(KodaTypography.subheadline.weight(.regular))
                        .foregroundStyle(KodaColor.textSecondary)

                    HStack(spacing: KodaSpacing.s - 2) {
                        RangeDayField(labelKey: "generate.from", day: viewModel.from, isPrimary: true) { day in
                            Task { await viewModel.send(.setFrom(day)) }
                        }
                        RangeDayField(labelKey: "generate.through", day: viewModel.through, isPrimary: false) { day in
                            Task { await viewModel.send(.setThrough(day)) }
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: KodaSpacing.xs) {
                            ForEach(ShoppingCycle.QuickRange.allCases) { range in
                                ChipView(titleKey: titleKey(for: range), isSelected: viewModel.quickRange == range) {
                                    Task { await viewModel.send(.selectQuickRange(range)) }
                                }
                            }
                        }
                    }

                    GenerateCandidatesList(viewModel: viewModel)

                    Text("generate.footnote")
                        .font(KodaTypography.caption)
                        .foregroundStyle(KodaColor.textSecondary)
                        .padding(.horizontal, KodaSpacing.xxs)
                }
                .padding(KodaSpacing.l - 4)
            }
            .background(KodaColor.background)
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(
                    "generate.add \(viewModel.toAdd.count)",
                    isLoading: viewModel.state == .adding
                ) {
                    Task { await viewModel.send(.add) }
                }
                .disabled(viewModel.toAdd.isEmpty)
                .padding(.horizontal, KodaSpacing.l - 4)
                .padding(.bottom, KodaSpacing.s)
                .accessibilityIdentifier("generate-add")
            }
            .navigationTitle(Text("generate.title"))
            .platformInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") { dismiss() }
                }
            }
            .toast($viewModel.toast)
        }
        .presentationDetents([.large])
        .platformSheetSize(width: 560, height: 720)
        .task { await viewModel.send(.appeared) }
        .onChange(of: viewModel.state) {
            if case .completed = viewModel.state { dismiss() }
        }
    }

    private var weekdayName: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let symbols = calendar.standaloneWeekdaySymbols
        // ISO 1 (Monday) … 7 (Sunday) → Gregorian symbols where index 0 is Sunday.
        return symbols[viewModel.shoppingWeekday % 7].lowercased()
    }

    private func titleKey(for range: ShoppingCycle.QuickRange) -> LocalizedStringKey {
        switch range {
        case .untilNextShoppingDay: "generate.range.until \(weekdayName)"
        case .weekend: "generate.range.weekend"
        case .fromToday: "generate.range.from-today"
        }
    }
}

/// "DESDE · Sáb 24 oct", editable with a compact date picker.
private struct RangeDayField: View {
    let labelKey: LocalizedStringKey
    let day: LocalDay
    let isPrimary: Bool
    let onChange: (LocalDay) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: KodaSpacing.xs - 2) {
            Text(labelKey).kodaEyebrow()
            DatePicker(
                selection: Binding(get: { day }, set: { onChange($0) }).date,
                displayedComponents: .date
            ) {
                Text(labelKey)
            }
            .labelsHidden()
            .datePickerStyle(.compact)
        }
        .padding(.horizontal, KodaSpacing.s + 2)
        .padding(.vertical, KodaSpacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KodaColor.surface, in: RoundedRectangle(cornerRadius: KodaRadius.tile, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: KodaRadius.tile, style: .continuous)
                .strokeBorder(isPrimary ? KodaColor.brand : KodaColor.brand.opacity(0.18), lineWidth: isPrimary ? 2 : 1)
        }
    }
}

/// "SE AÑADIRÁN 3 COMIDAS" and the planned recipes with checkboxes; already-added ones appear done.
private struct GenerateCandidatesList: View {
    let viewModel: GenerateShoppingViewModel
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: KodaSpacing.xs) {
            ListLabel(text: String(localized: "generate.will-add \(viewModel.toAdd.count)").uppercased())
            if viewModel.state == .loading {
                ProgressView().frame(maxWidth: .infinity).padding()
            } else if viewModel.candidates.isEmpty {
                Text("generate.empty")
                    .font(KodaTypography.callout)
                    .foregroundStyle(KodaColor.textSecondary)
                    .padding(KodaSpacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .kodaCardBackground()
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.candidates) { candidate in
                        CandidateRow(
                            candidate: candidate,
                            isSelected: viewModel.selectedIDs.contains(candidate.id),
                            detail: detail(for: candidate)
                        ) {
                            Task { await viewModel.send(.toggle(candidate.id)) }
                        }
                        if candidate.id != viewModel.candidates.last?.id {
                            Divider().overlay(KodaColor.background)
                        }
                    }
                }
                .background(KodaColor.surface, in: RoundedRectangle(cornerRadius: KodaRadius.card, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: KodaRadius.card, style: .continuous))
            }
        }
    }

    private func detail(for candidate: ShoppingCandidate) -> String {
        let day = KodaFormat.shortDay(candidate.entry.day, locale: locale).capitalizedFirst
        let slot = String(localized: candidate.entry.slot.titleResource).lowercased()
        let trailing =
            candidate.isAlreadyOnList
            ? String(localized: "generate.already-on-list")
            : String(localized: "generate.products \(candidate.productCount)")
        return KodaFormat.joined([day, slot, trailing])
    }
}

private struct CandidateRow: View {
    let candidate: ShoppingCandidate
    let isSelected: Bool
    let detail: String
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: KodaSpacing.s) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(candidate.isAlreadyOnList ? KodaColor.textTertiary : KodaColor.brandText)
                    .symbolEffect(.bounce, value: isSelected)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: candidate.entry.title)
                        .font(KodaTypography.subheadline.weight(.bold))
                        .foregroundStyle(candidate.isAlreadyOnList ? KodaColor.textSecondary : KodaColor.textPrimary)
                    Text(verbatim: detail)
                        .font(KodaTypography.caption)
                        .foregroundStyle(KodaColor.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, KodaSpacing.m)
            .padding(.vertical, KodaSpacing.s + 1)
            .background(candidate.isAlreadyOnList ? KodaColor.background.opacity(0.6) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(candidate.isAlreadyOnList)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("generate-candidate-\(candidate.id)")
    }

    private var icon: String {
        if candidate.isAlreadyOnList { return "checkmark" }
        return isSelected ? "checkmark.square.fill" : "square"
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Generate shopping") {
        Color.clear.sheet(isPresented: .constant(true)) {
            GenerateShoppingSheet(viewModel: ShoppingPreviewFactory.makeGenerateShoppingViewModel())
        }
        .kodaPreview()
    }

    #Preview("Generate shopping · dark") {
        GenerateShoppingSheet(viewModel: ShoppingPreviewFactory.makeGenerateShoppingViewModel())
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Generate shopping · Mac", traits: .fixedLayout(width: 560, height: 720)) {
        GenerateShoppingSheet(viewModel: ShoppingPreviewFactory.makeGenerateShoppingViewModel())
            .kodaPreview()
    }
#endif
