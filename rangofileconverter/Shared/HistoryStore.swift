import Foundation
import Combine

/// Replaces SwiftData ModelContainer/ModelContext with simple JSON persistence.
/// Shared singleton accessible from views and view models.
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var records: [ConversionRecord] = []

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("conversion_history.json")
        load()
    }

    // MARK: - Filtered Access

    func records(for mediaCategory: String) -> [ConversionRecord] {
        records.filter { $0.mediaCategory == mediaCategory }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Mutations

    func add(_ record: ConversionRecord) {
        records.insert(record, at: 0)
        save()
    }

    func remove(_ record: ConversionRecord) {
        if let outputURL = record.outputURL {
            try? FileManager.default.removeItem(at: outputURL)
        }
        records.removeAll { $0.id == record.id }
        save()
    }

    func save() {
        objectWillChange.send()
        do {
            let data = try encoder.encode(records)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[HistoryStore] Save failed: \(error)")
        }
    }

    // MARK: - Private

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            records = try decoder.decode([ConversionRecord].self, from: data)
            print("[HistoryStore] Loaded \(records.count) records")
        } catch {
            print("[HistoryStore] Load failed: \(error)")
            records = []
        }
    }
}
