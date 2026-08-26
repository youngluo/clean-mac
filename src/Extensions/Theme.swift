import AppKit
import SwiftUI

enum ThemeMode: String, CaseIterable {
    case system
    case light
    case dark

    var localizationKey: L10nKey {
        switch self {
        case .system: return .menuFollowSystem
        case .light: return .menuLight
        case .dark: return .menuDark
        }
    }

    func displayTitle(in locale: Locale) -> String {
        L10n.resolve(localizationKey, locale: locale)
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
        static let panelTint = Color.primary.opacity(0.035)
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
        static let primaryAction = Color(nsColor: .systemBlue)
        static let primaryActionForeground = Color.white

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

struct ThemeActionButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(isEnabled ? Color.theme.actionForeground(for: colorScheme) : Color.theme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                isEnabled ? Color.theme.actionBackground(for: colorScheme) : Color.theme.panelBorder,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.78 : isEnabled ? 1 : 0.7)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ThemeSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(isEnabled ? Color.theme.textPrimary : Color.theme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Color.theme.panelTint,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.theme.panelBorder, lineWidth: 0.5)
            }
            .opacity(configuration.isPressed ? 0.72 : isEnabled ? 1 : 0.65)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct CircleActionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(
                reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.72),
                value: configuration.isPressed
            )
    }
}

struct PointerCursorModifier: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                guard isEnabled, hovering != isHovering else { return }
                isHovering = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .onChange(of: isEnabled) { enabled in
                guard !enabled, isHovering else { return }
                isHovering = false
                NSCursor.pop()
            }
            .onDisappear {
                guard isHovering else { return }
                isHovering = false
                NSCursor.pop()
            }
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = 8) -> some View {
        modifier(GlassPanelModifier(cornerRadius: cornerRadius))
    }

    func pointerCursor() -> some View {
        modifier(PointerCursorModifier())
    }
}
