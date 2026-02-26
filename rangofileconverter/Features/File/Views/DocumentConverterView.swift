import SwiftUI

private enum DocumentTab: String, CaseIterable {
    case tools = "Tools"
    case history = "History"
}

private struct DocumentTool: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let isAvailable: Bool
}

private let documentTools: [DocumentTool] = [
    DocumentTool(id: "convert", title: "Format Conversion", icon: "arrow.triangle.2.circlepath", isAvailable: true),
    DocumentTool(id: "merge", title: "Merge PDFs", icon: "doc.on.doc", isAvailable: true),
    DocumentTool(id: "split", title: "Split PDF", icon: "scissors", isAvailable: true),
    DocumentTool(id: "reorder", title: "Reorder Pages", icon: "arrow.up.arrow.down", isAvailable: true),
    DocumentTool(id: "protect", title: "Protect PDF", icon: "lock.doc", isAvailable: true),
]

struct DocumentConverterView: View {
    @StateObject private var viewModel = DocumentConverterViewModel()
    @EnvironmentObject private var historyStore: HistoryStore
    @State private var selectedTab: DocumentTab = .tools
    @State private var showDocumentPicker = false
    @State private var showMergeView = false
    @State private var showSplitView = false
    @State private var showReorderView = false
    @State private var showProtectView = false
    @State private var showSettings = false
    @State private var selectedRecord: ConversionRecord?

    private var history: [ConversionRecord] {
        historyStore.records(for: "document")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                tabPicker

                switch selectedTab {
                case .tools:
                    toolsSection
                case .history:
                    historySection
                }
            }
            .navigationBarHidden(true)
            // Format conversion flow
            .navigationDestination(isPresented: $showDocumentPicker) {
                DocumentPickerView { fileName, url in
                    viewModel.selectDocument(fileName: fileName, fileURL: url)
                }
            }
            .navigationDestination(isPresented: $viewModel.showConversionDetail) {
                if let fileURL = viewModel.selectedFileURL {
                    DocumentDetailView(
                        fileName: viewModel.selectedFileName,
                        fileURL: fileURL
                    ) { format in
                        viewModel.convert(
                            inputURL: fileURL,
                            fileName: viewModel.selectedFileName,
                            to: format
                        )
                        viewModel.showConversionDetail = false
                        showDocumentPicker = false
                        selectedTab = .history
                    }
                }
            }
            // PDF Merge
            .navigationDestination(isPresented: $showMergeView) {
                PDFMergeView { urls, names in
                    viewModel.mergePDFs(fileURLs: urls, fileNames: names)
                    showMergeView = false
                    selectedTab = .history
                }
            }
            // PDF Split
            .navigationDestination(isPresented: $showSplitView) {
                PDFSplitView { url, name, pages in
                    viewModel.splitPDF(inputURL: url, fileName: name, pages: pages)
                    showSplitView = false
                    selectedTab = .history
                }
            }
            // PDF Reorder
            .navigationDestination(isPresented: $showReorderView) {
                PDFReorderView { url, name, order in
                    viewModel.reorderPDF(inputURL: url, fileName: name, pageOrder: order)
                    showReorderView = false
                    selectedTab = .history
                }
            }
            // PDF Protect
            .navigationDestination(isPresented: $showProtectView) {
                PDFProtectView { url, name, password in
                    viewModel.protectPDF(inputURL: url, fileName: name, password: password)
                    showProtectView = false
                    selectedTab = .history
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Document")
                .font(.title.bold())
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundStyle(.primary)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(historyStore)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var tabPicker: some View {
        Picker("", selection: $selectedTab) {
            ForEach(DocumentTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private var toolsSection: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(documentTools) { tool in
                    Button {
                        handleToolTap(tool)
                    } label: {
                        toolCard(tool)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func toolCard(_ tool: DocumentTool) -> some View {
        VStack(spacing: 10) {
            Image(systemName: tool.icon)
                .font(.title2)
            Text(tool.title)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(tool.isAvailable ? .primary : .secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topTrailing) {
            if !tool.isAvailable {
                Text("Soon")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary, in: Capsule())
                    .padding(8)
            }
        }
    }

    private func handleToolTap(_ tool: DocumentTool) {
        switch tool.id {
        case "convert":
            showDocumentPicker = true
        case "merge":
            showMergeView = true
        case "split":
            showSplitView = true
        case "reorder":
            showReorderView = true
        case "protect":
            showProtectView = true
        default:
            break
        }
    }

    @ViewBuilder
    private var historySection: some View {
        if history.isEmpty {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
                Text("No conversions yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        } else {
            List {
                ForEach(history) { record in
                    Button {
                        selectedRecord = record
                    } label: {
                        HistoryRowView(record: record)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .sheet(item: $selectedRecord) { record in
                HistoryResultSheet(record: record)
                    .environmentObject(historyStore)
            }
        }
    }
}

#Preview {
    DocumentConverterView()
        .environmentObject(HistoryStore.shared)
}
