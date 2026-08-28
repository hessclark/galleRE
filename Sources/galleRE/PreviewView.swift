import SwiftUI

/// Large preview overlay with prev/next navigation, like Finder Quick Look.
struct PreviewView: View {
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
        guard let url = currentItem?.url else { return }
        loading = true
        fullImage = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let img = NSImage(contentsOf: url)
            DispatchQueue.main.async {
                if self.currentItem?.url == url {
                    self.fullImage = img
                    self.loading = false
                }
            }
        }
    }
}
