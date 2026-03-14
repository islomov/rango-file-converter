import SwiftUI

private struct CapturedImageItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ImageToPDFView: View {
    let onCreate: ([UIImage]) -> Void

    @State private var items: [CapturedImageItem] = []
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var showAddMoreOptions = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            if items.isEmpty {
                AppColors.background
                    .ignoresSafeArea()
                emptyState
            } else {
                AppColors.surface
                    .ignoresSafeArea()
                listState
            }
        }
        .navigationBarHidden(true)
        .hidesFloatingTabBar()
        .sheet(isPresented: $showCamera) {
            CameraPickerView { image in
                items.append(CapturedImageItem(image: image))
            }
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoLibraryPickerView { images in
                for image in images {
                    items.append(CapturedImageItem(image: image))
                }
            }
        }
        .confirmationDialog("Add More", isPresented: $showAddMoreOptions, titleVisibility: .hidden) {
            Button("Take Photo") { showCamera = true }
            Button("Choose from Library") { showPhotoPicker = true }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 0) {
            emptyNavBar

            Spacer()

            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.textPrimary)

                    VStack(spacing: 8) {
                        Text("Capture images for PDF")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .tracking(-0.408)
                            .multilineTextAlignment(.center)

                        Text("Photos will become pages in order")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .tracking(-0.408)
                            .multilineTextAlignment(.center)
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .tracking(-0.408)
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    colors: [AppColors.accentLight, AppColors.accent, AppColors.accentLight],
                                    startPoint: .topTrailing,
                                    endPoint: .bottomLeading
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    Button {
                        showPhotoPicker = true
                    } label: {
                        Label("Library", systemImage: "photo.on.rectangle")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .tracking(-0.408)
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background(AppColors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding(.horizontal, 16)

            Spacer()
        }
    }

    // MARK: - List State

    private var listState: some View {
        VStack(spacing: 0) {
            header
            fileInfoRow
            pageList
            bottomSection
        }
    }

    // MARK: - Empty Nav Bar

    private var emptyNavBar: some View {
        ZStack {
            Text("Image to PDF")
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

    // MARK: - Header (with items)

    private var header: some View {
        ZStack {
            Text("Image to PDF")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.408)

            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(AppColors.textSecondary.opacity(0.08)))
                }
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 8)
    }

    // MARK: - File Info Row

    private var fileInfoRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 20))
                .foregroundColor(AppColors.textPrimary)
                .frame(width: 28, height: 28)

            Text("scanned_\(items.count)_pages.pdf")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.408)
                .lineLimit(1)

            Spacer()

            Button {
                showAddMoreOptions = true
            } label: {
                Text("Add More")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                    .tracking(-0.408)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColors.textSecondary.opacity(0.12))
                .frame(height: 1)
        }
    }

    // MARK: - Page List

    private var pageList: some View {
        List {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 12) {
                    Image(uiImage: item.image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 52, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 8.32))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Page \(index + 1)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .tracking(-0.408)

                        Text("\(Int(item.image.size.width)) × \(Int(item.image.size.height))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .tracking(-0.408)
                    }

                    Spacer()
                }
                .padding(.vertical, 12)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(AppColors.surface)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(AppColors.textSecondary.opacity(0.12))
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
                .fill(AppColors.shadow.opacity(0.08))
                .frame(height: 1)
        }
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.shadow.opacity(0.08))
                .frame(height: 1)

            VStack(spacing: 0) {
                Button {
                    onCreate(items.map(\.image))
                } label: {
                    Text("Create PDF (\(items.count) pages)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .tracking(-0.408)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(createButtonGradient)
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
    }

    private var createButtonGradient: LinearGradient {
        LinearGradient(
            colors: [AppColors.accentLight, AppColors.accent, AppColors.accentLight],
            startPoint: .topTrailing,
            endPoint: .bottomLeading
        )
    }
}
