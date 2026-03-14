import SwiftUI
import UIKit
import Combine
import AppTrackingTransparency

final class DocumentConverterViewModel: ObservableObject {
    // Format conversion state
    @Published var selectedFileName: String = ""
    @Published var selectedFileURL: URL?
    @Published var showConversionDetail = false
    @Published var navigateToHistoryTrigger = 0

    // PDF Merge state
    @Published var showMergeView = false
    @Published var mergeFileURLs: [URL] = []
    @Published var mergeFileNames: [String] = []

    // PDF Split state
    @Published var showSplitView = false
    @Published var splitFileURL: URL?
    @Published var splitFileName: String = ""

    // PDF Reorder state
    @Published var showReorderView = false
    @Published var reorderFileURL: URL?
    @Published var reorderFileName: String = ""

    // PDF Protect state
    @Published var showProtectView = false
    @Published var protectFileURL: URL?
    @Published var protectFileName: String = ""

    private let coordinator = ConversionCoordinator()
    private let store = HistoryStore.shared
    private let taskManager = ConversionTaskManager.shared

    // MARK: - Format Conversion

    func selectDocument(fileName: String, fileURL: URL) {
        selectedFileName = fileName
        selectedFileURL = fileURL
        showConversionDetail = true
    }

    func convert(inputURL: URL, fileName: String, to format: FormatDefinition) {
        let sourceExt = fileName.components(separatedBy: ".").last?.uppercased() ?? "UNKNOWN"

        let record = ConversionRecord(
            sourceFileName: fileName,
            sourceFormat: sourceExt,
            targetFormatID: format.id,
            thumbnailData: nil,
            status: .converting,
            toolType: ToolType.convert.rawValue,
            mediaCategory: "document"
        )

        let coordinator = self.coordinator
        let task = Task.detached { [weak self] in
            guard let self else { return }
            defer { self.taskManager.remove(id: record.id) }

            await AdTrackingManager.shared.ensureTrackingRequested()
            await MainActor.run {
                self.store.add(record)
                self.navigateToHistoryTrigger += 1
            }

            do {
                guard !Task.isCancelled else {
                    await MainActor.run { self.failRecord(record, error: "Cancelled") }
                    return
                }

                let job = ConversionJob(inputURL: inputURL, outputFormat: format)
                let result = try await coordinator.convert(job: job)

                guard !Task.isCancelled else {
                    await MainActor.run { self.failRecord(record, error: "Cancelled") }
                    return
                }

                let outputPath = ConversionRecord.persistOutput(from: result.outputURL)
                await MainActor.run {
                    record.progress = 1.0
                    record.status = .converted
                    record.outputPath = outputPath
                    self.store.save()
                }
            } catch {
                await MainActor.run {
                    record.status = .failed
                    record.errorMessage = error.localizedDescription
                    self.store.save()
                }
            }
        }

        taskManager.register(id: record.id, task: task)
    }

    // MARK: - PDF Merge

    func mergePDFs(fileURLs: [URL], fileNames: [String]) {
        let nameList = fileNames.joined(separator: ", ")
        let record = ConversionRecord(
            sourceFileName: nameList,
            sourceFormat: "PDF",
            targetFormatID: "pdf",
            thumbnailData: nil,
            status: .converting,
            toolType: ToolType.mergePDF.rawValue,
            mediaCategory: "document"
        )

        let task = Task.detached { [weak self] in
            guard let self else { return }
            defer { self.taskManager.remove(id: record.id) }

            await AdTrackingManager.shared.ensureTrackingRequested()
            await MainActor.run {
                self.store.add(record)
                self.navigateToHistoryTrigger += 1
            }

            do {
                let outputURL = try PDFToolsService.merge(pdfURLs: fileURLs)
                let outputPath = ConversionRecord.persistOutput(from: outputURL)
                await MainActor.run {
                    record.progress = 1.0
                    record.status = .converted
                    record.outputPath = outputPath
                    self.store.save()
                }
            } catch {
                await MainActor.run {
                    record.status = .failed
                    record.errorMessage = error.localizedDescription
                    self.store.save()
                }
            }
        }

        taskManager.register(id: record.id, task: task)
    }

    // MARK: - PDF Split

