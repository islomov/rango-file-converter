import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ImageConverterView()
                .tabItem {
                    Label("Image", systemImage: "photo")
                }

            VideoConverterView()
                .tabItem {
                    Label("Video", systemImage: "video")
                }

            AudioConverterView()
                .tabItem {
                    Label("Audio", systemImage: "music.note")
                }

            DocumentConverterView()
                .tabItem {
                    Label("Document", systemImage: "doc.text")
                }
        }
    }
}

#Preview {
    ContentView()
}
