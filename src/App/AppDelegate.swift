import SwiftUI
import Combine
import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: SpotlessPanel!
    private var hostingController: NSHostingController<AnyView>!
    private var panelContentController: PanelContentViewController!
    private var viewModel: CleanerViewModel!
    private var iconTimer: Timer?
    private var angle: CGFloat = 0
    private var cancellable: AnyCancellable?
    private var panelAnimationCancellable: AnyCancellable?
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var keepsPanelOpenDuringCleaning = false
    private let panelLayoutState = PanelLayoutState()
    private var lastAvailablePanelHeight: CGFloat?
    private let themeModeKey = "Spotless.themeMode"
    private let panelWhiteLiftKey = "Spotless.panelWhiteLift"
    private let panelCoolnessKey = "Spotless.panelCool"
    private let languageStore = LocalizationStore()

    private func loadMenuBarIcon() -> NSImage? {
        let image = NSImage(named: "menubar-icon") ?? NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: "Spotless")
        image?.isTemplate = true
        return image
    }

    private var isRunningUnderTest: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 确保单实例；XCTest 宿主进程跳过，否则守卫会把测试 runner 启动即终止
        if !isRunningUnderTest {
            let running = NSWorkspace.shared.runningApplications
            for app in running where app.bundleIdentifier == Bundle.main.bundleIdentifier && app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                app.activate(options: [])
                NSApp.terminate(nil)
                return
            }
        }

        applyTheme(themeMode)

        applySurfaceLiftFromDefaults()

        viewModel = CleanerViewModel()
        viewModel.dismissAction = { [weak self] in
            self?.closePanel()
        }

        // 状态栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let iconImage = loadMenuBarIcon() ?? NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: "Spotless")
            button.image = iconImage
            button.action = #selector(togglePanel)
            button.target = self

            // 启用右键点击
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        setupPanel()

        // 监听 isCleaning 状态控制图标旋转
        cancellable = viewModel.$isCleaning
            .receive(on: RunLoop.main)
            .sink { [weak self] cleaning in
                guard let self else { return }
                self.keepsPanelOpenDuringCleaning = cleaning
                if cleaning {
                    self.startIconRotation()
                } else {
                    self.stopIconRotation()
                }
            }

        panelAnimationCancellable = viewModel.$appState
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.panelLayoutState.resetCandidateReviewHeight()
                self?.lastAvailablePanelHeight = nil
                self?.schedulePanelResize()
            }
    }

    // MARK: - 右键菜单

    private func showRightClickMenu() {
        let menu = NSMenu()
        menu.minimumWidth = 180

        let themeItem = NSMenuItem(title: L10n.resolve(.menuTheme, locale: languageStore.locale), action: nil, keyEquivalent: "")
        let themeMenu = NSMenu(title: L10n.resolve(.menuTheme, locale: languageStore.locale))
        for mode in ThemeMode.allCases {
            let item = NSMenuItem(title: mode.displayTitle(in: languageStore.locale), action: #selector(changeTheme(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = mode == themeMode ? .on : .off
            themeMenu.addItem(item)
        }
        themeItem.submenu = themeMenu
        menu.addItem(themeItem)

        let languageItem = NSMenuItem(title: L10n.resolve(.menuLanguage, locale: languageStore.locale), action: nil, keyEquivalent: "")
        let languageMenu = NSMenu(title: L10n.resolve(.menuLanguage, locale: languageStore.locale))
        let canChangeLanguage = viewModel?.appState == .idle
        for language in AppLanguage.allCases {
            let item = NSMenuItem(title: language.displayTitle(in: languageStore.locale), action: #selector(changeLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = language.rawValue
            item.state = language == languageStore.selectedLanguage ? .on : .off
            item.isEnabled = canChangeLanguage
            languageMenu.addItem(item)
        }
        languageItem.submenu = languageMenu
        languageItem.isEnabled = canChangeLanguage
        menu.addItem(languageItem)
        menu.addItem(NSMenuItem.separator())

        let exitItem = NSMenuItem(title: L10n.resolve(.menuQuit, locale: languageStore.locale), action: #selector(exitApp), keyEquivalent: "q")
        exitItem.target = self
        exitItem.keyEquivalentModifierMask = .command
        menu.addItem(exitItem)

        guard let button = statusItem.button,
              let window = button.window else { return }
        
        // 获取按钮在屏幕上的位置
        var buttonFrameInScreen = button.convert(button.bounds, to: nil)
        buttonFrameInScreen = window.convertToScreen(buttonFrameInScreen)
        
        // 菜单定位点：按钮左下角往下 10 像素
        let menuLocation = NSPoint(x: buttonFrameInScreen.minX, y: buttonFrameInScreen.minY - 10)
        
        menu.popUp(positioning: nil, at: menuLocation, in: nil)
    }

    /// 提亮比例可由 `Spotless.panelWhiteLift`（0...1）覆盖；每次开面板时重读，改完数值不必重新编译
    private func applySurfaceLiftFromDefaults() {
        if let stored = UserDefaults.standard.object(forKey: panelWhiteLiftKey) as? Double {
            SurfaceLift.whiteAlpha = min(max(stored, 0), 1)
        }
        if let stored = UserDefaults.standard.object(forKey: panelCoolnessKey) as? Double {
            SurfaceLift.coolness = min(max(stored, 0), 1)
        }
        panelContentController?.materialView.whiteLiftAlpha = CGFloat(SurfaceLift.whiteAlpha)
    }

    private var themeMode: ThemeMode {
        guard let rawValue = UserDefaults.standard.string(forKey: themeModeKey),
              let mode = ThemeMode(rawValue: rawValue) else { return .system }
        return mode
    }

    private func applyTheme(_ mode: ThemeMode) {
        let appearance: NSAppearance?
        switch mode {
        case .system:
            appearance = nil
        case .light:
            appearance = NSAppearance(named: .aqua)
        case .dark:
            appearance = NSAppearance(named: .darkAqua)
        }
        NSApp.appearance = appearance
        let effectiveAppearance = NSApp.effectiveAppearance
        panel?.appearance = effectiveAppearance
        if hostingController != nil {
            hostingController.rootView = makeRootView()
            hostingController.view.appearance = effectiveAppearance
        }
        if let panel {
            panel.appearance = effectiveAppearance
            panelContentController?.view.appearance = effectiveAppearance
            panelContentController?.materialView.appearance = effectiveAppearance
            schedulePanelResize()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        viewModel?.refreshDiskAccessStatus()
    }

    private func setupPanel() {
        hostingController = NSHostingController(rootView: makeRootView())
        hostingController.view.wantsLayer = true
        hostingController.view.appearance = NSApp.effectiveAppearance
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor

        panelContentController = PanelContentViewController(hostingController: hostingController)
        panel = SpotlessPanel(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )
        panel.contentViewController = panelContentController
        panel.appearance = NSApp.effectiveAppearance
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        resizePanelToContent()
    }

    private func resizePanelToContent() {
        guard let panel, let contentView = panel.contentView else { return }
        let availableHeight = availablePanelHeight()

        if let availableHeight {
            if let lastAvailablePanelHeight,
               abs(lastAvailablePanelHeight - availableHeight) > 1 {
                panelLayoutState.resetCandidateReviewHeight()
            }
            lastAvailablePanelHeight = availableHeight
        }

        contentView.layoutSubtreeIfNeeded()
        let fittingSize = contentView.fittingSize
        guard fittingSize.height > 0 else { return }

        if let availableHeight,
           fittingSize.height > availableHeight + 1 {
            let currentHeight = panelLayoutState.candidateReviewMaximumHeight
            let adjustedHeight = max(
                PanelLayoutState.minimumCandidateReviewMaximumHeight,
                currentHeight - (fittingSize.height - availableHeight)
            )
            if adjustedHeight < currentHeight - 1 {
                panelLayoutState.candidateReviewMaximumHeight = adjustedHeight
                DispatchQueue.main.async { [weak self] in
                    self?.resizePanelToContent()
                }
                return
            }
        }

        if let availableHeight {
            let height = min(fittingSize.height, availableHeight)
            setPanelContentSize(NSSize(width: 360, height: height), on: panel)
            return
        }

        setPanelContentSize(NSSize(width: 360, height: fittingSize.height), on: panel)
    }

    private func setPanelContentSize(_ size: NSSize, on panel: NSPanel) {
        let topEdge = panel.frame.maxY
        panel.setContentSize(size)
        if panel.isVisible {
            panel.setFrameOrigin(NSPoint(x: panel.frame.origin.x, y: topEdge - size.height))
        }
    }

    private func schedulePanelResize() {
        DispatchQueue.main.async { [weak self] in
            self?.resizePanelToContent()
        }
    }

    private func availablePanelHeight() -> CGFloat? {
        guard let button = statusItem?.button,
              let buttonWindow = button.window,
              let screen = buttonWindow.screen ?? NSScreen.main else { return nil }

        let buttonFrame = button.convert(button.bounds, to: nil)
        let buttonFrameOnScreen = buttonWindow.convertToScreen(buttonFrame)
        return max(0, buttonFrameOnScreen.minY - screen.visibleFrame.minY - 8)
    }

    private func configurePanelWindow(_ window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        hostingController?.view.wantsLayer = true
        hostingController?.view.layer?.backgroundColor = NSColor.clear.cgColor
    }

    private func makeRootView() -> AnyView {
        AnyView(
            MenuBarView(
                viewModel: viewModel,
                languageStore: languageStore
            )
                .preferredColorScheme(themeMode.colorScheme)
                .environmentObject(panelLayoutState)
        )
    }

    @objc private func changeTheme(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = ThemeMode(rawValue: rawValue) else { return }
        UserDefaults.standard.set(mode.rawValue, forKey: themeModeKey)
        applyTheme(mode)
    }

    @objc private func changeLanguage(_ sender: NSMenuItem) {
        guard viewModel?.appState == .idle,
              let rawValue = sender.representedObject as? String,
              let language = AppLanguage(rawValue: rawValue) else { return }
        languageStore.selectedLanguage = language
    }

    @objc private func exitApp() {
        closePanel()
        NSApp.terminate(nil)
    }

    // MARK: - 左键面板控制

    @objc private func togglePanel() {
        guard statusItem.button != nil else { return }

        // 检测右键点击
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showRightClickMenu()
            return
        }

        // 左键行为
        if panel.isVisible {
            closePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let button = statusItem.button,
              let buttonWindow = button.window,
              let panel else { return }

        applySurfaceLiftFromDefaults()
        viewModel.refreshDiskAccessStatus()
        viewModel.refreshAvailableDiskSpace()
        panelLayoutState.resetCandidateReviewHeight()
        lastAvailablePanelHeight = nil
        resizePanelToContent()

        let buttonFrame = button.convert(button.bounds, to: nil)
        let buttonFrameOnScreen = buttonWindow.convertToScreen(buttonFrame)
        let visibleFrame = buttonWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let panelSize = panel.frame.size

        let proposedX = buttonFrameOnScreen.midX - panelSize.width / 2
        let x = min(
            max(proposedX, visibleFrame.minX + 8),
            visibleFrame.maxX - panelSize.width - 8
        )
        let y = max(buttonFrameOnScreen.minY - panelSize.height - 8, visibleFrame.minY + 8)

        panel.setFrameOrigin(NSPoint(x: x, y: y))
        configurePanelWindow(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        installPanelEventMonitors()
        button.highlight(true)
    }

    private func closePanel() {
        panel?.orderOut(nil)
        removePanelEventMonitors()
        statusItem?.button?.highlight(false)
    }

    private func installPanelEventMonitors() {
        guard localEventMonitor == nil, globalEventMonitor == nil else { return }

        let eventMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown]
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: eventMask) { [weak self] event in
            guard let self, let panel = self.panel, panel.isVisible else { return event }
            let screenPoint = NSEvent.mouseLocation
            guard panel.frame.contains(screenPoint) || self.isStatusItem(at: screenPoint) else {
                if !self.keepsPanelOpenDuringCleaning {
                    self.closePanel()
                }
                return event
            }
            return event
        }

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] _ in
            Task { @MainActor in
                guard let self, let panel = self.panel, panel.isVisible else { return }
                let screenPoint = NSEvent.mouseLocation
                guard panel.frame.contains(screenPoint) || self.isStatusItem(at: screenPoint) else {
                    if !self.keepsPanelOpenDuringCleaning {
                        self.closePanel()
                    }
                    return
                }
            }
        }
    }

    private func removePanelEventMonitors() {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }
    }

    private func isStatusItem(at screenPoint: NSPoint) -> Bool {
        guard let button = statusItem?.button,
              let window = button.window else { return false }
        let buttonFrame = button.convert(button.bounds, to: nil)
        let buttonFrameOnScreen = window.convertToScreen(buttonFrame)
        return buttonFrameOnScreen.contains(screenPoint)
    }

    // MARK: - 菜单栏图标旋转动画

    private func startIconRotation() {
        angle = 0
        iconTimer?.invalidate()
        iconTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateRotatingIcon()
            }
        }
    }

    private func stopIconRotation() {
        iconTimer?.invalidate()
        iconTimer = nil
        angle = 0
        statusItem?.button?.image = loadMenuBarIcon() ?? NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: "Spotless")
    }

    private func updateRotatingIcon() {
        angle += 12
        if angle >= 360 { angle -= 360 }
        guard let button = statusItem?.button else { return }
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        guard let base = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return }
        let size = base.size
        let rotated = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.translateBy(x: size.width / 2, y: size.height / 2)
            ctx.rotate(by: self.angle * .pi / 180)
            ctx.translateBy(x: -size.width / 2, y: -size.height / 2)
            base.draw(in: rect)
            return true
        }
        rotated.isTemplate = true
        button.image = rotated
    }
}

