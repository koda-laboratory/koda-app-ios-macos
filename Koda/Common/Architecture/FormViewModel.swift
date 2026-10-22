// MARK: - Form View Model

@MainActor
protocol FormViewModel: MVIViewModel {
    associatedtype Form: FormState

    var form: Form { get set }
}
