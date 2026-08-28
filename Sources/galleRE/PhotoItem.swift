import SwiftUI
import ImageIO
import UniformTypeIdentifiers

/// One photo in the working folder.
final class PhotoItem: Identifiable, ObservableObject {
    let id = UUID()
    @Published var url: URL
    @Published var thumbnail: NSImage?
    @Published var pixelSize: CGSize = .zero
    @Published var fileSizeBytes: Int = 0
    @Published var included: Bool = true     // exported to the MLS set?
    @Published var watermarked: Bool = false // burn the watermark on export?

    init(url: URL) {
        self.url = url
        loadMetadata()
    }

    var fileName: String { url.lastPathComponent }

    var fileSizeString: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSizeBytes), countStyle: .file)
    }

    var dimensionString: String {
        guard pixelSize != .zero else { return "" }
        return "\(Int(pixelSize.width))×\(Int(pixelSize.height))"
    }

    var isPDF: Bool { url.pathExtension.lowercased() == "pdf" }

    func loadMetadata() {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int {
            fileSizeBytes = size
        }
        if isPDF {
            if let size = ImageProcessor.pdfPageSize(url) {
                pixelSize = size
            }
            return
        }
        if let src = CGImageSourceCreateWithURL(url as CFURL, nil),
           let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] {
            let w = (props[kCGImagePropertyPixelWidth] as? CGFloat) ?? 0
            let h = (props[kCGImagePropertyPixelHeight] as? CGFloat) ?? 0
            // account for EXIF orientation (5-8 swap dimensions)
            let orientation = (props[kCGImagePropertyOrientation] as? Int) ?? 1
            if orientation >= 5 {
                pixelSize = CGSize(width: h, height: w)
            } else {
                pixelSize = CGSize(width: w, height: h)
            }
        }
    }

    /// Loads a downscaled thumbnail off the main thread.
    func loadThumbnail(maxPixel: CGFloat = 400) {
        let url = self.url
        let pdf = isPDF
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let cg: CGImage?
            if pdf {
                cg = ImageProcessor.renderPDF(url, page: 1, maxPixel: maxPixel)
            } else {
                let opts: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxPixel
                ]
                cg = CGImageSourceCreateWithURL(url as CFURL, nil)
                    .flatMap { CGImageSourceCreateThumbnailAtIndex($0, 0, opts as CFDictionary) }
            }
            guard let cg else { return }
            let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
            DispatchQueue.main.async { self?.thumbnail = img }
        }
    }

    static let supportedExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "pdf"]
}
