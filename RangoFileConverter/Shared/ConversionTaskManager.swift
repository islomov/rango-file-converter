import Foundation

/// Stores running Task handles keyed by ConversionRecord.id.
/// Allows cancellation from history UI and cleanup on completion.
final class ConversionTaskManager {
    static let shared = ConversionTaskManager()

    private var tasks: [UUID: Task<Void, Never>] = [:]
    private let lock = NSLock()

    private init() {}

    /// Register a running task for a record.
    func register(id: UUID, task: Task<Void, Never>) {
        lock.lock()
        defer { lock.unlock() }
        tasks[id] = task
    }

    /// Cancel and remove a task by record ID.
    func cancel(id: UUID) {
        lock.lock()
        let task = tasks.removeValue(forKey: id)
        lock.unlock()
        task?.cancel()
    }

    /// Remove a completed task (called at end of conversion).
    func remove(id: UUID) {
        lock.lock()
        tasks.removeValue(forKey: id)
        lock.unlock()
    }
}
