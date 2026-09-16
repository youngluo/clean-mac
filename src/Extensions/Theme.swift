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

enum SurfaceLift {
    /// 亮色外观下把系统材质往白推的提亮比例，取 0...1。根背景与内容卡片共用同一个值，
    /// 否则根背景单独提亮时，卡片会相对于面板表面读成灰块。
    /// 启动与每次开面板时可被 `Spotless.panelWhiteLift` 覆盖。
    static var whiteAlpha: Double = 0.45

    /// 提亮层的冷色倾向，取 0...1。0 是纯白中和（面板颜色随背景走），1 是明显冷白（面板有固定色相）。
    /// 面板与白色背景的明暗差上限只有约 9 个色阶，色相是白底上唯一还够用的区分维度。
    /// 可被 `Spotless.panelCool` 覆盖。
    static var coolness: Double = 0.6

    /// 冷白目标；对其与纯白做线性插值得出实际提亮色
    private static let coolTarget = (r: 0.898, g: 0.933, b: 0.984)

    static var liftColor: NSColor {
        let t = min(max(coolness, 0), 1)
        return NSColor(
            srgbRed: 1 + (coolTarget.r - 1) * t,
            green: 1 + (coolTarget.g - 1) * t,
            blue: 1 + (coolTarget.b - 1) * t,
            alpha: 1
        )
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
        // 以清爽的青绿色为品牌锚点，面板背景交给 macOS 系统材质。
        static let brand = Color(red: 0.247, green: 0.655, blue: 0.588)       // #3FA796
        static let accent = brand
        static let auxiliary = Color(red: 0.910, green: 0.851, blue: 0.710)   // #E8D9B5
        static let panelTint = Color.primary.opacity(0.05)
        static let subtlePanelBorder = Color.primary.opacity(0.07)
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let textTertiary = textSecondary.opacity(0.6)
        static let disabled = textSecondary.opacity(0.35)
        static let panelBorder = textPrimary.opacity(0.10)
        static let button = textPrimary
        static let primary = textPrimary
        static let inProgress = brand
        static let success = brand
        static let failure = Color(red: 0.651, green: 0.361, blue: 0.345)    // #A65C58
        static let primaryAction = brand
        static let primaryActionForeground = Color.white // #FFFFFF

        static func actionBackground(for _: ColorScheme) -> Color {
            primaryAction
        }

        static func actionForeground(for _: ColorScheme) -> Color {
            primaryActionForeground
        }
    }
}

struct SubtleGlassPanelModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat

    /// macOS 26 起面板表面由系统玻璃承担，内容卡片无需再提白
    private var liftOpacity: Double {
        if #available(macOS 26.0, *) { return 0 }
        return colorScheme == .dark ? 0 : SurfaceLift.whiteAlpha
    }

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    Rectangle().fill(.thinMaterial)
                    Rectangle().fill(
                        Color(nsColor: SurfaceLift.liftColor).opacity(liftOpacity)
                    )
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.theme.subtlePanelBorder, lineWidth: 0.5)
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
    func subtleGlassPanel(cornerRadius: CGFloat = 8) -> some View {
        modifier(SubtleGlassPanelModifier(cornerRadius: cornerRadius))
    }

    func pointerCursor() -> some View {
        modifier(PointerCursorModifier())
    }
}
