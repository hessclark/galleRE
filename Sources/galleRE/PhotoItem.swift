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

    /// Bounded queue so reading metadata for a large folder stays off the
    /// main thread and doesn't block folder navigation.
    private static let metaQueue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 4
        q.qualityOfService = .userInitiated
        return q
    }()

    /// Reads file size and pixel dimensions off the main thread, then publishes.
    func loadMetadata() {
        let url = self.url
        let pdf = isPDF
        PhotoItem.metaQueue.addOperation { [weak self] in
            autoreleasepool {
                var size = 0
                if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let s = attrs[.size] as? Int { size = s }

                var px = CGSize.zero
                if pdf {
                    if let s = ImageProcessor.pdfPageSize(url) { px = s }
                } else if let src = CGImageSourceCreateWithURL(url as CFURL, nil),
                          let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] {
                    let w = (props[kCGImagePropertyPixelWidth] as? CGFloat) ?? 0
                    let h = (props[kCGImagePropertyPixelHeight] as? CGFloat) ?? 0
                    let orientation = (props[kCGImagePropertyOrientation] as? Int) ?? 1  // 5–8 swap dims
                    px = orientation >= 5 ? CGSize(width: h, height: w) : CGSize(width: w, height: h)
                }

                let fsize = size, psize = px
                DispatchQueue.main.async {
                    self?.fileSizeBytes = fsize
                    self?.pixelSize = psize
                }
            }
        }
    }

    /// Loads a downscaled thumbnail off the main thread.
    /// Bounded queue so opening a large folder can't spawn hundreds of
    /// concurrent decodes (which exhausts memory/threads and crashes).
    private static let thumbQueue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 3
        q.qualityOfService = .userInitiated
        return q
    }()

    func loadThumbnail(maxPixel: CGFloat = 400) {
        guard thumbnail == nil else { return }
        let url = self.url
        let pdf = isPDF
        PhotoItem.thumbQueue.addOperation { [weak self] in
            autoreleasepool {
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
    }

    static let supportedExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "pdf"]
}
