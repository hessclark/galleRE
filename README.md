<div align="center">

# galleRE

**A native macOS app for organizing real-estate photos for MLS upload.**

Reorder by drag-and-drop, rename to lock in the order, and batch-resize/convert to MLS-ready JPGs — all in a fast, native SwiftUI app.

</div>

---

## Features

- 📂 **Open any folder** of property photos — thumbnails load in a grid with dimensions and file size.
- 🖱️ **Drag to reorder** — a live number badge shows each photo's MLS position.
- 🔢 **Save Current Order** — renames files in place with number prefixes so Finder *and* the MLS uploader keep your exact order. Uses safe two-phase renaming.
- 🗜️ **Resize for MLS** — writes downsized JPEGs (default long edge 1024px, configurable) into an export subfolder. Originals are never touched.
- 🖼️ **Export Full-Size** — full-resolution renamed copies, for brochures or archives.
- 🔄 **Format conversion** — HEIC, PNG, TIFF and **PDF** files convert to JPG on export. Multi-page PDFs become one JPG per page.
- 👁️ **Quick preview** — click a photo and press Space (or double-click) for a large preview; arrow keys flip through.
- ⚙️ **Configurable** — naming scheme, resize target (long edge or max file size), JPEG quality, and output location.

## Requirements

- macOS 14 (Sonoma) or later
- Swift 5.9+ toolchain (Xcode or Command Line Tools)

## Build & Run

```bash
git clone https://github.com/hessclark/galleRE.git
cd galleRE
./build_app.sh
open galleRE.app
```

`build_app.sh` compiles a release build and packages it into a double-clickable `galleRE.app` bundle (icon included). No full Xcode install required — Command Line Tools are enough.

## Project layout

| Path | Purpose |
|------|---------|
| `Sources/galleRE/` | SwiftUI app source |
| `build_app.sh` | Compiles and assembles the `.app` bundle |
| `make_icon.swift` | Regenerates the app icon art |
| `Package.swift` | Swift Package manifest |

## Support this project

galleRE is free and open source. If it saves you time, a tip is hugely appreciated and helps me keep improving it:

### 💜 Venmo: [@ClarkHess](https://venmo.com/u/ClarkHess)

## License

[MIT](LICENSE) © Clark Hess
