<div align="center">

# galleRE

**The best way to organize, optimize, and manage your real estate MLS photos.**

A native macOS app: reorder by drag-and-drop, rename to lock in the order, batch-resize/convert to MLS-ready JPGs, fit your MLS's photo limit, and add AI/virtual-staging watermarks — all fast and native.

![Platform: macOS only](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Universal: Apple Silicon + Intel](https://img.shields.io/badge/universal-Apple%20Silicon%20%2B%20Intel-lightgrey)
![License: MIT](https://img.shields.io/badge/license-MIT-green)

> 🍎 **macOS only.** galleRE is a native Mac app — it does not run on Windows, Linux, iPhone, or iPad.

### 🌐 [gallere.app](https://gallere.app)

</div>

---

## Download & Install (Mac)

**No developer tools required — just download and drag.**

1. Go to the [**latest release**](https://github.com/hessclark/galleRE/releases/latest) and download **`galleRE-macOS.zip`**.
2. Double-click the zip to unzip it (Safari may unzip it automatically). You'll get **galleRE.app**.
3. Drag **galleRE.app** into your **Applications** folder.
4. **First launch:** right-click (or Control-click) the app → **Open** → **Open** again in the dialog.

> **Why the right-click?** galleRE is open source and *ad-hoc signed* (not paid Apple notarization), so on first launch macOS shows *"Apple could not verify galleRE is free of malware."* Right-click → **Open** tells macOS you trust it — you only do this once. (Alternatively: **System Settings → Privacy & Security → Open Anyway**.)

**Requirements:** macOS 14 (Sonoma) or later. Runs natively on both Apple Silicon (M-series) and Intel Macs.

---

## Features

- 📂 **Open any folder** of property photos — thumbnails load in a grid with dimensions and file size.
- 🖱️ **Drag to reorder** — a live number badge shows each photo's MLS position.
- 🔢 **Save Current Order** — renames files in place with number prefixes so Finder *and* the MLS uploader keep your exact order. Uses safe two-phase renaming.
- 🗜️ **Resize for MLS** — writes downsized JPEGs (default long edge 1024px, configurable) into an export subfolder. Originals are never touched.
- 🖼️ **Export Full-Size** — full-resolution renamed copies, for brochures or archives.
- 🔄 **Format conversion** — HEIC, PNG, TIFF and **PDF** files convert to JPG on export. Multi-page PDFs become one JPG per page.
- 🔢 **Fit your MLS limit** — set your MLS's max photo count; include/exclude photos with one click and trim to fit, with a live counter.
- 🅰️ **Watermarks** — add a text watermark (e.g. "virtually staged or edited with AI") to any photo; burned in on export, originals untouched.
- 👁️ **Quick preview** — click a photo and press Space (or double-click) for a large preview; arrow keys flip through.
- ⚙️ **Configurable** — naming scheme, resize target (long edge or max file size), JPEG quality, and output location.

## Build from source

For developers who want to build it themselves (macOS only):

- macOS 14 (Sonoma) or later
- Swift 5.9+ toolchain (Xcode or Command Line Tools)

```bash
git clone https://github.com/hessclark/galleRE.git
cd galleRE
./build_app.sh            # single-arch build for your Mac
open galleRE.app
```

To produce a universal (Apple Silicon + Intel) bundle for distribution:

```bash
./build_app.sh --universal
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
