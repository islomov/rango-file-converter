import Foundation

/// The four media categories supported by Rango.
enum MediaType: String, CaseIterable, Identifiable {
    case image, video, audio, document
    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}

/// A single format definition.
struct FormatDefinition: Identifiable, Hashable {
    let id: String
    let displayName: String
    let fileExtension: String
    let mediaType: MediaType
    let mimeType: String?
}

/// Central registry of all 74 supported formats.
struct FormatRegistry {

    static let allFormats: [FormatDefinition] = imageFormats + videoFormats + audioFormats + documentFormats

    static func formats(for mediaType: MediaType) -> [FormatDefinition] {
        allFormats.filter { $0.mediaType == mediaType }
    }

    static func format(forExtension ext: String) -> FormatDefinition? {
        allFormats.first { $0.fileExtension.caseInsensitiveCompare(ext) == .orderedSame }
    }

    // MARK: - Image (21)

    static let imageFormats: [FormatDefinition] = [
        .init(id: "heic", displayName: "HEIC", fileExtension: "heic", mediaType: .image, mimeType: "image/heic"),
        .init(id: "jpeg", displayName: "JPEG", fileExtension: "jpeg", mediaType: .image, mimeType: "image/jpeg"),
        .init(id: "png", displayName: "PNG", fileExtension: "png", mediaType: .image, mimeType: "image/png"),
        .init(id: "jpg", displayName: "JPG", fileExtension: "jpg", mediaType: .image, mimeType: "image/jpeg"),
        .init(id: "webp", displayName: "WEBP", fileExtension: "webp", mediaType: .image, mimeType: "image/webp"),
        .init(id: "tga", displayName: "TGA", fileExtension: "tga", mediaType: .image, mimeType: "image/x-tga"),
        .init(id: "bmp", displayName: "BMP", fileExtension: "bmp", mediaType: .image, mimeType: "image/bmp"),
        .init(id: "jp2", displayName: "JP2", fileExtension: "jp2", mediaType: .image, mimeType: "image/jp2"),
        .init(id: "gif", displayName: "GIF", fileExtension: "gif", mediaType: .image, mimeType: "image/gif"),
        .init(id: "tiff", displayName: "TIFF", fileExtension: "tiff", mediaType: .image, mimeType: "image/tiff"),
        .init(id: "pbm", displayName: "PBM", fileExtension: "pbm", mediaType: .image, mimeType: "image/x-portable-bitmap"),
        .init(id: "pgm", displayName: "PGM", fileExtension: "pgm", mediaType: .image, mimeType: "image/x-portable-graymap"),
        .init(id: "exr", displayName: "EXR", fileExtension: "exr", mediaType: .image, mimeType: nil),
        .init(id: "pam", displayName: "PAM", fileExtension: "pam", mediaType: .image, mimeType: nil),
        .init(id: "pfm", displayName: "PFM", fileExtension: "pfm", mediaType: .image, mimeType: nil),
        .init(id: "ras", displayName: "RAS", fileExtension: "ras", mediaType: .image, mimeType: nil),
        .init(id: "rgb", displayName: "RGB", fileExtension: "rgb", mediaType: .image, mimeType: nil),
        .init(id: "sgi", displayName: "SGI", fileExtension: "sgi", mediaType: .image, mimeType: nil),
        .init(id: "sunvbm", displayName: "SUNVBM", fileExtension: "ras", mediaType: .image, mimeType: nil),
        .init(id: "xwd", displayName: "XWD", fileExtension: "xwd", mediaType: .image, mimeType: nil),
        .init(id: "yuv", displayName: "YUV", fileExtension: "yuv", mediaType: .image, mimeType: nil),
    ]

    // MARK: - Video (21)

    static let videoFormats: [FormatDefinition] = [
        .init(id: "mp4", displayName: "MP4", fileExtension: "mp4", mediaType: .video, mimeType: "video/mp4"),
        .init(id: "amv", displayName: "AMV", fileExtension: "amv", mediaType: .video, mimeType: nil),
        .init(id: "avi", displayName: "AVI", fileExtension: "avi", mediaType: .video, mimeType: "video/x-msvideo"),
        .init(id: "mov", displayName: "MOV", fileExtension: "mov", mediaType: .video, mimeType: "video/quicktime"),
        .init(id: "mpg", displayName: "MPG", fileExtension: "mpg", mediaType: .video, mimeType: "video/mpeg"),
        .init(id: "m4v", displayName: "M4V", fileExtension: "m4v", mediaType: .video, mimeType: "video/x-m4v"),
        .init(id: "mkv", displayName: "MKV", fileExtension: "mkv", mediaType: .video, mimeType: "video/x-matroska"),
        .init(id: "wmv", displayName: "WMV", fileExtension: "wmv", mediaType: .video, mimeType: "video/x-ms-wmv"),
        .init(id: "flv", displayName: "FLV", fileExtension: "flv", mediaType: .video, mimeType: "video/x-flv"),
        .init(id: "mpeg", displayName: "MPEG", fileExtension: "mpeg", mediaType: .video, mimeType: "video/mpeg"),
        .init(id: "rm", displayName: "RM", fileExtension: "rm", mediaType: .video, mimeType: "application/vnd.rn-realmedia"),
        .init(id: "vob", displayName: "VOB", fileExtension: "vob", mediaType: .video, mimeType: nil),
        .init(id: "ts", displayName: "TS", fileExtension: "ts", mediaType: .video, mimeType: "video/mp2t"),
        .init(id: "webm", displayName: "WEBM", fileExtension: "webm", mediaType: .video, mimeType: "video/webm"),
        .init(id: "asf", displayName: "ASF", fileExtension: "asf", mediaType: .video, mimeType: "video/x-ms-asf"),
        .init(id: "3gp", displayName: "3GP", fileExtension: "3gp", mediaType: .video, mimeType: "video/3gpp"),
        .init(id: "swf", displayName: "SWF", fileExtension: "swf", mediaType: .video, mimeType: "application/x-shockwave-flash"),
        .init(id: "mxf", displayName: "MXF", fileExtension: "mxf", mediaType: .video, mimeType: "application/mxf"),
        .init(id: "f4v", displayName: "F4V", fileExtension: "f4v", mediaType: .video, mimeType: "video/x-f4v"),
        .init(id: "3g2", displayName: "3G2", fileExtension: "3g2", mediaType: .video, mimeType: "video/3gpp2"),
        .init(id: "ogv", displayName: "OGV", fileExtension: "ogv", mediaType: .video, mimeType: "video/ogg"),
    ]

