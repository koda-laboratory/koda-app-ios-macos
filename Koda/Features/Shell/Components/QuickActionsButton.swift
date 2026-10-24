import SwiftUI

/// The "+" of the app: add to the shopping list, plan a meal or create a recipe. On the Mac it is a toolbar menu
/// on every section; on iPhone it is the separate "+" at the trailing end of the tab bar (see `MainTabView`),
/// which opens `quickActionsDialog`.
struct QuickActionsModifier: ViewModifier {
    let onSelect: (AppQuickAction) -> Void

    func body(content: Content) -> some View {
        switch PlatformIdiom.current {
        case .phone:
            content
        case .mac:
            content.toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        QuickActionButtons(onSelect: onSelect)
                    } label: {
                        Label("quick-actions.title", systemImage: "plus")
                    }
                    .menuIndicator(.hidden)
                    .help(Text("quick-actions.title"))
                    .accessibilityIdentifier("quick-actions")
                }
            }
        }
    }
}

/// The three quick actions, shared by the Mac menu and the iPhone dialog.
private struct QuickActionButtons: View {
    let onSelect: (AppQuickAction) -> Void

    var body: some View {
        Button("quick-actions.add-to-shopping", systemImage: "cart.badge.plus") { onSelect(.addToShopping) }
        Button("quick-actions.plan-meal", systemImage: "calendar.badge.plus") { onSelect(.planMeal) }
        Button("quick-actions.new-recipe", systemImage: "book.closed") { onSelect(.newRecipe) }
    }
}

extension View {
    func quickActions(onSelect: @escaping (AppQuickAction) -> Void) -> some View {
        modifier(QuickActionsModifier(onSelect: onSelect))
    }

    /// The iPhone quick actions, presented when the tab bar's "+" is tapped.
    func quickActionsDialog(isPresented: Binding<Bool>, onSelect: @escaping (AppQuickAction) -> Void) -> some View {
        confirmationDialog("quick-actions.title", isPresented: isPresented, titleVisibility: .hidden) {
            QuickActionButtons(onSelect: onSelect)
            Button("common.cancel", role: .cancel) {}
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Quick actions · iPhone") {
        Color.clear
            .quickActionsDialog(isPresented: .constant(true)) { _ in }
            .kodaPreview()
    }

    #Preview("Quick actions · dark") {
        Color.clear
            .quickActionsDialog(isPresented: .constant(true)) { _ in }
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
