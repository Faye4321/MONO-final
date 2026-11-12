import ImageIO
import UIKit
import CryptoKit

// Photos are stored as files under Documents/Images; JSON keeps only file names.
enum ImageStore {
    private static var scope: String?
    private static var legacyDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Images", isDirectory: true)
    }

    static var directory: URL {
        let folder = scope.map { legacyDirectory.appendingPathComponent("Accounts/" + $0, isDirectory: true) } ?? legacyDirectory
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func switchAccount(to uid: String?) {
        scope = uid.map { SHA256.hash(data: Data($0.utf8)).map { String(format: "%02x", $0) }.joined() }
        cache.removeAllObjects()
        thumbnailCache.removeAllObjects()
    }

    static func importLegacy(named name: String) throws {
        let destination = url(for: name)
        guard !FileManager.default.fileExists(atPath: destination.path) else { return }
        let source = legacyDirectory.appendingPathComponent(name)
        try FileManager.default.copyItem(at: source, to: destination)
    }

    private static let cache = NSCache<NSString, UIImage>()
    private static let thumbnailCache = NSCache<NSString, UIImage>()
    private static let maxPixelLength: CGFloat = 2000

    /// Saves the photo as a downscaled JPEG and returns its file name.
    static func save(_ data: Data) -> String? {
        guard let image = UIImage(data: data),
              let jpeg = downscaled(image).jpegData(compressionQuality: 0.85) else {
            return nil
        }

        let name = UUID().uuidString + ".jpg"
        do {
            try jpeg.write(to: url(for: name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func image(named name: String) -> UIImage? {
        if let cached = cache.object(forKey: name as NSString) {
            return cached
        }
        guard let image = UIImage(contentsOfFile: url(for: name).path) else {
            return nil
        }
        cache.setObject(image, forKey: name as NSString)
        return image
    }

    /// A small, cached copy for collages and timelines, decoded without
    /// loading the full-size photo into memory.
    static func thumbnail(named name: String, maxPixelLength: CGFloat = 320) -> UIImage? {
        let key = "\(name)@\(Int(maxPixelLength))" as NSString
        if let cached = thumbnailCache.object(forKey: key) {
            return cached
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelLength
        ]
        guard let source = CGImageSourceCreateWithURL(url(for: name) as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let image = UIImage(cgImage: cgImage)
        thumbnailCache.setObject(image, forKey: key)
        return image
    }

    static func delete(named name: String) {
        cache.removeObject(forKey: name as NSString)
        thumbnailCache.removeAllObjects()
        try? FileManager.default.removeItem(at: url(for: name))
    }

    static func url(for name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    private static func downscaled(_ image: UIImage) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxPixelLength else { return image }

        let scale = maxPixelLength / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

enum PhotoMetadata {
    /// The capture date recorded in the photo's EXIF/TIFF data, if any.
    /// This is when the photo was taken, not necessarily when the object
    /// was acquired, so callers should only offer it as a suggestion.
    static func captureDate(from data: Data) -> Date? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }

        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let raw = exif?[kCGImagePropertyExifDateTimeOriginal] as? String
            ?? tiff?[kCGImagePropertyTIFFDateTime] as? String

        guard let raw else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: raw)
    }
}

extension CollectibleItem {
    /// The photo the user uploaded for this object, if any.
    var uploadedImage: UIImage? {
        if let imageFileName {
            return ImageStore.image(named: imageFileName)
        }
        if let imageData {
            return UIImage(data: imageData)
        }
        return nil
    }

    var hasArtwork: Bool {
        imageFileName != nil || imageData != nil || imageName != nil
    }
}
