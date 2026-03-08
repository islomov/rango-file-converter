import SwiftUI

private enum DocumentTab: String, CaseIterable {
    case tools = "Tools"
    case history = "History"
}

private struct DocumentTool: Identifiable, Hashable {
    let id: String
    let title: LocalizedStringKey
    let icon: String
    let isAvailable: Bool

    // Hashable conformance for LocalizedStringKey
    static func == (lhs: DocumentTool, rhs: DocumentTool) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private let documentTools: [DocumentTool] = [
    DocumentTool(id: "convert", title: "Convert", icon: "icon_doc_convert", isAvailable: true),
    DocumentTool(id: "merge", title: "Merge PDF", icon: "icon_doc_merge", isAvailable: true),
    DocumentTool(id: "split", title: "Split PDF", icon: "icon_doc_split", isAvailable: true),
    DocumentTool(id: "reorder", title: "Reorder pages", icon: "icon_doc_reorder", isAvailable: true),
    DocumentTool(id: "protect", title: "Protect PDF", icon: "icon_doc_protect", isAvailable: true),
]

struct DocumentConverterView: View {
    var onBack: (() -> Void)?
    var onNavigateToHistory: (() -> Void)?

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
            ZStack {
                AppColors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    switch selectedTab {
                    case .tools:
                        toolsSection
                    case .history:
                        historySection
                    }
                }
            }
            .navigationBarHidden(true)
            // Format conversion flow
            .navigationDestination(isPresented: $showDocumentPicker) {
                DocumentPickerView(config: .convert) { fileName, url in
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
                        onNavigateToHistory?()
                    }
                }
            }
            // PDF Merge
            .navigationDestination(isPresented: $showMergeView) {
                PDFMergeView { urls, names in
                    viewModel.mergePDFs(fileURLs: urls, fileNames: names)
                    showMergeView = false
                    selectedTab = .history
                    onNavigateToHistory?()
                }
            }
            // PDF Split
            .navigationDestination(isPresented: $showSplitView) {
                PDFSplitView { url, name, pages in
                    viewModel.splitPDF(inputURL: url, fileName: name, pages: pages)
                    showSplitView = false
                    selectedTab = .history
                    onNavigateToHistory?()
                }
            }
            // PDF Reorder
            .navigationDestination(isPresented: $showReorderView) {
                PDFReorderView { url, name, order in
                    viewModel.reorderPDF(inputURL: url, fileName: name, pageOrder: order)
                    showReorderView = false
                    selectedTab = .history
                    onNavigateToHistory?()
                }
            }
            // PDF Protect
            .navigationDestination(isPresented: $showProtectView) {
                PDFProtectView { url, name, password in
                    viewModel.protectPDF(inputURL: url, fileName: name, password: password)
                    showProtectView = false
                    selectedTab = .history
                    onNavigateToHistory?()
                }
            }
        }
    }

    private var header: some View {
        ZStack {
            Text("Document")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            HStack {
                Button {
                    onBack?()
                } label: {
                    Image("icon_arrow_left")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 24, height: 24)
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 40, height: 40)
                }
                Spacer()
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 8)
    }


    private var toolsSection: some View {
        ScrollView {
            let twoColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

            LazyVGrid(columns: twoColumns, spacing: 12) {
                ForEach(documentTools) { tool in
                    Button {
                        handleToolTap(tool)
                    } label: {
                        toolCard(tool)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
    }

    private func toolCard(_ tool: DocumentTool) -> some View {
        VStack(spacing: 8) {
            Image(tool.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)

            Text(tool.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.408)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 106)
        .background(AppColors.surface)
        .cornerRadius(16)
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
