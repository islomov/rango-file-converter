import SwiftUI

struct RateAppPrompt {
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    static let allPrompts: [RateAppPrompt] = [
        RateAppPrompt(
            title: "Loving Media Converter?",
            message: "Your files converted perfectly! If Media Converter helps you convert images, videos, and documents, a quick rating would mean a lot."
        ),
        RateAppPrompt(
            title: "Enjoying Media Converter?",
            message: "You've successfully converted your files! Help others discover the best format converter for HEIC, PDF, MP4, and 70+ formats — rate us on the App Store."
        ),
        RateAppPrompt(
            title: "You're on a roll!",
            message: "If Media Converter makes file converting easy, share the love with a quick review. It helps other users find the best converter app."
        ),
        RateAppPrompt(
            title: "How's Your Experience?",
            message: "Media Converter has converted your images, videos, and audio seamlessly. Tap to rate and help us become the top file converter on the App Store!"
        ),
        RateAppPrompt(
            title: "Media Converter Made It Easy!",
            message: "Converting HEIC to JPG, MP4 to MP3, or PDF to Word — all done on your device. Love it? Leave a quick review!"
        ),
        RateAppPrompt(
            title: "Help Us Grow!",
            message: "Media Converter supports 70+ file formats — images, videos, audio, and documents. A 5-star rating helps others discover the ultimate converter app."
        ),
        RateAppPrompt(
            title: "One Tap to Support Us",
            message: "Your review helps millions find the best free file converter for photos, videos, and documents. Rate Media Converter on the App Store!"
        ),
    ]

    static func random() -> RateAppPrompt {
        allPrompts.randomElement() ?? allPrompts[0]
    }
}
    }
}
