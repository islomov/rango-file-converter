import SwiftUI

struct RangeSliderView: View {
    @Binding var lowerValue: Double
    @Binding var upperValue: Double
    let bounds: ClosedRange<Double>
    var accentColor: Color = AppColors.accent
    var onLowerChanged: () -> Void = {}
    var onUpperChanged: () -> Void = {}

    @State private var isDraggingLower = false
    @State private var isDraggingUpper = false

    private let trackHeight: CGFloat = 4
    private let thumbSize: CGFloat = 20

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width - thumbSize
            let range = bounds.upperBound - bounds.lowerBound

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColors.textSecondary.opacity(0.16))
                    .frame(height: trackHeight)
                    .padding(.horizontal, thumbSize / 2)

                let lowerFraction = range > 0 ? (lowerValue - bounds.lowerBound) / range : 0
                let upperFraction = range > 0 ? (upperValue - bounds.lowerBound) / range : 1
                Capsule()
                    .fill(accentColor)
                    .frame(
                        width: CGFloat(upperFraction - lowerFraction) * width,
                        height: trackHeight
                    )
                    .offset(x: thumbSize / 2 + CGFloat(lowerFraction) * width)

                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay(Circle().stroke(accentColor, lineWidth: 2))
                    .offset(x: CGFloat(lowerFraction) * width)
                    .gesture(
                        DragGesture()
                            .onChanged { drag in
                                isDraggingLower = true
                                let fraction = max(0, min(Double(drag.location.x / width), Double(upperValue - bounds.lowerBound) / range - 0.01))
                                lowerValue = bounds.lowerBound + fraction * range
                                onLowerChanged()
                            }
                            .onEnded { _ in isDraggingLower = false }
                    )

                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay(Circle().stroke(accentColor, lineWidth: 2))
                    .offset(x: CGFloat(upperFraction) * width)
                    .gesture(
                        DragGesture()
                            .onChanged { drag in
                                isDraggingUpper = true
                                let fraction = min(1, max(Double(drag.location.x / width), Double(lowerValue - bounds.lowerBound) / range + 0.01))
                                upperValue = bounds.lowerBound + fraction * range
                                onUpperChanged()
                            }
                            .onEnded { _ in isDraggingUpper = false }
                    )
            }
        }
        .frame(height: thumbSize)
    }
}
