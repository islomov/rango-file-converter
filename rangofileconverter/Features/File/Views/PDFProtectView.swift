import SwiftUI
import UniformTypeIdentifiers

struct PDFProtectView: View {
    let onProtect: (URL, String, String) -> Void

    @State private var fileURL: URL?
    @State private var fileName: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showFilePicker = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if fileURL == nil {
                    Spacer(minLength: 80)
                    VStack(spacing: 12) {
                        Image(systemName: "lock.doc")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Select a PDF to protect")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showFilePicker = true
                    } label: {
                        Label("Choose PDF", systemImage: "folder")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 40)
                } else {
                    // File info
                    HStack {
                        Image(systemName: "doc.richtext")
                            .font(.title2)
                            .foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(fileName)
                                .font(.headline)
                        }
                        Spacer()
                        Button {
                            showFilePicker = true
                        } label: {
                            Text("Change")
                                .font(.subheadline)
                        }
                    }
                    .padding()
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

                    // Password fields
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Set Password")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)

                        SecureField("Confirm Password", text: $confirmPassword)
                            .textFieldStyle(.roundedBorder)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    // Protect button
                    Button {
                        performProtect()
                    } label: {
                        Text("Protect PDF")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(password.isEmpty || confirmPassword.isEmpty)
                }
            }
            .padding(20)
        }
        .navigationTitle("Protect PDF")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let sourceURL = urls.first else { return }
        guard sourceURL.startAccessingSecurityScopedResource() else { return }
        defer { sourceURL.stopAccessingSecurityScopedResource() }

        let name = sourceURL.lastPathComponent
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_pdf_protect", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let destURL = tempDir.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: destURL)

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            fileURL = destURL
            fileName = name
            errorMessage = nil
            password = ""
            confirmPassword = ""
        } catch {
            // Copy failed
        }
    }

    private func performProtect() {
        errorMessage = nil

        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }

        guard password.count >= 4 else {
            errorMessage = "Password must be at least 4 characters."
            return
        }

        guard let url = fileURL else { return }
        onProtect(url, fileName, password)
    }
}
