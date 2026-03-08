import Foundation
import Combine

/// Replaces SwiftData ModelContainer/ModelContext with simple JSON persistence.
/// Shared singleton accessible from views and view models.
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var records: [ConversionRecord] = []

    /// Cached storage sizes updated asynchronously to avoid main-thread file I/O.
    @Published private(set) var cachedTotalStorageBytes: Int64 = 0
    @Published private(set) var cachedCategoryStorageBytes: [String: Int64] = [:]

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let ioQueue = DispatchQueue(label: "com.rango.historystore.io", qos: .utility)

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
        let overflow = Array(records[Self.maxRecords...])
        records.removeSubrange(Self.maxRecords...)
        // Delete files off the main thread
        ioQueue.async {
            for record in overflow {
                if let outputURL = record.outputURL {
                    try? FileManager.default.removeItem(at: outputURL)
                }
            }
        }
    }

    func remove(_ record: ConversionRecord) {
        ConversionTaskManager.shared.cancel(id: record.id)
        let outputURL = record.outputURL
        records.removeAll { $0.id == record.id }
        save()
        // Delete file off the main thread
        if let outputURL {
            ioQueue.async {
                try? FileManager.default.removeItem(at: outputURL)
            }
        }
    }

    func removeAll(for mediaCategory: String? = nil) {
        let toRemove = mediaCategory.map { records(for: $0) } ?? records
        let urlsToDelete = toRemove.compactMap { record -> URL? in
            ConversionTaskManager.shared.cancel(id: record.id)
            return record.outputURL
        }
        if let mediaCategory {
            records.removeAll { $0.mediaCategory == mediaCategory }
        } else {
            records.removeAll()
        }
        save()
        // Delete files off the main thread
        ioQueue.async {
            for url in urlsToDelete {
                try? FileManager.default.removeItem(at: url)
            }
        }
        refreshStorageSizes()
    }

    // MARK: - Storage Info

    private var conversionsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("rango_conversions", isDirectory: true)
    }

    /// Recalculates storage sizes on a background queue and publishes results on main thread.
    func refreshStorageSizes() {
        let convDir = conversionsDirectory
        let currentRecords = records
        ioQueue.async { [weak self] in
            guard let self else { return }
            let total = self.directorySize(at: convDir)
            let categories = ["image", "video", "audio", "document"]
            var categoryBytes: [String: Int64] = [:]
            let fm = FileManager.default
            for category in categories {
                let catRecords = currentRecords.filter { $0.mediaCategory == category }
                    .sorted { $0.date > $1.date }
                var catTotal: Int64 = 0
                for record in catRecords {
                    guard let url = record.outputURL else { continue }
                    if let attrs = try? fm.attributesOfItem(atPath: url.path),
                       let size = attrs[.size] as? Int64 {
                        catTotal += size
                    }
                }
                categoryBytes[category] = catTotal
            }
            DispatchQueue.main.async {
                self.cachedTotalStorageBytes = total
                self.cachedCategoryStorageBytes = categoryBytes
            }
        }
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

    func save() {
        objectWillChange.send()
        let snapshot = records
        let encoder = self.encoder
        let url = self.fileURL
        ioQueue.async {
            do {
                let data = try encoder.encode(snapshot)
                try data.write(to: url, options: .atomic)
            } catch {
                print("[HistoryStore] Save failed: \(error)")
            }
        }
    }

    // MARK: - Private

    /// Loads history synchronously at init so records are available immediately.
    /// The JSON file is small (metadata + tiny thumbnails, max 500 records) so this is fast.
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
