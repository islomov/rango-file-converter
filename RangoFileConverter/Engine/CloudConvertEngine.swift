import Foundation
import os.log

private let logger = Logger(subsystem: "com.rango.cloudconvert", category: "engine")

/// Converts document formats via the CloudConvert REST API.
final class CloudConvertEngine: ConversionEngine {
    let supportedMediaTypes: Set<MediaType> = [.document]

    private static let documentExtensions: Set<String> = [
        "doc", "docx", "pdf", "html", "odt", "rtf", "txt"
    ]

    private let client = CloudConvertClient()

    func canConvert(from inputExtension: String, to outputFormat: FormatDefinition) -> Bool {
        guard outputFormat.mediaType == .document else { return false }
        let inputExt = inputExtension.lowercased()
        let outputExt = outputFormat.fileExtension.lowercased()
        return Self.documentExtensions.contains(inputExt)
            && Self.documentExtensions.contains(outputExt)
            && inputExt != outputExt
    }

    func convert(job: ConversionJob) async throws -> ConversionResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        guard let apiKey = CloudConvertAPIKey.apiKey() else {
            logger.error("No API key configured")
            throw CloudConvertError.noAPIKey
        }

        let inputExt = job.inputURL.pathExtension.lowercased()
        let outputExt = job.outputFormat.fileExtension.lowercased()
        logger.info("Starting conversion: \(inputExt) → \(outputExt), file: \(job.inputURL.lastPathComponent)")

        // Check connectivity
        do {
            try await checkConnectivity()
            logger.info("Connectivity check passed")
        } catch {
            logger.error("Connectivity check failed: \(error.localizedDescription)")
            throw error
        }

        // 1. Create job
        logger.info("Creating CloudConvert job...")
        let jobResponse: CloudConvertJobResponse
        do {
            jobResponse = try await client.createJob(
                inputFormat: inputExt,
                outputFormat: outputExt,
                apiKey: apiKey
            )
            logger.info("Job created: id=\(jobResponse.data.id), status=\(jobResponse.data.status), tasks=\(jobResponse.data.tasks.count)")
            for task in jobResponse.data.tasks {
                logger.info("  Task: name=\(task.name), op=\(task.operation), status=\(task.status), hasForm=\(task.result?.form != nil)")
            }
        } catch {
            logger.error("Create job failed: \(error.localizedDescription)")
            throw error
        }

        // 2. Find import task and get upload form
        guard let importTask = jobResponse.data.tasks.first(where: { $0.operation == "import/upload" }),
              let form = importTask.result?.form else {
            let taskOps = jobResponse.data.tasks.map { "\($0.name)(\($0.operation), status=\($0.status))" }.joined(separator: ", ")
            logger.error("No upload form found. Tasks: \(taskOps)")
            throw CloudConvertError.uploadFailed("No upload form in response")
        }
        logger.info("Upload form URL: \(form.url), params: \(form.parameters.keys.joined(separator: ", "))")

        // 3. Upload file
        logger.info("Uploading file (\(job.inputURL.lastPathComponent))...")
        do {
            try await client.uploadFile(form: form, fileURL: job.inputURL, apiKey: apiKey)
            logger.info("Upload complete")
        } catch {
            logger.error("Upload failed: \(error.localizedDescription)")
            throw error
        }

        // 4. Wait for completion
        logger.info("Polling for job completion...")
        let finishedJob: CloudConvertJobResponse
        do {
            finishedJob = try await client.waitForJob(id: jobResponse.data.id, apiKey: apiKey)
            logger.info("Job finished: status=\(finishedJob.data.status)")
            for task in finishedJob.data.tasks {
                logger.info("  Task: name=\(task.name), status=\(task.status), files=\(task.result?.files?.count ?? 0)")
            }
        } catch {
            logger.error("Wait failed: \(error.localizedDescription)")
            throw error
        }

        // 5. Find export task and download result
        guard let exportTask = finishedJob.data.tasks.first(where: { $0.operation == "export/url" }),
              let fileResult = exportTask.result?.files?.first,
              let downloadURLString = fileResult.url,
              let downloadURL = URL(string: downloadURLString) else {
            let exportInfo = finishedJob.data.tasks.first(where: { $0.operation == "export/url" })
            logger.error("No download URL. Export task status=\(exportInfo?.status ?? "nil"), files=\(exportInfo?.result?.files?.count ?? 0)")
            throw CloudConvertError.downloadFailed
        }
        logger.info("Downloading from: \(downloadURLString)")

        // 6. Download to temp directory
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_conversions", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let baseName = job.inputURL.deletingPathExtension().lastPathComponent
        let shortID = UUID().uuidString.prefix(8)
        let outputURL = tempDir.appendingPathComponent("\(baseName)_\(shortID).\(outputExt)")

        do {
            try await client.downloadResult(from: downloadURL, to: outputURL)
            logger.info("Download complete: \(outputURL.lastPathComponent)")
        } catch {
            logger.error("Download failed: \(error.localizedDescription)")
            throw error
        }

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0
        logger.info("Conversion done in \(String(format: "%.1f", duration))s, size=\(fileSize) bytes")

        return ConversionResult(job: job, outputURL: outputURL, duration: duration, outputFileSize: fileSize)
    }

    // MARK: - Private

    private func checkConnectivity() async throws {
        guard let url = URL(string: "https://api.cloudconvert.com/v2") else {
            throw CloudConvertError.offline
        }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 500 {
                throw CloudConvertError.serverError(http.statusCode)
            }
        } catch is CloudConvertError {
            throw CloudConvertError.offline
        } catch {
            throw CloudConvertError.offline
        }
    }
}
