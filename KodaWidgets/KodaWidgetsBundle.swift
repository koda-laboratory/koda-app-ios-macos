import SwiftUI
import WidgetKit

@main
struct KodaWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        ShoppingWidget()
        AddToShoppingControl()
    }
}
