import Foundation
import SwiftData
import UIKit

enum ConversionStatus: String {
    case pending
    case converting
    case converted
    case failed
}

@Model
final class ConversionRecord {
    var id: UUID
    var sourceFileName: String
    var sourceFormat: String
    var targetFormatID: String
    @Attribute(.externalStorage) var thumbnailData: Data?
    var statusRaw: String
    var date: Date
    var outputPath: String?
    var errorMessage: String?
    var toolType: String

    init(
        id: UUID = UUID(),
        sourceFileName: String,
        sourceFormat: String,
        targetFormatID: String,
        thumbnailData: Data? = nil,
        status: ConversionStatus = .pending,
        date: Date = Date(),
        outputPath: String? = nil,
        errorMessage: String? = nil,
        toolType: String = "Convert"
    ) {
        self.id = id
        self.sourceFileName = sourceFileName
        self.sourceFormat = sourceFormat
        self.targetFormatID = targetFormatID
        self.thumbnailData = thumbnailData
        self.statusRaw = status.rawValue
        self.date = date
        self.outputPath = outputPath
        self.errorMessage = errorMessage
        self.toolType = toolType
    }

    // MARK: - Computed Helpers

    @Transient var targetFormat: FormatDefinition {
        FormatRegistry.format(forExtension: targetFormatID)
            ?? FormatDefinition(id: targetFormatID, displayName: targetFormatID.uppercased(), fileExtension: targetFormatID, mediaType: .image, mimeType: nil)
    }

    @Transient var thumbnail: UIImage? {
        guard let data = thumbnailData else { return nil }
        return UIImage(data: data)
    }

    @Transient var outputURL: URL? {
        guard let outputPath else { return nil }
        return Self.documentsDirectory.appendingPathComponent(outputPath)
    }

    @Transient var status: ConversionStatus {
        get { ConversionStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    // MARK: - File Persistence

    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func persistOutput(from tempURL: URL) -> String? {
        let dir = documentsDirectory.appendingPathComponent("rango_conversions", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let fileName = tempURL.lastPathComponent
        let destURL = dir.appendingPathComponent(fileName)

        // Remove existing file with same name
        try? FileManager.default.removeItem(at: destURL)

        do {
            try FileManager.default.copyItem(at: tempURL, to: destURL)
            return "rango_conversions/\(fileName)"
        } catch {
            return nil
        }
    }
}
