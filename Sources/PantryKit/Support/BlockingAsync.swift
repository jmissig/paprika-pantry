import Dispatch

enum BlockingAsync {
    static func run<Value: Sendable>(
        _ operation: @escaping @Sendable () async throws -> Value
    ) throws -> Value {
        let semaphore = DispatchSemaphore(value: 0)
        let box = AsyncResultBox<Value>()

        Task {
            do {
                box.result = .success(try await operation())
            } catch {
                box.result = .failure(error)
            }

            semaphore.signal()
        }

        semaphore.wait()
        return try box.result!.get()
    }
}

private final class AsyncResultBox<Value>: @unchecked Sendable {
    var result: Result<Value, Error>?
}
