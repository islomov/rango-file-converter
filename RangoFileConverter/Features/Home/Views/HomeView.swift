import SwiftUI

struct HomeView: View {
    var onCategorySelected: ((MediaCategory) -> Void)?
    var onProTapped: (() -> Void)?
    @State private var cardsAppeared = false
    @State private var showSubscription = false
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Home")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                if subscriptionManager.isProUser {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColors.accent)

                        Text("PRO")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColors.accent)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppColors.accent)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppColors.accent.opacity(0.12))
                    .cornerRadius(22)
                } else {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if let onProTapped {
                            onProTapped()
                        } else {
                            showSubscription = true
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)

                            Text("PRO")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [AppColors.accentLight, AppColors.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(22)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 16)

            // "Select service" label
            Text("Select service")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .opacity(cardsAppeared ? 1 : 0.5)
                .offset(y: cardsAppeared ? 0 : 30)
                .animation(.easeOut(duration: 0.3), value: cardsAppeared)

            // Stacked cards — responsive with capped max size
            GeometryReader { geo in
                // Visible gap between cards, capped so cards don't get too big
                let gap = min(geo.size.height / 4.8, 118.0)
                let lastCardHeight = gap * 1.2
                // Each overlapping card extends one gap behind the next card
                let cardHeight = gap * 2

                let offset2 = gap
                let offset3 = gap * 2
                let offset4 = gap * 3
                let totalHeight = offset4 + lastCardHeight

                ScrollView(.vertical, showsIndicators: false) {
                    ZStack(alignment: .top) {
                        ServiceCard(
                            title: "Image",
                            iconName: "icon_gallery",
                            arrowName: "icon_arrow_white",
                            backgroundColor: AppColors.cardImage,
                            foregroundColor: AppColors.cardImageForeground,
                            height: cardHeight,
                            topCornerRadius: 32
                        ) {
                            onCategorySelected?(.image)
                        }
                        .zIndex(1)

                        ServiceCard(
                            title: "Video",
                            iconName: "icon_video",
                            arrowName: "icon_arrow_dark",
                            backgroundColor: AppColors.cardVideo,
                            foregroundColor: AppColors.cardVideoForeground,
                            height: cardHeight,
                            topCornerRadius: 32
                        ) {
                            onCategorySelected?(.video)
                        }
                        .offset(y: offset2)
                        .zIndex(2)

                        ServiceCard(
                            title: "Audio",
                            iconName: "icon_musicnote",
                            arrowName: "icon_arrow_dark",
                            backgroundColor: AppColors.cardAudio,
                            foregroundColor: AppColors.cardDarkText,
                            height: cardHeight,
                            topCornerRadius: 32,
                            hasBottomRadius: true
                        ) {
                            onCategorySelected?(.audio)
                        }
                        .offset(y: offset3)
                        .zIndex(3)

                        ServiceCard(
                            title: "Documents",
                            iconName: "icon_document",
                            arrowName: "icon_arrow_dark",
                            backgroundColor: AppColors.cardDocument,
                            foregroundColor: AppColors.cardDarkText,
                            height: lastCardHeight,
                            topCornerRadius: 32,
                            hasBottomRadius: true
                        ) {
                            onCategorySelected?(.document)
                        }
                        .offset(y: offset4)
                        .zIndex(4)
                    }
                    .frame(height: totalHeight, alignment: .top)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .opacity(cardsAppeared ? 1 : 0.5)
            .offset(y: cardsAppeared ? 0 : 30)
            .animation(.easeOut(duration: 0.3), value: cardsAppeared)
        }
        .background(AppColors.background)
        .onAppear {
            if !cardsAppeared {
                cardsAppeared = true
            }
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
    }
}

// MARK: - Service Card

private struct ServiceCard: View {
    let title: LocalizedStringKey
    var iconName: String?
    var systemIconName: String?
    let arrowName: String
    var backgroundColor: Color?
    var backgroundGradient: LinearGradient?
    let foregroundColor: Color
    let height: CGFloat
    let topCornerRadius: CGFloat
    var hasBottomRadius: Bool = false
    var action: () -> Void

    @State private var isPressed = false

    var body: some View {
        VStack {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    if let iconName = iconName {
                        Image(iconName)
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 32, height: 32)
                            .foregroundColor(foregroundColor)
                    } else if let systemIconName = systemIconName {
                        Image(systemName: systemIconName)
                            .font(.system(size: 24, weight: .bold))
                            .frame(width: 32, height: 32)
                            .foregroundColor(foregroundColor)
                    }

                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(foregroundColor)
                }

                Spacer()

                Image(arrowName)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(foregroundColor)
                    .frame(width: 24, height: 24)
                    .flipsForRightToLeftLayoutDirection(true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background {
            if let backgroundGradient = backgroundGradient {
                backgroundGradient
            } else if let backgroundColor = backgroundColor {
                backgroundColor
            }
        }
        .clipShape(CardShape(topRadius: topCornerRadius, bottomRadius: hasBottomRadius ? topCornerRadius : 0))
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Card Shape

private struct CardShape: Shape {
    let topRadius: CGFloat
    let bottomRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let tl = topRadius
        let tr = topRadius
        let bl = bottomRadius
        let br = bottomRadius

        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),
                    radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        if br > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
                        radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        if bl > 0 {
            path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl),
                        radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl),
                    radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)

        return path
    }
}

// MARK: - Media Category

enum MediaCategory: String, CaseIterable {
    case image
    case video
    case audio
    case document
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
