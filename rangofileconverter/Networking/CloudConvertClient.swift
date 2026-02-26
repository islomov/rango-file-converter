import Foundation
import os.log

private let logger = Logger(subsystem: "com.rango.cloudconvert", category: "client")

struct CloudConvertClient {
    private static let baseURL = "https://api.cloudconvert.com/v2"
    private static let pollInterval: TimeInterval = 2
    private static let maxPollAttempts = 150 // 5 minutes at 2s intervals

    // MARK: - Public API

    /// Creates a conversion job and returns the job response with task details.
    func createJob(inputFormat: String, outputFormat: String, apiKey: String) async throws -> CloudConvertJobResponse {
        let requestBody = CloudConvertJobRequest(inputFormat: inputFormat, outputFormat: outputFormat)
        let url = URL(string: "\(Self.baseURL)/jobs")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTPResponse(response, data: data)
        return try JSONDecoder().decode(CloudConvertJobResponse.self, from: data)
    }

    /// Uploads a file to the import task's upload URL using multipart form data.
    func uploadFile(form: CloudConvertJobResponse.UploadForm, fileURL: URL, apiKey: String) async throws {
        guard let uploadURL = URL(string: form.url) else {
            throw CloudConvertError.uploadFailed("Invalid upload URL")
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add form parameters (must come before the file field)
        for (key, value) in form.parameters {
            body.appendMultipartField(name: key, value: value.stringValue, boundary: boundary)
        }

        // Add file field (must be last)
        let fileData = try Data(contentsOf: fileURL)
        let fileName = fileURL.lastPathComponent
        let mimeType = mimeType(for: fileURL.pathExtension)
        body.appendMultipartFile(name: "file", fileName: fileName, mimeType: mimeType, data: fileData, boundary: boundary)

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (uploadData, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let body = String(data: uploadData, encoding: .utf8) ?? "(no body)"
            logger.error("Upload HTTP \(httpResponse.statusCode): \(body.prefix(500))")
            throw CloudConvertError.uploadFailed("HTTP \(httpResponse.statusCode)")
        }
    }

    /// Polls the job status until it finishes or errors out.
    func waitForJob(id: String, apiKey: String) async throws -> CloudConvertJobResponse {
        let url = URL(string: "\(Self.baseURL)/jobs/\(id)")!

        for _ in 0..<Self.maxPollAttempts {
            try await Task.sleep(nanoseconds: UInt64(Self.pollInterval * 1_000_000_000))

            if Task.isCancelled { throw CancellationError() }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            try checkHTTPResponse(response, data: data)

            let jobResponse = try JSONDecoder().decode(CloudConvertJobResponse.self, from: data)

            switch jobResponse.data.status {
            case "finished":
                return jobResponse
            case "error":
                let errorMessage = jobResponse.data.tasks
                    .first(where: { $0.status == "error" })?.message ?? "Unknown error"
                throw CloudConvertError.conversionFailed(errorMessage)
            default:
                continue // still processing
            }
        }

        throw CloudConvertError.timeout
    }

    /// Downloads the converted file from the export task's result URL.
    func downloadResult(from remoteURL: URL, to localURL: URL) async throws {
        let (tempURL, response) = try await URLSession.shared.download(from: remoteURL)

        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw CloudConvertError.downloadFailed
        }

        try? FileManager.default.removeItem(at: localURL)
        try FileManager.default.moveItem(at: tempURL, to: localURL)
    }

    // MARK: - Helpers

    private func checkHTTPResponse(_ response: URLResponse, data: Data? = nil) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        switch httpResponse.statusCode {
        case 200...299:
            return
        default:
            if let data, let body = String(data: data, encoding: .utf8) {
                logger.error("HTTP \(httpResponse.statusCode) response: \(body.prefix(500))")
            } else {
                logger.error("HTTP \(httpResponse.statusCode) (no body)")
            }
        }
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401, 403:
            throw CloudConvertError.noAPIKey
        case 429:
            throw CloudConvertError.rateLimitExceeded
        case 500...599:
            throw CloudConvertError.serverError(httpResponse.statusCode)
        default:
            throw CloudConvertError.serverError(httpResponse.statusCode)
        }
    }

    private func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "pdf": return "application/pdf"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "html": return "text/html"
        case "rtf": return "application/rtf"
        case "odt": return "application/vnd.oasis.opendocument.text"
        case "txt": return "text/plain"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - Data Multipart Helpers

private extension Data {
    mutating func appendMultipartField(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }

    mutating func appendMultipartFile(name: String, fileName: String, mimeType: String, data: Data, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}
