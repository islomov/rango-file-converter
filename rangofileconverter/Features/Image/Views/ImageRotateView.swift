import SwiftUI

struct ImageRotateView: View {
    let fileURL: URL
    let fileName: String
    let onApply: (Double, Bool, Bool) -> Void

    @State private var rotation: Double = 0
    @State private var flipH = false
    @State private var flipV = false
    @State private var previewImage: UIImage?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            GeometryReader { geo in
                let maxSide = min(geo.size.width - 40, geo.size.height)
                Group {
                    if let previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: maxSide, maxHeight: maxSide)
                            .rotationEffect(.degrees(rotation))
                            .scaleEffect(x: flipH ? -1 : 1, y: flipV ? -1 : 1)
                            .animation(.easeInOut(duration: 0.25), value: rotation)
                            .animation(.easeInOut(duration: 0.25), value: flipH)
                            .animation(.easeInOut(duration: 0.25), value: flipV)
                    } else {
                        ProgressView()
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }

            Spacer()

            controls
        }
        .navigationTitle("Rotate")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Reset") {
                    rotation = 0
                    flipH = false
                    flipV = false
                }
                .disabled(rotation == 0 && !flipH && !flipV)
            }
        }
        .onAppear {
            previewImage = ImageConverterViewModel.loadPreviewImage(from: fileURL)
        }
    }

    private var controls: some View {
        VStack(spacing: 20) {
            // Quick actions
            HStack(spacing: 24) {
                quickAction(icon: "rotate.left", label: "90\u{00B0} L") {
                    rotation -= 90
                }
                quickAction(icon: "rotate.right", label: "90\u{00B0} R") {
                    rotation += 90
                }
                quickAction(icon: "arrow.left.and.right.righttriangle.left.righttriangle.right", label: "Flip H") {
                    flipH.toggle()
                }
                quickAction(icon: "arrow.up.and.down.righttriangle.up.righttriangle.down", label: "Flip V") {
                    flipV.toggle()
                }
            }

            // Free rotation slider
            VStack(spacing: 8) {
                Text("\(Int(normalizedDegrees))\u{00B0}")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)

                Slider(value: $rotation, in: -180...180, step: 1)
                    .padding(.horizontal, 4)
            }

            // Apply button
            Button {
                onApply(rotation, flipH, flipV)
            } label: {
                Text("Apply")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(rotation == 0 && !flipH && !flipV)
        }
        .padding(20)
        .background(.bar)
    }

    private func quickAction(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(.primary)
            .frame(width: 64, height: 56)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var normalizedDegrees: Double {
        let mod = rotation.truncatingRemainder(dividingBy: 360)
        return mod < 0 ? mod + 360 : mod
    }
}
