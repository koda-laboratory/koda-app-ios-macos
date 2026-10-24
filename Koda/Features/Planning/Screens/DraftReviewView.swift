import SwiftUI

/// Review of a planning draft: its meals by day, accept or discard.
struct DraftReviewView: View {
    @State private var viewModel: DraftReviewViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(viewModel: DraftReviewViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KodaSpacing.l - 4) {
                if let rationale = viewModel.draft?.rationale, !rationale.isEmpty {
                    Label {
                        Text(verbatim: rationale)
                    } icon: {
                        Image(systemName: "sparkles").foregroundStyle(KodaColor.taupe)
                    }
                    .font(KodaTypography.callout)
                    .foregroundStyle(KodaColor.cream)
                    .padding(KodaSpacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(KodaGradient.signature, in: RoundedRectangle(cornerRadius: KodaRadius.card))
                }
                if viewModel.state == .finished {
                    ContentUnavailableView("draft.review.finished", systemImage: "checkmark.circle")
                }
                ForEach(viewModel.days) { day in
                    VStack(alignment: .leading, spacing: KodaSpacing.xs) {
                        Text(verbatim: KodaFormat.weekdayAndDay(day.day, locale: locale).capitalizedFirst)
                            .font(KodaTypography.sectionTitle)
                            .accessibilityAddTraits(.isHeader)
                        VStack(spacing: 0) {
                            ForEach(day.meals) { meal in
                                SlotRowLayout(isStacked: dynamicTypeSize.isAccessibilitySize) {
                                    Text(meal.slot.titleKey)
                                        .kodaEyebrow()
                                        .frame(
                                            width: dynamicTypeSize.isAccessibilitySize ? nil : KodaSize.slotLabelWidth,
                                            alignment: .leading
                                        )
                                    Text(verbatim: meal.title)
                                        .font(KodaTypography.body.weight(.semibold))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .accessibilityElement(children: .combine)
                                .padding(.horizontal, KodaSpacing.m)
                                .padding(.vertical, KodaSpacing.s + 2)
                                if meal.id != day.meals.last?.id {
                                    Divider().overlay(KodaColor.chip)
                                }
                            }
                        }
                        .background(KodaColor.surface, in: RoundedRectangle(cornerRadius: KodaRadius.medium))
                    }
                }
            }
            .padding(KodaSpacing.l - 4)
            .frame(maxWidth: KodaSize.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .background(KodaColor.background)
        .safeAreaInset(edge: .bottom) {
            if viewModel.state != .finished {
                HStack(spacing: KodaSpacing.s) {
                    Button("draft.review.discard") { Task { await viewModel.send(.discard) } }
                        .buttonStyle(.kodaPill(.outline))
                        .disabled(viewModel.state != .ready)
                        .accessibilityIdentifier("draft-discard")
                    PrimaryButton("draft.review.accept", isLoading: viewModel.state == .accepting) {
                        Task { await viewModel.send(.accept) }
                    }
                    .disabled(viewModel.state != .ready)
                    .accessibilityIdentifier("draft-accept")
                }
                .padding(KodaSpacing.m)
            }
        }
        .navigationTitle(Text("draft.review.title"))
        .platformInlineNavigationTitle()
        .toast($viewModel.toast)
        .task { await viewModel.send(.appeared) }
        .platformHaptic(.success, trigger: viewModel.state) { _, state in state == .finished }
        .onChange(of: viewModel.state) {
            if viewModel.state == .finished { dismiss() }
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Draft review · iPhone") {
        NavigationStack {
            PlanningPreviewFactory.makeDraftReviewView()
        }
        .kodaPreview()
    }

    #Preview("Draft review · dark") {
        NavigationStack {
            PlanningPreviewFactory.makeDraftReviewView()
        }
        .kodaPreview()
        .preferredColorScheme(.dark)
    }

    #Preview("Draft review · Mac", traits: .fixedLayout(width: 900, height: 700)) {
        NavigationStack {
            PlanningPreviewFactory.makeDraftReviewView()
        }
        .kodaPreview()
    }
#endif
