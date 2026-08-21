import SwiftUI

enum ThemeMode: String, CaseIterable {
    case system
    case light
    case dark

    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

extension Color {
    enum theme {
        // 黑白是主题基底，亮蓝只用于图标、进度和状态点缀。
        static let accent = Color(red: 0.20, green: 0.612, blue: 1.0)    // #339CFF
        static let panelTint = accent.opacity(0.04)
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let textTertiary = textSecondary.opacity(0.6)
        static let disabled = textSecondary.opacity(0.35)
        static let panelBorder = textPrimary.opacity(0.10)
        static let button = textPrimary
        static let primary = textPrimary
        static let inProgress = accent
        static let warning = accent
        static let success = Color(red: 0.16, green: 0.68, blue: 0.38)
        static let failure = Color(red: 0.86, green: 0.20, blue: 0.24)

        static func actionBackground(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color.white : Color(red: 0.10, green: 0.11, blue: 0.12)
        }

        static func actionForeground(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color.black : Color.white
        }
    }
}

struct GlassPanelModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(Color.theme.panelTint)
            .background(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.theme.panelBorder, lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = 8) -> some View {
        modifier(GlassPanelModifier(cornerRadius: cornerRadius))
    }
}

// Backward compatibility
typealias Theme = Color.theme
