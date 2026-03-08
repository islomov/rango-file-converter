import SwiftUI
import UniformTypeIdentifiers

private struct MergePDFItem: Identifiable {
    let id = UUID()
    let fileName: String
    let url: URL
}

struct PDFMergeView: View {
    let onMerge: ([URL], [String]) -> Void

    @State private var items: [MergePDFItem] = []
    @State private var showFilePicker = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            if items.isEmpty {
                Color(hex: "F2F2F6")
                    .ignoresSafeArea()
                emptyState
            } else {
                Color.white
                    .ignoresSafeArea()
                fileListState
            }
        }
        .navigationBarHidden(true)
        .hidesFloatingTabBar()
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 0) {
            emptyNavBar

            Spacer()

            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image("icon_doc_merge")
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: 56, height: 56)

                    VStack(spacing: 8) {
                        Text("Add PDF files to merge")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color(hex: "1D1D1D"))
                            .tracking(-0.408)
                            .multilineTextAlignment(.center)

                        Text("Files will be merged in the order shown")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "888888"))
                            .tracking(-0.408)
                            .multilineTextAlignment(.center)
                    }
                }

                Button {
                    showFilePicker = true
                } label: {
                    Text("Add PDFs")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .tracking(-0.408)
                        .padding(16)
                        .frame(width: 180)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "FFAD5B"), Color(hex: "F4800D"), Color(hex: "FFAD5B")],
                                startPoint: .topTrailing,
                                endPoint: .bottomLeading
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal, 16)

            Spacer()
        }
    }

    // MARK: - File List State

    private var fileListState: some View {
        VStack(spacing: 0) {
            header

            // File info row
            fileInfoRow

            // Page list
            pageList

            bottomSection
        }
    }

    // MARK: - Empty State Nav Bar

    private var emptyNavBar: some View {
        ZStack {
            Text("Merge PDF")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1D"))
                .tracking(-0.408)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image("icon_arrow_left")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 24, height: 24)
                        .foregroundColor(Color(hex: "1D1D1D"))
                        .frame(width: 40, height: 40)
                }
                Spacer()
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 8)
    }

    // MARK: - Header (with files)

    private var header: some View {
        ZStack {
            Text("Merge PDF")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1D"))
                .tracking(-0.408)

            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "1D1D1D"))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color(hex: "888888").opacity(0.08)))
                }
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 8)
    }

    // MARK: - File Info Row

    private var fileInfoRow: some View {
        HStack(spacing: 12) {
            Image("icon_doc_merge")
                .resizable()
                .renderingMode(.template)
                .foregroundColor(Color(hex: "1D1D1D"))
                .frame(width: 28, height: 28)

            Text(mergedFileName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1D"))
                .tracking(-0.408)
                .lineLimit(1)

            Spacer()

            Button {
                showFilePicker = true
            } label: {
                Text("Change")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "F4800D"))
                    .tracking(-0.408)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(hex: "888888").opacity(0.12))
                .frame(height: 1)
        }
    }

    private var mergedFileName: String {
        if items.count == 1 {
            return items[0].fileName
        } else if items.count > 1 {
            let baseName = items[0].fileName.replacingOccurrences(of: ".pdf", with: "", options: .caseInsensitive)
            return "\(baseName)_merged.pdf"
        }
        return "merged.pdf"
    }

    // MARK: - Page List

    private var pageList: some View {
        List {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8.32)
                        .fill(Color(hex: "E6E6EC"))
                        .frame(width: 52, height: 56)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Page \(index + 1)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "1D1D1D"))
                            .tracking(-0.408)

                        Text(item.fileName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "888888"))
                            .tracking(-0.408)
                            .lineLimit(1)
                    }

                    Spacer()
                }
                .padding(.vertical, 12)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowSeparator(.hidden)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color(hex: "888888").opacity(0.12))
                        .frame(height: 1)
                }
            }
            .onMove { from, to in
                items.move(fromOffsets: from, toOffset: to)
            }
            .onDelete { offsets in
                items.remove(atOffsets: offsets)
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(hex: "565656").opacity(0.08))
                .frame(height: 1)
        }
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(hex: "565656").opacity(0.08))
                .frame(height: 1)

            VStack(spacing: 0) {
                Button {
                    onMerge(items.map(\.url), items.map(\.fileName))
                } label: {
                    Text("Merge \(items.count) PDFs")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .tracking(-0.408)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(mergeButtonGradient)
                        )
                }
                .disabled(items.count < 2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
    }

    private var mergeButtonGradient: LinearGradient {
        if items.count < 2 {
            return LinearGradient(
                colors: [Color(hex: "FFD9B8"), Color(hex: "F8C192"), Color(hex: "FFD9B8")],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        } else {
            return LinearGradient(
                colors: [Color(hex: "FFAD5B"), Color(hex: "F4800D"), Color(hex: "FFAD5B")],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
    }

    // MARK: - File Import

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        for sourceURL in urls {
            guard sourceURL.startAccessingSecurityScopedResource() else { continue }
            defer { sourceURL.stopAccessingSecurityScopedResource() }

            let fileName = sourceURL.lastPathComponent
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("rango_pdf_merge", isDirectory: true)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            let shortID = UUID().uuidString.prefix(8)
            let destURL = tempDir.appendingPathComponent("\(shortID)_\(fileName)")
            try? FileManager.default.removeItem(at: destURL)

            if let _ = try? FileManager.default.copyItem(at: sourceURL, to: destURL) {
                items.append(MergePDFItem(fileName: fileName, url: destURL))
            }
        }
    }
}
