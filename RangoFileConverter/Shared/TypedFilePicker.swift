import SwiftUI
import UniformTypeIdentifiers

/// A modifier that presents `UIDocumentPickerViewController` directly from UIKit,
/// bypassing SwiftUI's `.fileImporter` which can fail to apply content-type filters.
struct TypedFilePickerModifier: ViewModifier {
    @Binding var isPresented: Bool
    let allowedContentTypes: [UTType]
    let allowsMultipleSelection: Bool
    let onResult: (Result<[URL], Error>) -> Void

    func body(content: Content) -> some View {
        content
            .background(
                TypedFilePickerBridge(
                    isPresented: $isPresented,
                    allowedContentTypes: allowedContentTypes,
                    allowsMultipleSelection: allowsMultipleSelection,
                    onResult: onResult
                )
                .frame(width: 0, height: 0)
            )
    }
}

extension View {
    func typedFilePicker(
        isPresented: Binding<Bool>,
        allowedContentTypes: [UTType],
        allowsMultipleSelection: Bool = false,
        onResult: @escaping (Result<[URL], Error>) -> Void
    ) -> some View {
        modifier(TypedFilePickerModifier(
            isPresented: isPresented,
            allowedContentTypes: allowedContentTypes,
            allowsMultipleSelection: allowsMultipleSelection,
            onResult: onResult
        ))
    }
}

// MARK: - UIKit Bridge

private struct TypedFilePickerBridge: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let allowedContentTypes: [UTType]
    let allowsMultipleSelection: Bool
    let onResult: (Result<[URL], Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        if isPresented && controller.presentedViewController == nil {
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes)
            picker.allowsMultipleSelection = allowsMultipleSelection
            picker.shouldShowFileExtensions = true
            picker.delegate = context.coordinator
            controller.present(picker, animated: true)
        }
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: TypedFilePickerBridge

        init(parent: TypedFilePickerBridge) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.isPresented = false
            parent.onResult(.success(urls))
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.isPresented = false
        }
    }
}
