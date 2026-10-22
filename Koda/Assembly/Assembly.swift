import Swinject

extension Resolver {
    func required<Service>(
        _ serviceType: Service.Type = Service.self,
        name: String? = nil
    ) -> Service {
        guard let service = resolve(serviceType, name: name) else {
            fatalError(
                "Missing Swinject registration for \(String(reflecting: serviceType))"
                    + (name.map { " named '\($0)'" } ?? "")
                    + "."
            )
        }
        return service
    }
}

@MainActor
enum Assembly {
    nonisolated static let supabaseHeaderProviderName = "supabase"
}
