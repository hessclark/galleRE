import SwiftUI

enum NamingScheme: String, CaseIterable, Identifiable {
    case numberPrefixKeepName   // 01_kitchen.jpg
    case numberOnly             // 01.jpg
    case customPrefix           // 123Main_01.jpg

    var id: String { rawValue }
    var label: String {
        switch self {
        case .numberPrefixKeepName: return "Number prefix + original name"
        case .numberOnly:           return "Number only"
        case .customPrefix:         return "Custom prefix + number"
        }
    }
}

enum ResizeMode: String, CaseIterable, Identifiable {
    case longEdge       // scale so the longest side == longEdgePx
    case targetFileSize // scale/compress to stay under maxFileSizeMB

    var id: String { rawValue }
    var label: String {
        switch self {
        case .longEdge:       return "Long edge (pixels)"
        case .targetFileSize: return "Target file size (MB)"
        }
    }
}

enum WatermarkPosition: String, CaseIterable, Identifiable {
    case bottomRight, bottomLeft, bottomCenter, topRight, topLeft, center
    var id: String { rawValue }
    var label: String {
        switch self {
        case .bottomRight:  return "Bottom right"
        case .bottomLeft:   return "Bottom left"
        case .bottomCenter: return "Bottom center"
        case .topRight:     return "Top right"
        case .topLeft:      return "Top left"
        case .center:       return "Center"
        }
    }
}

enum OutputMode: String, CaseIterable, Identifiable {
    case exportSubfolder // originals untouched, copies to subfolder
    case inPlace         // rename working files in place; resize to subfolder

    var id: String { rawValue }
    var label: String {
        switch self {
        case .exportSubfolder: return "Export copies to a subfolder"
        case .inPlace:         return "Rename in place (resize to subfolder)"
        }
    }
}

/// Persisted user settings, backed by UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("namingScheme") var namingSchemeRaw: String = NamingScheme.numberPrefixKeepName.rawValue
    @AppStorage("customPrefix") var customPrefix: String = ""
    @AppStorage("separator")    var separator: String = "_"
    @AppStorage("startNumber")  var startNumber: Int = 1

    @AppStorage("resizeMode")   var resizeModeRaw: String = ResizeMode.longEdge.rawValue
    @AppStorage("longEdgePx")   var longEdgePx: Int = 1024
    @AppStorage("jpegQuality")  var jpegQuality: Double = 0.85
    @AppStorage("maxFileSizeMB") var maxFileSizeMB: Double = 5.0

    @AppStorage("outputMode")   var outputModeRaw: String = OutputMode.exportSubfolder.rawValue
    @AppStorage("exportFolderName") var exportFolderName: String = "MLS_export"

    // Max photos allowed by the MLS (0 = no limit).
    @AppStorage("maxPhotos") var maxPhotos: Int = 0

    // Watermark
    @AppStorage("watermarkText") var watermarkText: String = "This image was virtually staged or edited with AI"
    @AppStorage("watermarkPosition") var watermarkPositionRaw: String = WatermarkPosition.bottomRight.rawValue
    @AppStorage("watermarkOpacity") var watermarkOpacity: Double = 0.7
    @AppStorage("watermarkSizePct") var watermarkSizePct: Double = 3.5   // font height as % of image height
    @AppStorage("watermarkWhite") var watermarkWhite: Bool = true        // white text vs black

    var watermarkPosition: WatermarkPosition {
        get { WatermarkPosition(rawValue: watermarkPositionRaw) ?? .bottomRight }
        set { watermarkPositionRaw = newValue.rawValue }
    }

    var namingScheme: NamingScheme {
        get { NamingScheme(rawValue: namingSchemeRaw) ?? .numberPrefixKeepName }
        set { namingSchemeRaw = newValue.rawValue }
    }
    var resizeMode: ResizeMode {
        get { ResizeMode(rawValue: resizeModeRaw) ?? .longEdge }
        set { resizeModeRaw = newValue.rawValue }
    }
    var outputMode: OutputMode {
        get { OutputMode(rawValue: outputModeRaw) ?? .exportSubfolder }
        set { outputModeRaw = newValue.rawValue }
    }

    /// Builds the base filename (without extension) for a given 1-based order.
    func fileBaseName(order: Int, originalBaseName: String, totalCount: Int) -> String {
        let width = max(2, String(totalCount + startNumber - 1).count)
        let number = String(format: "%0\(width)d", order + startNumber - 1)
        switch namingScheme {
        case .numberOnly:
            return number
        case .numberPrefixKeepName:
            return "\(number)\(separator)\(originalBaseName)"
        case .customPrefix:
            let prefix = customPrefix.trimmingCharacters(in: .whitespaces)
            return prefix.isEmpty ? number : "\(prefix)\(separator)\(number)"
        }
    }
}