private final class SpotlessPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class PanelContentViewController: NSViewController {
    let hostingController: NSHostingController<AnyView>
    let materialView = MenuMaterialView()

    init(hostingController: NSHostingController<AnyView>) {
        self.hostingController = hostingController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = materialView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(hostingController)
        materialView.embedContent(hostingController.view)
    }
}

private final class MenuMaterialView: NSView {
    var whiteLiftAlpha = CGFloat(SurfaceLift.whiteAlpha) {
        didSet { updateSurfaceColors() }
    }
    private static let cornerRadius: CGFloat = 18
    /// 内侧亮边：macOS 菜单在近白背景上靠这道高光维持轮廓，只有外侧暗线会显得平
    private static let rimInset: CGFloat = 1
    private static let rimWidth: CGFloat = 0.5
    private static let rimAlpha: CGFloat = 0.45
    /// 外侧描边：暗色沿用原标定；亮色按实际观感继续收细，比系统菜单实测值更轻
    private static let borderAlphaLight: CGFloat = 0.05
    private static let borderAlphaDark: CGFloat = 0.35

    private let effectView = NSVisualEffectView()
    private let whiteLiftView = NSView()
    private let rimView = NSView()

    /// macOS 26 起系统菜单由 Liquid Glass 渲染，直接复用系统组件
    private var glassView: NSView?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // 圆角遮罩与焦点环必须在两条路径都设：
        // 缺圆角遮罩时内容视图的图层是方角矩形，系统的窗口阴影会按方形算，贴着窗口边界画出一圈方角暗线
        wantsLayer = true
        layer?.cornerRadius = Self.cornerRadius
        layer?.masksToBounds = true
        focusRingType = .none

