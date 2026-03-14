import Foundation
import UIKit
import Combine

enum ConversionStatus: String, Codable {
    case pending
    case converting
    case converted
    case failed
}

enum ToolType: String, Codable, CaseIterable {
    case convert = "Convert"
    case compress = "Compress"
    case rotate = "Rotate"
    case resize = "Resize"
    case crop = "Crop"
    case stitch = "Stitch"
    case gif = "GIF"
    case merge = "Merge"
    case speed = "Speed"
    case timeClip = "Time Clip"
    case extractAudio = "Extract Audio"
    case ratio = "Ratio"
    case mergePDF = "Merge PDF"
    case splitPDF = "Split PDF"
    case reorderPDF = "Reorder PDF"
    case protectPDF = "Protect PDF"
    case imageToPDF = "Image to PDF"
}

final class ConversionRecord: Identifiable, Codable, ObservableObject {
    let id: UUID
    var sourceFileName: String
    var sourceFormat: String
    var targetFormatID: String
    var thumbnailData: Data?
    var statusRaw: String {
        willSet {
            objectWillChange.send()
            let newStatus = ConversionStatus(rawValue: newValue)
            if newStatus == .converted || newStatus == .failed {
                completedDate = Date()
            }
        }
    }
    var date: Date
    var completedDate: Date?
    var outputPath: String? { willSet { objectWillChange.send() } }
    var errorMessage: String?
    var toolType: String
    var mediaCategory: String
    var progress: Double { willSet { objectWillChange.send() } }

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
        toolType: String = ToolType.convert.rawValue,
        mediaCategory: String = "image"
    ) {
        self.id = id
        self.sourceFileName = sourceFileName
        self.sourceFormat = sourceFormat
        self.targetFormatID = targetFormatID
        self.thumbnailData = thumbnailData
        self.statusRaw = status.rawValue
        self.date = date
        self.completedDate = (status == .converted || status == .failed) ? date : nil
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

    private var _cachedThumbnail: UIImage?
    private var _thumbnailDataHash: Int?

    var thumbnail: UIImage? {
        guard let data = thumbnailData else { return nil }
        let hash = data.hashValue
        if let cached = _cachedThumbnail, _thumbnailDataHash == hash {
            return cached
        }
        let image = UIImage(data: data)
        _cachedThumbnail = image
        _thumbnailDataHash = hash
        return image
    }

    // Exclude cache from Codable
    private enum CodingKeys: String, CodingKey {
        case id, sourceFileName, sourceFormat, targetFormatID, thumbnailData
        case statusRaw, date, completedDate, outputPath, errorMessage, toolType, mediaCategory, progress
    }

    var outputURL: URL? {
        guard let outputPath else { return nil }
        return Self.documentsDirectory.appendingPathComponent(outputPath)
    }

    var status: ConversionStatus {
        get { ConversionStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var tool: ToolType {
        ToolType(rawValue: toolType) ?? .convert
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
