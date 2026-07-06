import SwiftUI
import Combine

// MARK: - Theme Type
enum AppThemeType: String, CaseIterable {
    case pink = "Pushti"
    case blue  = "Ko'k"

    var icon: String {
        switch self {
        case .pink: return "heart.fill"
        case .blue:  return "drop.fill"
        }
    }

    var locKey: LKey {
        switch self {
        case .pink: return .themePink
        case .blue:  return .themeBlue
        }
    }
}

// MARK: - AppTheme (ObservableObject — butun app bo'ylab ishlaydi)
class AppTheme: ObservableObject {
    @Published var current: AppThemeType = .pink {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: "app_theme") }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "app_theme") ?? ""
        current = AppThemeType(rawValue: saved) ?? .pink
    }

    // ── Asosiy ranglar ─────────────────────────────────────────────
    var primary: Color {
        switch current {
        case .pink: return Color(hex: "#E05C7A")
        case .blue:  return Color(hex: "#2F80ED")
        }
    }

    var primaryLight: Color {
        switch current {
        case .pink: return Color(hex: "#FADADD")
        case .blue:  return Color(hex: "#D6E8FF")
        }
    }

    var background: Color {
        switch current {
        case .pink: return Color(hex: "#FFF0F2")
        case .blue:  return Color(hex: "#EEF4FF")
        }
    }

    var cardBackground: Color { Color.white }

    var textPrimary: Color   { Color(hex: "#1A1A2E") }
    var textSecondary: Color { Color(hex: "#8A8A9A") }

    var buttonGradient: LinearGradient {
        switch current {
        case .pink:
            return LinearGradient(colors: [Color(hex: "#E05C7A"), Color(hex: "#F48FB1")],
                                  startPoint: .leading, endPoint: .trailing)
        case .blue:
            return LinearGradient(colors: [Color(hex: "#2F80ED"), Color(hex: "#56CCF2")],
                                  startPoint: .leading, endPoint: .trailing)
        }
    }
}

// MARK: - Color hex helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a,r,g,b) = (255,(int>>8)*17,(int>>4&0xF)*17,(int&0xF)*17)
        case 6:  (a,r,g,b) = (255,int>>16,int>>8&0xFF,int&0xFF)
        case 8:  (a,r,g,b) = (int>>24,int>>16&0xFF,int>>8&0xFF,int&0xFF)
        default: (a,r,g,b) = (255,0,0,0)
        }
        self.init(.sRGB,red:Double(r)/255,green:Double(g)/255,blue:Double(b)/255,opacity:Double(a)/255)
    }
}
