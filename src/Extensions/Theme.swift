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

    /// 暗色内容卡片的轻微提亮，缓和卡片在暗色桌面上的重量，同时保留透底。
    static let darkCardWhiteAlpha: Double = 0.06

    /// macOS 26 及以上暗色主面板的轻微收底，降低 Liquid Glass 透底过强带来的透明感。
    static let darkPanelOverlayAlpha: Double = 0.20

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
        static let lightCardBackground = Color.white
        /// 亮色卡片使用轻量纯白叠加，保留根面板的模糊和桌面色彩透出。
        static let lightCardOpacity: Double = 0.2
        /// 亮色卡片靠更清晰的细边框与主面板区分，暗色沿用原边框。
        static let lightCardBorder = Color.primary.opacity(0.2)
        static let subtlePanelBorder = Color.primary.opacity(0.07)
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
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

    private var isDark: Bool { colorScheme == .dark }
    private var borderColor: Color {
        isDark ? Color.theme.subtlePanelBorder : Color.theme.lightCardBorder
    }

    func body(content: Content) -> some View {
        content
            .background {
                if isDark {
                    // 根面板已经由 AppKit 提供毛玻璃；暗色卡片只保留现有的
                    // 0.06 白色提亮，避免重复材质遮住根面板的透底。
                    Rectangle().fill(Color.white.opacity(SurfaceLift.darkCardWhiteAlpha))
                } else {
                    // 根面板已经由 AppKit 提供毛玻璃；亮色卡片只叠加 tint，避免二次
                    // thinMaterial 取景把桌面色彩抹平。
                    Rectangle().fill(
                        Color.theme.lightCardBackground.opacity(Color.theme.lightCardOpacity)
                    )
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

/// 两套 pill 按钮共用的尺寸与状态量。按下和禁用各只有一个值，避免两套样式各写各的、
/// 同一个状态出现两种视觉重量。
enum ButtonSurface {
    static let cornerRadius: CGFloat = 8
    static let titleFont = Font.system(size: 11, weight: .semibold)

    static let pressedOpacity: Double = 0.75
    static let disabledOpacity: Double = 0.65

    /// 禁用态填充取和次按钮使能态同源的相对 tint。不得借用 `panelBorder`：
    /// 那是描边令牌、alpha 更高，会让禁用按钮比可点的次按钮还重。
    static let disabledFill = Color.theme.panelTint
    static let disabledForeground = Color.theme.textSecondary
}

struct ThemeActionButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ButtonSurface.titleFont)
            .foregroundStyle(
                isEnabled ? Color.theme.actionForeground(for: colorScheme) : ButtonSurface.disabledForeground
            )
            .padding(.horizontal, LayoutSpacing.actionHorizontal)
            .padding(.vertical, LayoutSpacing.actionVertical)
            .background(
                isEnabled ? Color.theme.actionBackground(for: colorScheme) : ButtonSurface.disabledFill,
                in: RoundedRectangle(cornerRadius: ButtonSurface.cornerRadius, style: .continuous)
            )
            .opacity(configuration.isPressed ? ButtonSurface.pressedOpacity : isEnabled ? 1 : ButtonSurface.disabledOpacity)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ThemeSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ButtonSurface.titleFont)
            .foregroundStyle(isEnabled ? Color.theme.textPrimary : ButtonSurface.disabledForeground)
            .padding(.horizontal, LayoutSpacing.actionHorizontal)
            .padding(.vertical, LayoutSpacing.actionVertical)
            .background(
                Color.theme.panelTint,
                in: RoundedRectangle(cornerRadius: ButtonSurface.cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: ButtonSurface.cornerRadius, style: .continuous)
                    .stroke(Color.theme.panelBorder, lineWidth: 0.5)
            }
            .opacity(configuration.isPressed ? ButtonSurface.pressedOpacity : isEnabled ? 1 : ButtonSurface.disabledOpacity)
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