    func splitPDF(inputURL: URL, fileName: String, pages: [Int]) {
        let record = ConversionRecord(
            sourceFileName: fileName,
            sourceFormat: "PDF",
            targetFormatID: "pdf",
            thumbnailData: nil,
            status: .converting,
            toolType: ToolType.splitPDF.rawValue,
            mediaCategory: "document"
        )

        let task = Task.detached { [weak self] in
            guard let self else { return }
            defer { self.taskManager.remove(id: record.id) }

            await AdTrackingManager.shared.ensureTrackingRequested()
            await MainActor.run {
                self.store.add(record)
                self.navigateToHistoryTrigger += 1
            }

            do {
                let outputURL = try PDFToolsService.split(pdfURL: inputURL, pages: pages)
                let outputPath = ConversionRecord.persistOutput(from: outputURL)
                await MainActor.run {
                    record.progress = 1.0
                    record.status = .converted
                    record.outputPath = outputPath
                    self.store.save()
                }
            } catch {
                await MainActor.run {
                    record.status = .failed
                    record.errorMessage = error.localizedDescription
                    self.store.save()
                }
            }
        }

        taskManager.register(id: record.id, task: task)
    }

    // MARK: - PDF Reorder

    func reorderPDF(inputURL: URL, fileName: String, pageOrder: [Int]) {
        let record = ConversionRecord(
            sourceFileName: fileName,
            sourceFormat: "PDF",
            targetFormatID: "pdf",
            thumbnailData: nil,
            status: .converting,
            toolType: ToolType.reorderPDF.rawValue,
            mediaCategory: "document"
        )

        let task = Task.detached { [weak self] in
            guard let self else { return }
            defer { self.taskManager.remove(id: record.id) }

            await AdTrackingManager.shared.ensureTrackingRequested()
            await MainActor.run {
                self.store.add(record)
                self.navigateToHistoryTrigger += 1
            }

            do {
                let outputURL = try PDFToolsService.reorder(pdfURL: inputURL, pageOrder: pageOrder)
                let outputPath = ConversionRecord.persistOutput(from: outputURL)
                await MainActor.run {
                    record.progress = 1.0
                    record.status = .converted
                    record.outputPath = outputPath
                    self.store.save()
                }
            } catch {
                await MainActor.run {
                    record.status = .failed
                    record.errorMessage = error.localizedDescription
                    self.store.save()
                }
            }
        }

        taskManager.register(id: record.id, task: task)
    }

    // MARK: - PDF Protect

    func protectPDF(inputURL: URL, fileName: String, password: String) {
        let record = ConversionRecord(
            sourceFileName: fileName,
            sourceFormat: "PDF",
            targetFormatID: "pdf",
            thumbnailData: nil,
            status: .converting,
            toolType: ToolType.protectPDF.rawValue,
            mediaCategory: "document"
        )

        let task = Task.detached { [weak self] in
            guard let self else { return }
            defer { self.taskManager.remove(id: record.id) }

            await AdTrackingManager.shared.ensureTrackingRequested()
            await MainActor.run {
                self.store.add(record)
                self.navigateToHistoryTrigger += 1
            }

            do {
                let outputURL = try PDFToolsService.protect(pdfURL: inputURL, password: password)
                let outputPath = ConversionRecord.persistOutput(from: outputURL)
                await MainActor.run {
                    record.progress = 1.0
                    record.status = .converted
                    record.outputPath = outputPath
                    self.store.save()
                }
            } catch {
                await MainActor.run {
                    record.status = .failed
                    record.errorMessage = error.localizedDescription
                    self.store.save()
                }
            }
        }

        taskManager.register(id: record.id, task: task)
    }

    // MARK: - Image to PDF

    func createPDFFromImages(images: [UIImage]) {
        let record = ConversionRecord(
            sourceFileName: "Scanned_\(images.count)_pages.pdf",
            sourceFormat: "IMG",
            targetFormatID: "pdf",
            thumbnailData: nil,
            status: .converting,
            toolType: ToolType.imageToPDF.rawValue,
            mediaCategory: "document"
        )

        let task = Task.detached { [weak self] in
            guard let self else { return }
            defer { self.taskManager.remove(id: record.id) }

            await AdTrackingManager.shared.ensureTrackingRequested()
            await MainActor.run {
                self.store.add(record)
                self.navigateToHistoryTrigger += 1
            }

            do {
                let outputURL = try PDFToolsService.createFromImages(images)
                let outputPath = ConversionRecord.persistOutput(from: outputURL)
                await MainActor.run {
                    record.progress = 1.0
                    record.status = .converted
                    record.outputPath = outputPath
                    self.store.save()
                }
            } catch {
                await MainActor.run {
                    record.status = .failed
                    record.errorMessage = error.localizedDescription
                    self.store.save()
                }
            }
        }

        taskManager.register(id: record.id, task: task)
    }

    // MARK: - Private

    private func failRecord(_ record: ConversionRecord, error: String) {
        record.status = .failed
        record.errorMessage = error
        store.save()
    }
}
