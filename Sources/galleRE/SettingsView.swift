import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Settings").font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding()
            Divider()

            Form {
                Section("Naming") {
                    Picker("Scheme", selection: Binding(
                        get: { settings.namingScheme },
                        set: { settings.namingScheme = $0 })) {
                        ForEach(NamingScheme.allCases) { Text($0.label).tag($0) }
                    }
                    if settings.namingScheme == .customPrefix {
                        TextField("Prefix (e.g. 123Main)", text: $settings.customPrefix)
                    }
                    TextField("Separator", text: $settings.separator)
                    Stepper("Start number: \(settings.startNumber)", value: $settings.startNumber, in: 0...100)
                    Text("Preview: \(previewName)")
                        .font(.callout).foregroundStyle(.secondary)
                }

                Section("Resize") {
                    Picker("Mode", selection: Binding(
                        get: { settings.resizeMode },
                        set: { settings.resizeMode = $0 })) {
                        ForEach(ResizeMode.allCases) { Text($0.label).tag($0) }
                    }
                    if settings.resizeMode == .longEdge {
                        HStack {
                            Text("Long edge")
                            Spacer()
                            TextField("", value: $settings.longEdgePx, format: .number)
                                .frame(width: 70).multilineTextAlignment(.trailing)
                            Text("px")
                        }
                        commonLongEdgePresets
                    } else {
                        HStack {
                            Text("Max file size")
                            Spacer()
                            TextField("", value: $settings.maxFileSizeMB, format: .number)
                                .frame(width: 70).multilineTextAlignment(.trailing)
                            Text("MB")
                        }
                    }
                    VStack(alignment: .leading) {
                        Text("JPEG quality: \(Int(settings.jpegQuality * 100))%")
                        Slider(value: $settings.jpegQuality, in: 0.4...1.0)
                    }
                }

                Section("MLS photo limit") {
                    HStack {
                        Text("Max photos")
                        Spacer()
                        TextField("", value: $settings.maxPhotos, format: .number)
                            .frame(width: 60).multilineTextAlignment(.trailing)
                    }
                    Text(settings.maxPhotos > 0
                         ? "A counter shows how many photos are included vs. your limit of \(settings.maxPhotos). Photos past the limit are flagged, and you can trim to fit."
                         : "0 = no limit. Set your MLS's maximum (e.g. 24) to get a live count and trimming help.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Watermark") {
                    TextField("Text", text: $settings.watermarkText, axis: .vertical)
                        .lineLimit(1...3)
                    Picker("Position", selection: Binding(
                        get: { settings.watermarkPosition },
                        set: { settings.watermarkPosition = $0 })) {
                        ForEach(WatermarkPosition.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Color", selection: $settings.watermarkWhite) {
                        Text("White").tag(true)
                        Text("Black").tag(false)
                    }
                    .pickerStyle(.segmented)
                    VStack(alignment: .leading) {
                        Text("Size: \(settings.watermarkSizePct, specifier: "%.1f")% of image height")
                        Slider(value: $settings.watermarkSizePct, in: 1.5...8)
                    }
                    VStack(alignment: .leading) {
                        Text("Opacity: \(Int(settings.watermarkOpacity * 100))%")
                        Slider(value: $settings.watermarkOpacity, in: 0.2...1.0)
                    }
                    Text("Turn the watermark on per photo with the 🅰︎ toggle on each thumbnail, or the Watermark toolbar button. It's burned in only on export — originals stay clean.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Output") {
                    Picker("When exporting", selection: Binding(
                        get: { settings.outputMode },
                        set: { settings.outputMode = $0 })) {
                        ForEach(OutputMode.allCases) { Text($0.label).tag($0) }
                    }
                    TextField("Export subfolder name", text: $settings.exportFolderName)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 460, height: 560)
    }

    private var previewName: String {
        let base = settings.fileBaseName(order: 1, originalBaseName: "kitchen", totalCount: 24)
        return "\(base).jpg"
    }

    private var commonLongEdgePresets: some View {
        HStack {
            ForEach([1024, 1600, 2048], id: \.self) { px in
                Button("\(px)") { settings.longEdgePx = px }
                    .buttonStyle(.bordered).controlSize(.small)
            }
        }
    }
}
