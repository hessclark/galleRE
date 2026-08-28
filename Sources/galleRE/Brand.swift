import SwiftUI

/// Brand palette derived from the app icon (blue → violet).
enum Brand {
    static let blue   = Color(red: 96/255,  green: 129/255, blue: 255/255)
    static let violet = Color(red: 124/255, green: 92/255,  blue: 234/255)
    static let indigo = Color(red: 99/255,  green: 70/255,  blue: 220/255)
    static let accent = Color(red: 108/255, green: 82/255,  blue: 226/255)

    static let gradient = LinearGradient(
        colors: [blue, violet, indigo],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    /// Soft horizontal wash for bars/headers.
    static let barWash = LinearGradient(
        colors: [blue.opacity(0.10), violet.opacity(0.10)],
        startPoint: .leading, endPoint: .trailing)
}

extension Color {
    static let brand = Brand.accent
}
