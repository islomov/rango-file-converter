import Foundation
import UIKit
import Combine

enum ConversionStatus: String, Codable {
    case pending
    case converting
    case converted
    case failed
}

final class ConversionRecord: Identifiable, Codable, ObservableObject {
    let id: UUID
    var sourceFileName: String
    var sourceFormat: String
    var targetFormatID: String
    var thumbnailData: Data?
    var statusRaw: String
    var date: Date
    var outputPath: String?
    var errorMessage: String?
    var toolType: String
    var mediaCategory: String
    var progress: Double

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
        toolType: String = "Convert",
        mediaCategory: String = "image"
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
        self.mediaCategory = mediaCategory
        self.progress = 0.0
    }

    // MARK: - Computed Helpers

    var targetFormat: FormatDefinition {
        FormatRegistry.format(forExtension: targetFormatID)
            ?? FormatDefinition(id: targetFormatID, displayName: targetFormatID.uppercased(), fileExtension: targetFormatID, mediaType: .image, mimeType: nil)
    }

    var thumbnail: UIImage? {
        guard let data = thumbnailData else { return nil }
        return UIImage(data: data)
    }

    var outputURL: URL? {
        guard let outputPath else { return nil }
        return Self.documentsDirectory.appendingPathComponent(outputPath)
    }

    var status: ConversionStatus {
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
