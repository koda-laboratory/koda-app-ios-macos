@propertyWrapper
struct Inject<Value: Sendable>: Sendable {
    let wrappedValue: Value

    init(name: String? = nil) {
        self.wrappedValue = DependencyContainer.shared.required(Value.self, name: name)
    }

    init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }
}
