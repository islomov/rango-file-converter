import SwiftUI

struct DocumentConverterView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Spacer()
                Text("Document Converter")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .navigationBarHidden(true)
        }
    }

    private var header: some View {
        HStack {
            Text("Document")
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
}

#Preview {
    DocumentConverterView()
}
