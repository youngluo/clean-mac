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

enum LayoutSpacing {
    static let popoverInset: CGFloat = 16
    static let heroSection: CGFloat = 22
    static let section: CGFloat = 14
    static let panelHorizontal: CGFloat = 12
    static let panelVertical: CGFloat = 12
    static let headerVertical: CGFloat = 10
    static let fallbackInset: CGFloat = 11
    static let actionHorizontal: CGFloat = 14
    static let actionVertical: CGFloat = 7
    static let anchorTop: CGFloat = 13
    static let hintHorizontal: CGFloat = 9
    static let heroClearance: CGFloat = 8
    static let iconToContent: CGFloat = 9
    static let inline: CGFloat = 7
    static let row: CGFloat = 7
    static let small: CGFloat = 8
    static let tight: CGFloat = 5
    static let micro: CGFloat = 2
    static let textBlock: CGFloat = 3
    static let emptyStateVertical: CGFloat = 18
    static let optical: CGFloat = 1
    static let listGutter: CGFloat = 4
}

extension Color {
    enum theme {
        // 以 App 图标的鼠尾草绿和暖象牙白为品牌锚点，背景继续交给系统材质。
        static let brand = Color(red: 0.369, green: 0.620, blue: 0.435)       // #5E9E6F
        static let accent = Color(nsColor: .systemBlue)
        static let panelTint = Color.primary.opacity(0.05)
        static let glassBase = Color(nsColor: .windowBackgroundColor).opacity(0.68)
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let textTertiary = textSecondary.opacity(0.6)
        static let disabled = textSecondary.opacity(0.35)
        static let panelBorder = textPrimary.opacity(0.10)
        static let button = textPrimary
        static let primary = textPrimary
        static let inProgress = Color(nsColor: .systemBlue)
        static let warning = Color(nsColor: .systemOrange)
        static let success = Color(nsColor: .systemGreen)
        static let failure = Color(nsColor: .systemRed)
        static let primaryAction = Color(red: 0.275, green: 0.498, blue: 0.322) // #467F52
        static let primaryActionForeground = Color(red: 1.0, green: 0.976, blue: 0.933) // #FFF9EE

        static func actionBackground(for _: ColorScheme) -> Color {
            primaryAction
        }

        static func actionForeground(for _: ColorScheme) -> Color {
            primaryActionForeground
        }
    }
}

struct GlassPanelModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(Color.theme.panelTint)
            .background(.regularMaterial)
            .background(Color.theme.glassBase)
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
            .padding(.horizontal, LayoutSpacing.actionHorizontal)
            .padding(.vertical, LayoutSpacing.actionVertical)
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
            .padding(.horizontal, LayoutSpacing.actionHorizontal)
            .padding(.vertical, LayoutSpacing.actionVertical)
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
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(
                reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.78),
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
