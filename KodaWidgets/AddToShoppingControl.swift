import AppIntents
import SwiftUI
import WidgetKit

/// "Añadir a la compra" in Control Center: opens Koda with the shopping quick-add field focused.
struct AddToShoppingControl: ControlWidget {
    static let kind = "AddToShoppingControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenURLIntent(URL(string: "koda://shopping/add")!)) {
                Label("widget.control.add-shopping", systemImage: "cart.badge.plus")
            }
        }
        .displayName("widget.control.add-shopping")
        .description("widget.control.add-shopping.description")
    }
}
