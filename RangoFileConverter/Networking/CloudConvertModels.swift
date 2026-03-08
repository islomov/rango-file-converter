import Foundation

// MARK: - Errors

enum CloudConvertError: LocalizedError {
    case noAPIKey
    case offline
    case uploadFailed(String)
    case conversionFailed(String)
    case downloadFailed
    case rateLimitExceeded
    case serverError(Int)
    case timeout

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "Please add your CloudConvert API key in Settings."
        case .offline:
            return "Document conversion requires an internet connection."
        case .uploadFailed(let detail):
            return "Upload failed: \(detail)"
        case .conversionFailed(let detail):
            return "Conversion failed: \(detail)"
        case .downloadFailed:
            return "Failed to download the converted file."
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .serverError(let code):
            return "CloudConvert service error (\(code)). Please try again."
        case .timeout:
            return "Conversion timed out. Please try again with a smaller file."
        }
    }
}

// MARK: - Request Models

struct CloudConvertJobRequest: Encodable {
    let tasks: [String: TaskDefinition]
    let tag: String?

    init(inputFormat: String, outputFormat: String, tag: String? = nil) {
        self.tasks = [
            "import-file": TaskDefinition(operation: "import/upload"),
            "convert-file": TaskDefinition(
                operation: "convert",
                input: ["import-file"],
                inputFormat: inputFormat,
                outputFormat: outputFormat
            ),
            "export-file": TaskDefinition(
                operation: "export/url",
                input: ["convert-file"]
            ),
        ]
        self.tag = tag
    }

    struct TaskDefinition: Encodable {
        let operation: String
        var input: [String]?
        var inputFormat: String?
        var outputFormat: String?

        enum CodingKeys: String, CodingKey {
            case operation, input
            case inputFormat = "input_format"
            case outputFormat = "output_format"
        }
    }
}

// MARK: - Response Models

struct CloudConvertJobResponse: Decodable {
    let data: JobData

    struct JobData: Decodable {
        let id: String
        let status: String
        let tasks: [TaskData]
    }

    struct TaskData: Decodable {
        let id: String
        let name: String
        let operation: String
        let status: String
        let message: String?
        let result: TaskResult?
    }

    struct TaskResult: Decodable {
        let form: UploadForm?
        let files: [ResultFile]?
    }

    struct UploadForm: Decodable {
        let url: String
        let parameters: [String: AnyCodable]
    }

    struct ResultFile: Decodable {
        let filename: String?
        let url: String?
    }
}

/// Type-erased Codable wrapper for dynamic form parameters.
struct AnyCodable: Decodable, Encodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        } else if let stringVal = try? container.decode(String.self) {
            value = stringVal
        } else if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intVal = value as? Int {
            try container.encode(intVal)
        } else if let doubleVal = value as? Double {
            try container.encode(doubleVal)
        } else if let stringVal = value as? String {
            try container.encode(stringVal)
        } else if let boolVal = value as? Bool {
            try container.encode(boolVal)
        }
    }

    var stringValue: String {
        switch value {
        case let s as String: return s
        case let i as Int: return String(i)
        case let d as Double: return String(d)
        case let b as Bool: return String(b)
        default: return ""
        }
    }
}
