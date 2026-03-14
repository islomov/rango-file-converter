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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            if fileURL == nil {
                emptyState
            } else {
                detailState
            }
        }
        .navigationBarHidden(true)
        .hidesFloatingTabBar()
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                emptyNavBar

                Spacer()

                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Image("icon_doc_protect")
                            .resizable()
                            .renderingMode(.original)
                            .frame(width: 56, height: 56)

                        Text("Select a PDF to protect")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .tracking(-0.408)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        showFilePicker = true
                    } label: {
                        Text("Choose PDF")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .tracking(-0.408)
                            .padding(16)
                            .frame(width: 180)
                            .background(
                                LinearGradient(
                                    colors: [AppColors.accentLight, AppColors.accent, AppColors.accentLight],
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
    }

    // MARK: - Detail State

    private var detailState: some View {
        VStack(spacing: 0) {
            detailNavBar

            VStack(spacing: 0) {
                // File info row with bottom border
                HStack(spacing: 12) {
                    Image("icon_doc_protect")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 28, height: 28)

                    Text(fileName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .tracking(-0.408)
                        .lineLimit(1)

                    Spacer()

                    Button {
                        showFilePicker = true
                    } label: {
                        Text("Change")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.accent)
                            .tracking(-0.408)
                    }
                }
                .padding(.vertical, 16)
                .overlay(
                    Rectangle()
                        .fill(AppColors.textSecondary.opacity(0.12))
                        .frame(height: 1),
                    alignment: .bottom
                )

                // Password fields
                VStack(alignment: .leading, spacing: 12) {
                    Text("Set password")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(-0.408)

                    SecureField("Password", text: $password)
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(-0.408)
                        .padding(.horizontal, 16)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.textSecondary.opacity(0.08))
                        )

                    SecureField("Confirm password", text: $confirmPassword)
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(-0.408)
                        .padding(.horizontal, 16)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.textSecondary.opacity(0.08))
                        )
                }
                .padding(.top, 24)

                if let errorMessage {
                    Text(LocalizedStringKey(errorMessage))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.destructive)
                        .tracking(-0.408)
                        .padding(.top, 8)
                }

                Spacer()
            }
            .padding(.horizontal, 16)

            // Protect button
            Button {
                performProtect()
            } label: {
                Text("Protect PDF")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .tracking(-0.408)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(protectButtonGradient)
                    )
            }
            .disabled(password.isEmpty || confirmPassword.isEmpty)
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
    }

    // MARK: - Navigation Bars

    private var emptyNavBar: some View {
        ZStack {
            Text("Protect PDF")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.408)

            HStack {
                Button {
                    dismiss()
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

    private var detailNavBar: some View {
        ZStack {
            Text("Protect PDF")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.408)

            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(AppColors.textSecondary.opacity(0.08)))
                }
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 8)
    }

    private var protectButtonGradient: LinearGradient {
        let isDisabled = password.isEmpty || confirmPassword.isEmpty
        if isDisabled {
            return LinearGradient(
                colors: [AppColors.buttonDisabledStart, AppColors.buttonDisabledMid, AppColors.buttonDisabledStart],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        } else {
            return LinearGradient(
                colors: [AppColors.accentLight, AppColors.accent, AppColors.accentLight],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
    }

    // MARK: - File Import

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
