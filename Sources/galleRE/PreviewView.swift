import SwiftUI
import ImageIO
import CoreGraphics

/// Large preview overlay with prev/next navigation, like Finder Quick Look.
struct PreviewView: View {
    // Screen-sized decode cap and a shared decoded-image cache.
    private static let maxPreviewPixel: CGFloat = 2560
    private static let cache: NSCache<NSURL, NSImage> = {
        let c = NSCache<NSURL, NSImage>(); c.countLimit = 24; return c
    }()

    /// Fast, screen-sized decode via ImageIO (orientation-aware), cached.
    private static func previewImage(for url: URL) -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        return autoreleasepool {
            let opts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPreviewPixel
            ]
            guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
            else {
                let img = NSImage(contentsOf: url)
                if let img { cache.setObject(img, forKey: url as NSURL) }
                return img
            }
            let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
            cache.setObject(img, forKey: url as NSURL)
            return img
        }
    }
    @EnvironmentObject var store: PhotoStore
    @Binding var currentID: UUID?
    @Binding var isPresented: Bool

    @State private var fullImage: NSImage?
    @State private var loading = true

    private var currentIndex: Int? {
        guard let currentID else { return nil }
        return store.items.firstIndex { $0.id == currentID }
    }
    private var currentItem: PhotoItem? {
        guard let i = currentIndex else { return nil }
        return store.items[i]
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider().overlay(.white.opacity(0.15))
                imageArea
            }

            // edge nav buttons
            HStack {
                navButton("chevron.left") { step(-1) }
                    .disabled((currentIndex ?? 0) <= 0)
                Spacer()
                navButton("chevron.right") { step(1) }
                    .disabled((currentIndex ?? 0) >= store.items.count - 1)
            }
            .padding(.horizontal, 16)
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.leftArrow)  { step(-1); return .handled }
        .onKeyPress(.rightArrow) { step(1);  return .handled }
        .onKeyPress(.space)      { isPresented = false; return .handled }
        .onKeyPress(.escape)     { isPresented = false; return .handled }
        .onAppear(perform: load)
        .onChange(of: currentID) { _, _ in load() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(currentItem?.fileName ?? "")
                    .font(.headline).foregroundStyle(.white)
                if let item = currentItem {
                    Text("\(item.dimensionString)  ·  \(item.fileSizeString)")
                        .font(.caption).foregroundStyle(.white.opacity(0.7))
                }
            }
            Spacer()
            if let i = currentIndex {
                Text("\(i + 1) of \(store.items.count)")
                    .font(.callout.monospacedDigit()).foregroundStyle(.white.opacity(0.7))
            }
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill").font(.title2)
            }
            .buttonStyle(.plain).foregroundStyle(.white.opacity(0.8))
            .keyboardShortcut(.cancelAction)
            .padding(.leading, 12)
        }
        .padding(16)
    }

    private var imageArea: some View {
        ZStack {
            if let img = fullImage {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .padding(24)
            } else if loading {
                ProgressView().controlSize(.large).tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func navButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.15), in: Circle())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    private func step(_ delta: Int) {
        guard let i = currentIndex else { return }
        let next = i + delta
        guard store.items.indices.contains(next) else { return }
        currentID = store.items[next].id
    }

    private func load() {
        guard let item = currentItem else { return }
        let url = item.url

        // If already decoded, show instantly with no spinner.
        if let cached = Self.cache.object(forKey: url as NSURL) {
            fullImage = cached
            loading = false
            prefetchNeighbors()
            return
        }

        // Show the small grid thumbnail immediately as a placeholder, then swap.
        fullImage = item.thumbnail
        loading = item.thumbnail == nil
        DispatchQueue.global(qos: .userInitiated).async {
            let img = Self.previewImage(for: url)
            DispatchQueue.main.async {
                if self.currentItem?.url == url {
                    self.fullImage = img
                    self.loading = false
                }
                self.prefetchNeighbors()
            }
        }
    }

    /// Warm the cache for the previous/next photos so arrow navigation is instant.
    private func prefetchNeighbors() {
        guard let i = currentIndex else { return }
        for offset in [-1, 1, 2, -2] {
            let n = i + offset
            guard store.items.indices.contains(n) else { continue }
            let url = store.items[n].url
            if Self.cache.object(forKey: url as NSURL) != nil { continue }
            DispatchQueue.global(qos: .utility).async {
                _ = Self.previewImage(for: url)
            }
        }
    }
}
