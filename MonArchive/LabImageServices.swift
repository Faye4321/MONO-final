import CoreImage
import CoreImage.CIFilterBuiltins
import Photos
import SwiftUI
import UIKit
import Vision

enum LabCutoutError: LocalizedError {
    case invalidImage
    case noForeground
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "The selected image could not be read."
        case .noForeground: return "MONO could not find a clear foreground object."
        case .renderFailed: return "The cutout could not be rendered."
        }
    }
}

enum LabCutoutService {
    static func removeBackground(from image: UIImage) async throws -> UIImage {
        guard let cgImage = normalized(image).cgImage else { throw LabCutoutError.invalidImage }

        return try await Task.detached(priority: .userInitiated) {
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try handler.perform([request])
            guard let observation = request.results?.first,
                  !observation.allInstances.isEmpty else {
                throw LabCutoutError.noForeground
            }

            let maskBuffer = try observation.generateScaledMaskForImage(
                forInstances: observation.allInstances,
                from: handler
            )
            let source = CIImage(cgImage: cgImage)
            let mask = CIImage(cvPixelBuffer: maskBuffer)
                .transformed(by: CGAffineTransform(
                    scaleX: source.extent.width / CGFloat(CVPixelBufferGetWidth(maskBuffer)),
                    y: source.extent.height / CGFloat(CVPixelBufferGetHeight(maskBuffer))
                ))
            let clear = CIImage(color: CIColor.clear).cropped(to: source.extent)
            let filter = CIFilter.blendWithMask()
            filter.inputImage = source
            filter.backgroundImage = clear
            filter.maskImage = mask

            let context = CIContext(options: [.useSoftwareRenderer: false])
            guard let output = filter.outputImage,
                  let rendered = context.createCGImage(output, from: source.extent) else {
                throw LabCutoutError.renderFailed
            }
            return UIImage(cgImage: rendered)
        }.value
    }

    private static func normalized(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: image.size)) }
    }
}

enum LabMaskMode: String, CaseIterable, Identifiable {
    case restore = "RESTORE"
    case erase = "ERASE"
    var id: Self { self }
}

struct LabMaskStroke: Identifiable, Equatable {
    let id = UUID()
    var mode: LabMaskMode
    var points: [CGPoint]
    var size: CGFloat
    var softness: CGFloat
}

enum LabMaskRenderer {
    static func render(original: UIImage, cutout: UIImage, strokes: [LabMaskStroke]) -> UIImage {
        let source = normalized(original)
        let base = normalized(cutout)
        let size = source.size
        let renderer = UIGraphicsImageRenderer(size: size, format: transparentFormat())

        return renderer.image { context in
            base.draw(in: CGRect(origin: .zero, size: size))
            let cg = context.cgContext

            for stroke in strokes where stroke.points.count > 1 {
                let path = CGMutablePath()
                let first = CGPoint(x: stroke.points[0].x * size.width, y: stroke.points[0].y * size.height)
                path.move(to: first)
                for point in stroke.points.dropFirst() {
                    path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
                }
                let width = stroke.size * max(size.width, size.height)

                cg.saveGState()
                cg.setLineCap(.round)
                cg.setLineJoin(.round)
                cg.setLineWidth(width)
                if stroke.softness > 0 {
                    cg.setShadow(offset: .zero, blur: width * stroke.softness * 0.35, color: UIColor.black.cgColor)
                }

                if stroke.mode == .erase {
                    cg.setBlendMode(.clear)
                    cg.addPath(path)
                    cg.strokePath()
                } else {
                    cg.addPath(path)
                    cg.replacePathWithStrokedPath()
                    cg.clip()
                    source.draw(in: CGRect(origin: .zero, size: size))
                }
                cg.restoreGState()
            }
        }
    }

    private static func normalized(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let renderer = UIGraphicsImageRenderer(size: image.size, format: transparentFormat())
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: image.size)) }
    }

    private static func transparentFormat() -> UIGraphicsImageRendererFormat {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        return format
    }
}

@MainActor
enum LabExportService {
    static func render(project: LabProject, transparent: Bool, scale: CGFloat = 3) -> UIImage? {
        let view = LabExportCanvasView(project: project, transparent: transparent)
            .frame(width: 900 * project.format.aspectRatio, height: 900)
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        renderer.isOpaque = !transparent
        return renderer.uiImage
    }

    static func saveToPhotos(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            DispatchQueue.main.async { completion(true) }
        }
    }

    static func temporaryFile(for image: UIImage, format: String) -> URL? {
        let isPNG = format.uppercased() == "PNG"
        guard let data = isPNG ? image.pngData() : image.jpegData(compressionQuality: 0.94) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MONO-Lab-\(UUID().uuidString)")
            .appendingPathExtension(isPNG ? "png" : "jpg")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

struct LabShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
