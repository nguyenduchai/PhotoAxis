import Foundation
import PhotoAxisCore

/// Request cancellation is thread safe and may precede Vision request creation.
/// The lock protects callbacks only; never hold it while calling Vision/user code.
final class OCRCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var cancelRequest: (@Sendable () -> Void)?
    func install(_ action: @escaping @Sendable () -> Void) {
        lock.lock(); cancelRequest = action; let invoke = cancelled; lock.unlock()
        if invoke { action() }
    }
    func cancel() {
        lock.lock(); cancelled = true; let action = cancelRequest; lock.unlock(); action?()
    }
    func check() throws {
        lock.lock(); let value = cancelled; lock.unlock()
        if value { throw CancellationError() }
    }
}

/// Cancelling releases the caller immediately even if an OS model loader stalls.
/// At most one worker runs; a late result never resumes twice or enters the ledger.
enum OCRExecution {
    private final class State<T: Sendable>: @unchecked Sendable {
        let cancellation = OCRCancellation()
        private let lock = NSLock()
        private var continuation: CheckedContinuation<T, any Error>?
        private var result: Result<T, any Error>?
        func start(_ continuation: CheckedContinuation<T, any Error>) {
            lock.lock()
            if let result { lock.unlock(); continuation.resume(with:result) }
            else { self.continuation = continuation; lock.unlock() }
        }
        func finish(_ result: Result<T, any Error>) {
            lock.lock()
            guard self.result == nil else { lock.unlock(); return }
            self.result = result; let continuation = self.continuation; self.continuation = nil; lock.unlock()
            continuation?.resume(with:result)
        }
        func cancel() { finish(.failure(CancellationError())); cancellation.cancel() }
    }
    private final class Gate: @unchecked Sendable {
        let lock = NSLock()
        var occupied = false
        func enter() -> Bool { lock.lock(); defer { lock.unlock() }; if occupied { return false }; occupied = true; return true }
        func leave() { lock.lock(); occupied = false; lock.unlock() }
    }
    private static let gate = Gate()
    static func run<T: Sendable>(_ operation: @escaping @Sendable (OCRCancellation) throws -> T) async throws -> T {
        try Task.checkCancellation()
        guard gate.enter() else { throw InvestigationError.ocrBusy }
        let state = State<T>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                state.start(continuation)
                Task.detached(priority:.userInitiated) {
                    let result: Result<T, any Error>
                    do { try state.cancellation.check(); result = .success(try operation(state.cancellation)) }
                    catch { result = .failure(error) }
                    gate.leave(); state.finish(result)
                }
            }
        } onCancel: { state.cancel() }
    }
}
