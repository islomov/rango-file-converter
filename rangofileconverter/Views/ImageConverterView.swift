import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ImageConverterView: View {
    @State private var viewModel = ImageConverterViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                pickSection
                historySection
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $viewModel.showConversionDetail) {
                if let image = viewModel.selectedImage {
                    ImageDetailView(
                        image: image,
                        fileName: viewModel.selectedFileName
                    ) { format in
                        await viewModel.convert(to: format)
                    }
                }
            }
            .fileImporter(
                isPresented: $viewModel.showFilePicker,
                allowedContentTypes: [UTType.image],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        viewModel.handleFileImport(result: .success(url))
                    }
                case .failure(let error):
                    viewModel.handleFileImport(result: .failure(error))
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Image")
                .font(.title.bold())
            Spacer()
            Button {
                // TODO: open settings
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var pickSection: some View {
        HStack(spacing: 12) {
            PhotosPicker(
                selection: $viewModel.selectedPhotoItem,
                matching: .images
            ) {
                pickButton(title: "Photo Library", icon: "photo.on.rectangle")
            }

            Button {
                viewModel.showFilePicker = true
            } label: {
                pickButton(title: "Files", icon: "folder")
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private func pickButton(title: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
            Text(title)
                .font(.subheadline.weight(.medium))
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var historySection: some View {
        if viewModel.history.isEmpty {
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
                ForEach(viewModel.history) { record in
                    HistoryRowView(record: record)
                }
            }
            .listStyle(.plain)
        }
    }
}

#Preview {
    ImageConverterView()
}
