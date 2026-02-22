import Foundation
import UIKit

enum ConversionStatus: String {
    case pending
    case converting
    case converted
    case failed
}

struct ConversionRecord: Identifiable {
    let id: UUID
    let sourceFileName: String
    let sourceFormat: String
    var targetFormat: FormatDefinition
    let thumbnail: UIImage?
    var status: ConversionStatus
    let date: Date
    var outputURL: URL?
    var errorMessage: String?

    init(
        id: UUID = UUID(),
        sourceFileName: String,
        sourceFormat: String,
        targetFormat: FormatDefinition,
        thumbnail: UIImage?,
        status: ConversionStatus = .pending,
        date: Date = Date(),
        outputURL: URL? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.sourceFileName = sourceFileName
        self.sourceFormat = sourceFormat
        self.targetFormat = targetFormat
        self.thumbnail = thumbnail
        self.status = status
        self.date = date
        self.outputURL = outputURL
        self.errorMessage = errorMessage
    }
}
