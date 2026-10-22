import SwiftUI

/// The "+" of the app: add to the shopping list, plan a meal or create a recipe. A floating Liquid Glass
/// button on iPhone and a toolbar menu on the Mac.
struct QuickActionsModifier: ViewModifier {
    let onSelect: (AppQuickAction) -> Void

    func body(content: Content) -> some View {
        switch PlatformIdiom.current {
        case .phone:
            content.overlay(alignment: .bottomTrailing) {
                QuickActionsMenu(onSelect: onSelect) {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(KodaColor.cream)
                        .frame(width: KodaSize.fab, height: KodaSize.fab)
                        .glassEffect(.regular.tint(KodaColor.brand).interactive(), in: .circle)
                }
                .padding(.trailing, KodaSpacing.m)
                .padding(.bottom, KodaSpacing.s)
            }
        case .mac:
            content.toolbar {
                ToolbarItem(placement: .primaryAction) {
                    QuickActionsMenu(onSelect: onSelect) {
                        Label("quick-actions.title", systemImage: "plus")
                    }
                }
            }
        }
    }
}

private struct QuickActionsMenu<Label: View>: View {
    let onSelect: (AppQuickAction) -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Menu {
            Button("quick-actions.add-to-shopping", systemImage: "cart.badge.plus") { onSelect(.addToShopping) }
            Button("quick-actions.plan-meal", systemImage: "calendar.badge.plus") { onSelect(.planMeal) }
            Button("quick-actions.new-recipe", systemImage: "book.closed") { onSelect(.newRecipe) }
        } label: {
            label()
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel(Text("quick-actions.title"))
        .accessibilityIdentifier("quick-actions")
    }
}

extension View {
    func quickActions(onSelect: @escaping (AppQuickAction) -> Void) -> some View {
        modifier(QuickActionsModifier(onSelect: onSelect))
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Quick actions · iPhone") {
        Color.clear
            .quickActions { _ in }
            .kodaPreview()
    }

    #Preview("Quick actions · dark") {
        Color.clear
            .quickActions { _ in }
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Quick actions · Mac", traits: .fixedLayout(width: 800, height: 500)) {
        NavigationStack {
            Color.clear.quickActions { _ in }
        }
        .kodaPreview()
    }
#endif