        if #available(macOS 26.0, *) {
            // 玻璃只当背景；内容仍以约束贴在表面上——交给玻璃的 contentView 会破坏尺寸向上传递的链条
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.cornerRadius = Self.cornerRadius
            glass.focusRingType = .none
            glass.translatesAutoresizingMaskIntoConstraints = true
            addSubview(glass)
            glassView = glass
            updateSurfaceColors()
            return
        }

        // 与 App 自身右键菜单同族材质，面板表面和菜单保持一致
        effectView.material = .menu
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.translatesAutoresizingMaskIntoConstraints = true
        addSubview(effectView)

        whiteLiftView.wantsLayer = true
        whiteLiftView.translatesAutoresizingMaskIntoConstraints = true
        addSubview(whiteLiftView)

        rimView.wantsLayer = true
        rimView.translatesAutoresizingMaskIntoConstraints = true
        addSubview(rimView)

        updateSurfaceColors()
    }

    /// 内容始终以约束贴在表面上：面板高度由内容的自适应尺寸向上传递，这是本项目原有且可靠的链条。
    /// 不要交给玻璃的 contentView 托管——那样内容尺寸会被窗口尺寸钉住，状态变化时面板无法变高。
    func embedContent(_ content: NSView) {
        content.focusRingType = .none
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.topAnchor.constraint(equalTo: topAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        glassView?.frame = bounds
        effectView.frame = bounds
        whiteLiftView.frame = bounds
        rimView.frame = bounds.insetBy(dx: Self.rimInset, dy: Self.rimInset)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateSurfaceColors()
    }

    private func updateSurfaceColors() {
        // 玻璃路径下表面与边缘由系统承担，只保留圆角遮罩
        guard glassView == nil else { return }
        effectiveAppearance.performAsCurrentDrawingAppearance {
            // 纯白提亮只在亮色下叠加；暗色下加白会冲淡系统材质本身的表面层级
            let isDarkAppearance = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            whiteLiftView.layer?.backgroundColor = SurfaceLift.liftColor
                .withAlphaComponent(isDarkAppearance ? 0 : whiteLiftAlpha)
                .cgColor
            rimView.layer?.cornerRadius = Self.cornerRadius - Self.rimInset
            rimView.layer?.borderWidth = Self.rimWidth
            rimView.layer?.borderColor = NSColor.white
                .withAlphaComponent(isDarkAppearance ? 0 : Self.rimAlpha)
                .cgColor
            layer?.borderWidth = 0.5
            layer?.borderColor = NSColor.separatorColor
                .withAlphaComponent(isDarkAppearance ? Self.borderAlphaDark : Self.borderAlphaLight)
                .cgColor
        }
    }
}
