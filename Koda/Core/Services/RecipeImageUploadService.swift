import Foundation

/// Uploads the recipe and product photos taken on this device to their Storage bucket whenever there is a connection: observes the local queue and
/// the network, uploads one image at a time and backs off after a failure. The rows that reference the images sync
/// through the outbox independently.
protocol RecipeImageUploadService: Sendable {
    func start() async
    /// Sign-out: stops uploading and deletes the images on disk (the queue goes with the database).
    func stopAndClear() async
}

actor RecipeImageUploadServiceImpl: RecipeImageUploadService {
    private let repository: any RecipeImageRepository
    private let reachability: any NetworkReachabilityMonitoring
    private let loggerService: any LoggerService
    private let sleep: @Sendable (Duration) async throws -> Void

    private var tasks: [Task<Void, Never>] = []
    private var pending: [PendingImageUpload] = []
    private var isOnline = true
    private var worker: Task<Void, Never>?

    init(
        repository: any RecipeImageRepository,
        reachability: any NetworkReachabilityMonitoring,
        loggerService: any LoggerService,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.repository = repository
        self.reachability = reachability
        self.loggerService = loggerService
        self.sleep = sleep
    }

    func start() async {
        guard tasks.isEmpty else {
            // Returning to the foreground retries what failed before.
            drain()
            return
        }
        let uploads = repository.observePendingUploads()
        let network = reachability.updates()
        tasks = [
            Task { [weak self] in
                for await value in uploads { await self?.pendingChanged(value) }
            },
            Task { [weak self] in
                for await online in network { await self?.networkChanged(online) }
            },
        ]
    }

    func stopAndClear() async {
        tasks.forEach { $0.cancel() }
        tasks = []
        worker?.cancel()
        worker = nil
        pending = []
        repository.removeAllLocalImages()
    }

    // MARK: - Private Methods

    private func pendingChanged(_ value: [PendingImageUpload]) {
        pending = value
        drain()
    }

    private func networkChanged(_ online: Bool) {
        isOnline = online
        if online { drain() }
    }

    /// Single worker: uploads the queue in order until it is empty or offline, waiting after each failure.
    private func drain() {
        guard worker == nil, isOnline, !pending.isEmpty else { return }
        worker = Task { [weak self] in
            await self?.runQueue()
        }
    }

    private func runQueue() async {
        defer { worker = nil }
        while isOnline, let next = pending.first, !Task.isCancelled {
            do {
                try await repository.upload(path: next.path)
                pending.removeAll { $0.path == next.path }
            } catch {
                guard error.type != .apiRequestCancelled else { return }
                loggerService.warning(
                    "An image upload failed.",
                    attributes: ["error.type": error.type.rawValue, "bucket": next.bucket.rawValue]
                )
                await repository.recordUploadFailure(path: next.path, error: error)
                // Wait before the next try (30 s, 60 s, … up to 10 min).
                let delay = min(30 * (next.attempts + 1), 600)
                do {
                    try await sleep(.seconds(delay))
                } catch {
                    return
                }
            }
        }
    }
}