    // MARK: - Audio (25)

    static let audioFormats: [FormatDefinition] = [
        .init(id: "mp3", displayName: "MP3", fileExtension: "mp3", mediaType: .audio, mimeType: "audio/mpeg"),
        .init(id: "wav", displayName: "WAV", fileExtension: "wav", mediaType: .audio, mimeType: "audio/wav"),
        .init(id: "flac", displayName: "FLAC", fileExtension: "flac", mediaType: .audio, mimeType: "audio/flac"),
        .init(id: "m4a", displayName: "M4A", fileExtension: "m4a", mediaType: .audio, mimeType: "audio/mp4"),
        .init(id: "aac", displayName: "AAC", fileExtension: "aac", mediaType: .audio, mimeType: "audio/aac"),
        .init(id: "ogg", displayName: "OGG", fileExtension: "ogg", mediaType: .audio, mimeType: "audio/ogg"),
        .init(id: "ac3", displayName: "AC3", fileExtension: "ac3", mediaType: .audio, mimeType: "audio/ac3"),
        .init(id: "wma", displayName: "WMA", fileExtension: "wma", mediaType: .audio, mimeType: "audio/x-ms-wma"),
        .init(id: "amr", displayName: "AMR", fileExtension: "amr", mediaType: .audio, mimeType: "audio/amr"),
        .init(id: "opus", displayName: "OPUS", fileExtension: "opus", mediaType: .audio, mimeType: "audio/opus"),
        .init(id: "aiff", displayName: "AIFF", fileExtension: "aiff", mediaType: .audio, mimeType: "audio/aiff"),
        .init(id: "mp2", displayName: "MP2", fileExtension: "mp2", mediaType: .audio, mimeType: "audio/mpeg"),
        .init(id: "gsm", displayName: "GSM", fileExtension: "gsm", mediaType: .audio, mimeType: nil),
        .init(id: "dts", displayName: "DTS", fileExtension: "dts", mediaType: .audio, mimeType: "audio/vnd.dts"),
        .init(id: "au", displayName: "AU", fileExtension: "au", mediaType: .audio, mimeType: "audio/basic"),
        .init(id: "caf", displayName: "CAF", fileExtension: "caf", mediaType: .audio, mimeType: "audio/x-caf"),
        .init(id: "wv", displayName: "WV", fileExtension: "wv", mediaType: .audio, mimeType: nil),
        .init(id: "oga", displayName: "OGA", fileExtension: "oga", mediaType: .audio, mimeType: "audio/ogg"),
        .init(id: "w64", displayName: "W64", fileExtension: "w64", mediaType: .audio, mimeType: nil),
        .init(id: "voc", displayName: "VOC", fileExtension: "voc", mediaType: .audio, mimeType: nil),
        .init(id: "snd", displayName: "SND", fileExtension: "snd", mediaType: .audio, mimeType: "audio/basic"),
        .init(id: "spx", displayName: "SPX", fileExtension: "spx", mediaType: .audio, mimeType: "audio/ogg"),
        .init(id: "ircam", displayName: "IRCAM", fileExtension: "ircam", mediaType: .audio, mimeType: nil),
    ]

    // MARK: - Document (7)
    // Note: FFmpeg cannot convert documents. A separate engine is needed.

    static let documentFormats: [FormatDefinition] = [
        .init(id: "doc", displayName: "DOC", fileExtension: "doc", mediaType: .document, mimeType: "application/msword"),
        .init(id: "docx", displayName: "DOCX", fileExtension: "docx", mediaType: .document, mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document"),
        .init(id: "pdf", displayName: "PDF", fileExtension: "pdf", mediaType: .document, mimeType: "application/pdf"),
        .init(id: "html", displayName: "HTML", fileExtension: "html", mediaType: .document, mimeType: "text/html"),
        .init(id: "odt", displayName: "ODT", fileExtension: "odt", mediaType: .document, mimeType: "application/vnd.oasis.opendocument.text"),
        .init(id: "rtf", displayName: "RTF", fileExtension: "rtf", mediaType: .document, mimeType: "application/rtf"),
        .init(id: "txt", displayName: "TXT", fileExtension: "txt", mediaType: .document, mimeType: "text/plain"),
    ]
}
