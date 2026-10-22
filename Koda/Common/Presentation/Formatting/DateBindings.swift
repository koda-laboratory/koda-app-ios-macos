import SwiftUI

extension Binding where Value == LocalDay {
    /// A `Date` binding for `DatePicker` (the day at midnight in the device time zone).
    var date: Binding<Date> {
        Binding<Date>(
            get: { wrappedValue.startDate(in: .current) },
            set: { wrappedValue = LocalDay(date: $0, timeZone: .current) }
        )
    }
}

extension Binding where Value == LocalTime {
    /// A `Date` binding for an hour-and-minute `DatePicker`.
    var date: Binding<Date> {
        Binding<Date>(
            get: { wrappedValue.date(on: LocalDay(year: 2001, month: 1, day: 1), in: .current) },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                wrappedValue = LocalTime(hour: components.hour ?? 0, minute: components.minute ?? 0)
            }
        )
    }
}
