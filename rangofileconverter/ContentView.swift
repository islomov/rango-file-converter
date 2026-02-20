import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Image", systemImage: "photo") {
                ImageConverterView()
            }

            Tab("Video", systemImage: "video") {
                VideoConverterView()
            }

            Tab("Audio", systemImage: "music.note") {
                AudioConverterView()
            }

            Tab("Document", systemImage: "doc.text") {
                DocumentConverterView()
            }
        }
    }
}

#Preview {
    ContentView()
}
