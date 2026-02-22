import Foundation
import UIKit

enum ConversionStatus: String {
    case pending
    case converted
    case failed
}

enum ImageFormat: String, CaseIterable, Identifiable {
    case heic = "HEIC"
    case jpeg = "JPEG"
    case png = "PNG"
    case webp = "WEBP"
    case bmp = "BMP"
    case tiff = "TIFF"
    case gif = "GIF"

    var id: String { rawValue }
}

struct ConversionRecord: Identifiable {
    let id: UUID
    let sourceFileName: String
    let sourceFormat: String
    var targetFormat: ImageFormat
    let thumbnail: UIImage?
    var status: ConversionStatus
    let date: Date

    init(
        id: UUID = UUID(),
        sourceFileName: String,
        sourceFormat: String,
        targetFormat: ImageFormat = .jpeg,
        thumbnail: UIImage?,
        status: ConversionStatus = .pending,
        date: Date = Date()
    ) {
        self.id = id
        self.sourceFileName = sourceFileName
        self.sourceFormat = sourceFormat
        self.targetFormat = targetFormat
        self.thumbnail = thumbnail
        self.status = status
        self.date = date
    }
}
