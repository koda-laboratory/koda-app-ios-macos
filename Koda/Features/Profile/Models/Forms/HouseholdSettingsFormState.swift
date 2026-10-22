/// Meal times and the shopping weekday edited in Profile.
struct HouseholdSettingsFormState: FormState {
    var slotTimes = SlotTimes.default
    var shoppingWeekday = 5

    var isValid: Bool { (1...7).contains(shoppingWeekday) }

    var settings: HouseholdSettings {
        HouseholdSettings(slotTimes: slotTimes, shoppingWeekday: shoppingWeekday)
    }
}
