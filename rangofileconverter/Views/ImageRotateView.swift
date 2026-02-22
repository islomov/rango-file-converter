import SwiftUI

struct ImageRotateView: View {
    let image: UIImage
    let fileName: String
    let onApply: (UIImage, URL) async -> Void

    @State private var rotation: Double = 0
    @State private var flipH = false
    @State private var flipV = false
    @State private var isApplying = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()

                GeometryReader { geo in
                    let maxSide = min(geo.size.width - 40, geo.size.height)
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: maxSide, maxHeight: maxSide)
                        .rotationEffect(.degrees(rotation))
                        .scaleEffect(x: flipH ? -1 : 1, y: flipV ? -1 : 1)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .animation(.easeInOut(duration: 0.25), value: rotation)
                        .animation(.easeInOut(duration: 0.25), value: flipH)
                        .animation(.easeInOut(duration: 0.25), value: flipV)
                }

                Spacer()

                controls
            }
            .allowsHitTesting(!isApplying)

            if isApplying {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("Rotating...")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
        }
        .navigationTitle("Rotate")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") {
                    rotation = 0
                    flipH = false
                    flipV = false
                }
                .disabled(isApplying || (rotation == 0 && !flipH && !flipV))
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 20) {
            // Quick actions
            HStack(spacing: 24) {
                quickAction(icon: "rotate.left", label: "90° L") {
                    rotation -= 90
                }
                quickAction(icon: "rotate.right", label: "90° R") {
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
                Text("\(Int(normalizedDegrees))°")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)

                Slider(value: $rotation, in: -180...180, step: 1)
                    .padding(.horizontal, 4)
            }

            // Apply button
            Button {
                isApplying = true
                Task {
                    print("[Rotate] renderRotatedImage starting...")
                    if let (rotatedImage, url) = renderRotatedImage() {
                        print("[Rotate] render succeeded, url: \(url)")
                        print("[Rotate] calling onApply...")
                        await onApply(rotatedImage, url)
                        print("[Rotate] onApply returned")
                    } else {
                        print("[Rotate] renderRotatedImage returned nil!")
                    }
                    isApplying = false
                }
            } label: {
                if isApplying {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                } else {
                    Text("Apply")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isApplying || (rotation == 0 && !flipH && !flipV))
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

    // MARK: - Render

    private func renderRotatedImage() -> (UIImage, URL)? {
        guard let cgImage = image.cgImage else { return nil }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let radians = rotation * .pi / 180

        // Compute bounding box of rotated image
        let rotatedRect = CGRect(x: 0, y: 0, width: width, height: height)
            .applying(CGAffineTransform(rotationAngle: radians))
        let newWidth = abs(rotatedRect.width)
        let newHeight = abs(rotatedRect.height)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
                  data: nil,
                  width: Int(newWidth),
                  height: Int(newHeight),
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: bitmapInfo
              ) else { return nil }

        context.translateBy(x: newWidth / 2, y: newHeight / 2)
        context.rotate(by: radians)
        context.scaleBy(x: flipH ? -1 : 1, y: flipV ? -1 : 1)
        context.draw(cgImage, in: CGRect(x: -width / 2, y: -height / 2, width: width, height: height))

        guard let outputCG = context.makeImage() else { return nil }
        let outputImage = UIImage(cgImage: outputCG)

        // Save to temp file
        let ext = fileName.components(separatedBy: ".").last ?? "png"
        let outputName = "rotated_\(UUID().uuidString.prefix(8)).\(ext)"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rango_conversions", isDirectory: true)
            .appendingPathComponent(outputName)

        try? FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if let data = outputImage.pngData() {
            try? data.write(to: outputURL)
            return (outputImage, outputURL)
        }

        return nil
    }
}
