import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

enum AppColors {
    static let primary = Color(hex: "6366F1")
    static let primaryLight = Color(hex: "818CF8")
    static let primarySoft = Color(hex: "EEF2FF")

    static let background = Color(hex: "FAFAF9")
    static let text = Color(hex: "1C1917")
    static let textSecondary = Color(hex: "78716C")
    static let card = Color.white
    static let border = Color(hex: "E7E5E4")
    static let divider = Color(hex: "F5F5F4")

    static let red = Color(hex: "EF4444")
    static let green = Color(hex: "22C55E")
    static let purple = Color(hex: "A855F7")
    static let orange = Color(hex: "F97316")
    static let blue = Color(hex: "3B82F6")
    static let teal = Color(hex: "14B8A6")

    static func categoryColor(for category: String) -> Color {
        switch category.lowercased() {
        case "vårdkontakter": return primary
        case "anteckningar": return purple
        case "diagnoser": return red
        case "vaccinationer": return green
        case "recept", "läkemedel": return orange
        case "lab", "labresultat": return blue
        case "remisser": return teal
        default: return textSecondary
        }
    }
}
