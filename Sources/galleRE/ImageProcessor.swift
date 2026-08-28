import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

/// Resizes and re-encodes an image according to the current settings.
enum ImageProcessor {

    struct Result {
        var outputURL: URL
        var originalBytes: Int
        var newBytes: Int
    }

    /// Load a full CGImage with EXIF orientation applied, optionally capped at maxPixel.
    private static func loadImage(_ url: URL, maxPixel: CGFloat?) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        if let maxPixel {
            let opts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel
            ]
            return CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
        } else {
            return CGImageSourceCreateImageAtIndex(src, 0, nil)
        }
    }

    private static func encodeJPEG(_ image: CGImage, quality: Double) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        let props: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(dest, image, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    /// Process a single file to `destURL` using the provided settings.
    static func process(source: URL, destURL: URL, settings: AppSettings) throws -> Result {
        let originalBytes = (try? FileManager.default.attributesOfItem(atPath: source.path)[.size] as? Int) ?? 0

        let data: Data
        switch settings.resizeMode {
        case .longEdge:
            let maxPixel = CGFloat(settings.longEdgePx)
            guard let img = loadImage(source, maxPixel: maxPixel),
                  let out = encodeJPEG(img, quality: settings.jpegQuality) else {
                throw ProcessingError.failed(source.lastPathComponent)
            }
            data = out

        case .targetFileSize:
            let cap = Int(settings.maxFileSizeMB * 1_000_000)
            data = try compressToSize(source: source, capBytes: cap, settings: settings)
        }

        try data.write(to: destURL, options: .atomic)
        return Result(outputURL: destURL, originalBytes: originalBytes, newBytes: data.count)
    }

    /// Iteratively reduce dimensions and quality until under the byte cap.
    private static func compressToSize(source: URL, capBytes: Int, settings: AppSettings) throws -> Data {
        // Start from full size, step the long edge down.
        var longEdge: CGFloat = {
            if let img = loadImage(source, maxPixel: nil) {
                return CGFloat(max(img.width, img.height))
            }
            return 4000
        }()
        longEdge = min(longEdge, 4000) // sane upper bound to start
        var quality = settings.jpegQuality
        var best: Data?

        for _ in 0..<12 {
            guard let img = loadImage(source, maxPixel: longEdge),
                  let data = encodeJPEG(img, quality: quality) else { break }
            best = data
            if data.count <= capBytes { return data }
            // reduce: drop quality first, then dimensions
            if quality > 0.5 {
                quality -= 0.1
            } else {
                longEdge *= 0.85
                quality = settings.jpegQuality
            }
        }
        if let best { return best }
        throw ProcessingError.failed(source.lastPathComponent)
    }

    // MARK: - PDF support

    static func isPDF(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "pdf"
    }

    static func pdfPageCount(_ url: URL) -> Int {
        guard let doc = CGPDFDocument(url as CFURL) else { return 0 }
        return doc.numberOfPages
    }

    /// Size (in points) of a PDF page, accounting for its intrinsic rotation.
    static func pdfPageSize(_ url: URL, page: Int = 1) -> CGSize? {
        guard let doc = CGPDFDocument(url as CFURL), let pg = doc.page(at: page) else { return nil }
        let box = pg.getBoxRect(.mediaBox)
        var w = box.width, h = box.height
        let rot = abs(pg.rotationAngle % 360)
        if rot == 90 || rot == 270 { swap(&w, &h) }
        return CGSize(width: w, height: h)
    }

    /// Rasterize a single PDF page to a CGImage whose long edge == maxPixel.
    static func renderPDF(_ url: URL, page: Int, maxPixel: CGFloat) -> CGImage? {
        guard let doc = CGPDFDocument(url as CFURL), let pg = doc.page(at: page) else { return nil }
        let box = pg.getBoxRect(.mediaBox)
        let rot = pg.rotationAngle
        var boxW = box.width, boxH = box.height
        if abs(rot % 360) == 90 || abs(rot % 360) == 270 { swap(&boxW, &boxH) }
        guard boxW > 0, boxH > 0 else { return nil }

        let scale = maxPixel / max(boxW, boxH)
        let outW = max(1, Int((boxW * scale).rounded()))
        let outH = max(1, Int((boxH * scale).rounded()))

        guard let ctx = CGContext(data: nil, width: outW, height: outH,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        // PDFs are frequently transparent — paint white so scans/flyers aren't black.
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: outW, height: outH))
        ctx.interpolationQuality = .high

        let target = CGRect(x: 0, y: 0, width: CGFloat(outW), height: CGFloat(outH))
        let transform = pg.getDrawingTransform(.mediaBox, rect: target, rotate: rot, preserveAspectRatio: true)
        ctx.concatenate(transform)
        ctx.clip(to: box)
        ctx.drawPDFPage(pg)
        return ctx.makeImage()
    }

    /// Convert one PDF page to a JPEG at `destURL`.
    static func processPDFPage(source: URL, page: Int, destURL: URL,
                               settings: AppSettings, resize: Bool) throws -> Result {
        let originalBytes = (try? FileManager.default.attributesOfItem(atPath: source.path)[.size] as? Int) ?? 0
        let maxPixel: CGFloat = resize ? CGFloat(settings.longEdgePx) : 2400
        let quality: Double = resize ? settings.jpegQuality : 0.92
        guard let img = renderPDF(source, page: page, maxPixel: maxPixel),
              let data = encodeJPEG(img, quality: quality) else {
            throw ProcessingError.failed(source.lastPathComponent)
        }
        try data.write(to: destURL, options: .atomic)
        return Result(outputURL: destURL, originalBytes: originalBytes, newBytes: data.count)
    }

    enum ProcessingError: LocalizedError {
        case failed(String)
        var errorDescription: String? {
            switch self {
            case .failed(let name): return "Could not process \(name)."
            }
        }
    }
}
