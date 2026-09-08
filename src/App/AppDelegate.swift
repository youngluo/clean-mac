import SwiftUI
import Combine
import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: CleanMacPanel!
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
    private let themeModeKey = "CleanMac.themeMode"
    private let languageStore = LocalizationStore()

    private func loadMenuBarIcon() -> NSImage? {
        let image = NSImage(named: "menubar-icon") ?? NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: "CleanMac")
        image?.isTemplate = true
        return image
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 确保单实例
        let running = NSWorkspace.shared.runningApplications
        for app in running where app.bundleIdentifier == Bundle.main.bundleIdentifier && app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            app.activate(options: [])
            NSApp.terminate(nil)
            return
        }

        applyTheme(themeMode)

        viewModel = CleanerViewModel()
        viewModel.dismissAction = { [weak self] in
            self?.closePanel()
        }

        // 状态栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let iconImage = loadMenuBarIcon() ?? NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: "CleanMac")
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

    private func setupPanel() {
        hostingController = NSHostingController(rootView: makeRootView())
        hostingController.view.wantsLayer = true
        hostingController.view.appearance = NSApp.effectiveAppearance
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor

        panelContentController = PanelContentViewController(hostingController: hostingController)
        panel = CleanMacPanel(
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
        statusItem?.button?.image = loadMenuBarIcon() ?? NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: "CleanMac")
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

private final class CleanMacPanel: NSPanel {
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
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

private final class MenuMaterialView: NSView {
    private let effectView = NSVisualEffectView()
    private let neutralTintView = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 18
        layer?.masksToBounds = true

        effectView.material = .menu
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.translatesAutoresizingMaskIntoConstraints = true
        addSubview(effectView)

        neutralTintView.wantsLayer = true
        neutralTintView.translatesAutoresizingMaskIntoConstraints = true
        addSubview(neutralTintView)
        updateSurfaceColors()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        effectView.frame = bounds
        neutralTintView.frame = bounds
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateSurfaceColors()
    }

    private func updateSurfaceColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            neutralTintView.layer?.backgroundColor = NSColor.windowBackgroundColor
                .withAlphaComponent(0.28)
                .cgColor
            layer?.borderWidth = 0.5
            layer?.borderColor = NSColor.separatorColor
                .withAlphaComponent(0.35)
                .cgColor
        }
    }
}
