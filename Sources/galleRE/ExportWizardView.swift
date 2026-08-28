import SwiftUI

struct ExportWizardView: View {
    @EnvironmentObject var store: PhotoStore
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    // Local export-mode choice (not persisted with the rest of settings).
    @AppStorage("exportKindResize") private var resizeMode = true          // true = MLS resize, false = full res
    @AppStorage("exportConvertFullSize") private var convertFullSize = true // full-res: convert to JPG?

    @State private var phase: Phase = .configure
    private enum Phase { case configure, running, done }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            switch phase {
            case .configure: configureBody
            case .running:   runningBody
            case .done:      doneBody
            }
        }
        .frame(width: 500, height: 620)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.and.arrow.up.on.square").font(.title2).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text("Export").font(.title2.bold())
                Text("\(store.items.count) item\(store.items.count == 1 ? "" : "s") in current order")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    // MARK: Configure

    private var configureBody: some View {
        VStack(spacing: 0) {
            Form {
                Section("What to export") {
                    Picker("Output", selection: $resizeMode) {
                        Text("Resized for MLS (JPG)").tag(true)
                        Text("Full resolution").tag(false)
                    }
                    .pickerStyle(.radioGroup)

                    if !resizeMode {
                        Toggle("Convert everything to JPG", isOn: $convertFullSize)
                        Text(convertFullSize
                             ? "HEIC, PNG, TIFF and PDF are re-encoded to full-size JPG."
                             : "Photos keep their original format; PDFs are still converted to JPG.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                if resizeMode {
                    Section("Resize") {
                        Picker("Mode", selection: Binding(
                            get: { settings.resizeMode }, set: { settings.resizeMode = $0 })) {
                            ForEach(ResizeMode.allCases) { Text($0.label).tag($0) }
                        }
                        if settings.resizeMode == .longEdge {
                            HStack {
                                Text("Long edge"); Spacer()
                                TextField("", value: $settings.longEdgePx, format: .number)
                                    .frame(width: 64).multilineTextAlignment(.trailing)
                                Text("px")
                            }
                            HStack {
                                ForEach([1024, 1600, 2048], id: \.self) { px in
                                    Button("\(px)") { settings.longEdgePx = px }
                                        .buttonStyle(.bordered).controlSize(.small)
                                }
                            }
                        } else {
                            HStack {
                                Text("Max file size"); Spacer()
                                TextField("", value: $settings.maxFileSizeMB, format: .number)
                                    .frame(width: 64).multilineTextAlignment(.trailing)
                                Text("MB")
                            }
                        }
                    }
                }

                if resizeMode || convertFullSize {
                    Section("Quality") {
                        VStack(alignment: .leading) {
                            Text("JPEG quality: \(Int(settings.jpegQuality * 100))%")
                            Slider(value: $settings.jpegQuality, in: 0.4...1.0)
                        }
                    }
                }

                Section("Naming") {
                    Picker("Scheme", selection: Binding(
                        get: { settings.namingScheme }, set: { settings.namingScheme = $0 })) {
                        ForEach(NamingScheme.allCases) { Text($0.label).tag($0) }
                    }
                    if settings.namingScheme == .customPrefix {
                        TextField("Prefix (e.g. 123Main)", text: $settings.customPrefix)
                    }
                    Text("First file: \(previewName)").font(.caption).foregroundStyle(.secondary)
                }

                Section("Output") {
                    TextField("Subfolder name", text: $settings.exportFolderName)
                    Text("Files go to a “\(settings.exportFolderName)” subfolder inside your photo folder. Originals are not modified\(settings.outputMode == .inPlace ? " except renaming to order" : "").")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    runExport()
                } label: {
                    Label("Export \(store.items.count) →", systemImage: "square.and.arrow.up")
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(store.items.isEmpty)
            }
            .padding()
        }
    }

    // MARK: Running / Done

    private var runningBody: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView().controlSize(.large)
            Text(store.statusMessage).foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var doneBody: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill").font(.system(size: 48)).foregroundStyle(.green)
            Text("Export complete").font(.title3.bold())
            Text(store.statusMessage).font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)
            Spacer()
            Divider()
            HStack {
                Button("Reveal in Finder") {
                    if let dir = store.lastExportDir { NSWorkspace.shared.open(dir) }
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Helpers

    private var previewName: String {
        let base = settings.fileBaseName(order: 1, originalBaseName: "kitchen", totalCount: 24)
        return "\(base).jpg"
    }

    private func runExport() {
        phase = .running
        let options = PhotoStore.ExportOptions(resize: resizeMode, convertToJPG: convertFullSize)
        Task {
            await store.export(options: options)
            phase = .done
        }
    }
}
