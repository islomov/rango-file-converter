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

    private static let maxRecords = 500

    // MARK: - Mutations

    func add(_ record: ConversionRecord) {
        records.insert(record, at: 0)
        pruneIfNeeded()
        save()
    }

    private func pruneIfNeeded() {
        guard records.count > Self.maxRecords else { return }
        let overflow = records[Self.maxRecords...]
        for record in overflow {
            if let outputURL = record.outputURL {
                try? FileManager.default.removeItem(at: outputURL)
            }
        }
        records.removeSubrange(Self.maxRecords...)
    }

    func remove(_ record: ConversionRecord) {
        ConversionTaskManager.shared.cancel(id: record.id)
        if let outputURL = record.outputURL {
            try? FileManager.default.removeItem(at: outputURL)
        }
        records.removeAll { $0.id == record.id }
        save()
    }

    func removeAll(for mediaCategory: String? = nil) {
        let toRemove = mediaCategory.map { records(for: $0) } ?? records
        for record in toRemove {
            ConversionTaskManager.shared.cancel(id: record.id)
            if let outputURL = record.outputURL {
                try? FileManager.default.removeItem(at: outputURL)
            }
        }
        if let mediaCategory {
            records.removeAll { $0.mediaCategory == mediaCategory }
        } else {
            records.removeAll()
        }
        save()
    }

    // MARK: - Storage Info

    private var conversionsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("rango_conversions", isDirectory: true)
    }

    func totalStorageBytes() -> Int64 {
        directorySize(at: conversionsDirectory)
    }

    func storageBytes(for mediaCategory: String) -> Int64 {
        let fm = FileManager.default
        let categoryRecords = records(for: mediaCategory)
        var total: Int64 = 0
        for record in categoryRecords {
            guard let url = record.outputURL else { continue }
            if let attrs = try? fm.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        return total
    }

    private func directorySize(at url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    private let saveQueue = DispatchQueue(label: "com.rango.historystore.save", qos: .utility)

    func save() {
        objectWillChange.send()
        let snapshot = records
        let encoder = self.encoder
        let url = self.fileURL
        saveQueue.async {
            do {
                let data = try encoder.encode(snapshot)
                try data.write(to: url, options: .atomic)
            } catch {
                print("[HistoryStore] Save failed: \(error)")
            }
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
