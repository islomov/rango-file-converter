import SwiftUI
import Combine

struct SettingsView: View {
    @EnvironmentObject private var historyStore: HistoryStore
    @Environment(\.dismiss) private var dismiss
    @State private var storageInfo = StorageInfo()
    @State private var showDeleteAll = false
    @State private var deleteCategoryTarget: String?
    @State private var cloudConvertKey: String = ""
    @State private var showAPIKeySaved = false

    var body: some View {
        NavigationStack {
            List {
                cloudConvertSection
                storageSection
                clearDataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                refreshStorage()
                cloudConvertKey = CloudConvertAPIKey.apiKey() ?? ""
            }
            .alert("API Key Saved", isPresented: $showAPIKeySaved) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your CloudConvert API key has been saved securely.")
            }
            .alert("Delete All History", isPresented: $showDeleteAll) {
                Button("Delete All", role: .destructive) {
                    historyStore.removeAll()
                    refreshStorage()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all converted files and history. This action cannot be undone.")
            }
            .alert(
                "Delete \(deleteCategoryTitle) History",
                isPresented: Binding(
                    get: { deleteCategoryTarget != nil },
                    set: { if !$0 { deleteCategoryTarget = nil } }
                )
            ) {
                Button("Delete", role: .destructive) {
                    if let category = deleteCategoryTarget {
                        historyStore.removeAll(for: category)
                        refreshStorage()
                    }
                }
                Button("Cancel", role: .cancel) { deleteCategoryTarget = nil }
            } message: {
                Text("This will permanently delete all \(deleteCategoryTitle.lowercased()) files and history.")
            }
        }
    }

    private var deleteCategoryTitle: String {
        deleteCategoryTarget?.capitalized ?? ""
    }

    // MARK: - CloudConvert Section

    private var cloudConvertSection: some View {
        Section {
            SecureField("API Key", text: $cloudConvertKey)
                .textContentType(.password)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            Button {
                let trimmed = cloudConvertKey.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty {
                    CloudConvertAPIKey.deleteAPIKey()
                } else {
                    CloudConvertAPIKey.setAPIKey(trimmed)
                }
                showAPIKeySaved = true
            } label: {
                Text("Save API Key")
            }
            .disabled(cloudConvertKey.trimmingCharacters(in: .whitespaces) == (CloudConvertAPIKey.apiKey() ?? ""))
        } header: {
            Text("Document Conversion")
        } footer: {
            Text("Required for document format conversion. Get your free API key at cloudconvert.com.")
        }
    }

    // MARK: - Storage Section

    private var storageSection: some View {
        Section {
            HStack {
                Label("Total Storage", systemImage: "internaldrive")
                Spacer()
                Text(formatBytes(storageInfo.total))
                    .foregroundStyle(.secondary)
            }

            ForEach(storageCategories, id: \.category) { item in
                HStack {
                    Label(item.label, systemImage: item.icon)
                    Spacer()
                    Text(formatBytes(item.bytes))
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Storage")
        } footer: {
            Text("Converted files are stored locally on your device in the app's Documents folder.")
        }
    }

    // MARK: - Clear Data Section

    private var clearDataSection: some View {
        Section {
            ForEach(storageCategories, id: \.category) { item in
                if item.count > 0 {
                    Button(role: .destructive) {
                        deleteCategoryTarget = item.category
                    } label: {
                        HStack {
                            Label("Delete \(item.label)", systemImage: "trash")
                            Spacer()
                            Text("\(item.count) files")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if historyStore.records.count > 0 {
                Button(role: .destructive) {
                    showDeleteAll = true
                } label: {
                    HStack {
                        Label("Delete All History", systemImage: "trash.fill")
                        Spacer()
                        Text("\(historyStore.records.count) files")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Clear Data")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Build")
                Spacer()
                Text(buildNumber)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private struct CategoryInfo {
        let category: String
        let label: String
        let icon: String
        let bytes: Int64
        let count: Int
    }

    private var storageCategories: [CategoryInfo] {
        [
            CategoryInfo(
                category: "image", label: "Image", icon: "photo",
                bytes: storageInfo.image,
                count: historyStore.records(for: "image").count
            ),
            CategoryInfo(
                category: "video", label: "Video", icon: "video",
                bytes: storageInfo.video,
                count: historyStore.records(for: "video").count
            ),
            CategoryInfo(
                category: "audio", label: "Audio", icon: "music.note",
                bytes: storageInfo.audio,
                count: historyStore.records(for: "audio").count
            ),
            CategoryInfo(
                category: "document", label: "Document", icon: "doc.text",
                bytes: storageInfo.document,
                count: historyStore.records(for: "document").count
            ),
        ]
    }

    private struct StorageInfo {
        var total: Int64 = 0
        var image: Int64 = 0
        var video: Int64 = 0
        var audio: Int64 = 0
        var document: Int64 = 0
    }

    private func refreshStorage() {
        storageInfo = StorageInfo(
            total: historyStore.totalStorageBytes(),
            image: historyStore.storageBytes(for: "image"),
            video: historyStore.storageBytes(for: "video"),
            audio: historyStore.storageBytes(for: "audio"),
            document: historyStore.storageBytes(for: "document")
        )
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

#Preview {
    SettingsView()
        .environmentObject(HistoryStore.shared)
}
