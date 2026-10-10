import Flutter
import UIKit

/// Native navigation chrome hosted inside Flutter's platform-view composition.
/// The glass samples the native compositor; it does not snapshot Flutter pixels.
enum LiquidGlassDockRegistration {
    static func register(with registrar: FlutterApplicationRegistrar) {
        let messenger = registrar.messenger()
        let channel = FlutterMethodChannel(
            name: "bugaoshan/liquid_glass",
            binaryMessenger: messenger
        )
        channel.setMethodCallHandler { call, result in
            guard call.method == "isSupported" else {
                result(FlutterMethodNotImplemented)
                return
            }
            // Older Xcode SDKs must also be able to build the Flutter fallback.
            #if compiler(>=6.2)
            if #available(iOS 26.0, *) {
                result(true)
            } else {
                result(false)
            }
            #else
            result(false)
            #endif
        }
        registrar.register(
            LiquidGlassDockFactory(messenger: messenger),
            withId: "bugaoshan/liquid_glass_dock"
        )
    }
}

private final class LiquidGlassDockFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        LiquidGlassDockPlatformView(
            frame: frame,
            viewId: viewId,
            arguments: args as? [String: Any] ?? [:],
            messenger: messenger
        )
    }
}

private final class LiquidGlassDockPlatformView: NSObject, FlutterPlatformView {
    private let channel: FlutterMethodChannel
    private let controller: LiquidGlassDockController
    private let container: LiquidGlassDockContainer

    init(
        frame: CGRect,
        viewId: Int64,
        arguments: [String: Any],
        messenger: FlutterBinaryMessenger
    ) {
        let channel = FlutterMethodChannel(
            name: "bugaoshan/liquid_glass_dock/\(viewId)",
            binaryMessenger: messenger
        )
        self.channel = channel
        let controller = LiquidGlassDockController(
            configuration: LiquidGlassDockConfiguration(arguments: arguments),
            onSelect: { [weak channel] id in
                channel?.invokeMethod("select", arguments: id)
            }
        )
        self.controller = controller
        container = LiquidGlassDockContainer(frame: frame, controller: controller)
        super.init()
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else {
                result(FlutterError(code: "DISPOSED", message: "Dock was disposed", details: nil))
                return
            }
            guard call.method == "update" else {
                result(FlutterMethodNotImplemented)
                return
            }
            guard let arguments = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected dock configuration", details: nil))
                return
            }
            self.controller.update(LiquidGlassDockConfiguration(arguments: arguments))
            result(nil)
        }
    }

    func view() -> UIView { container }

    deinit {
        channel.setMethodCallHandler(nil)
        container.dispose()
    }
}

/// Containment follows the platform view's actual responder chain, including
/// removal/reinsertion. No app-window overlay or global root controller is used.
private final class LiquidGlassDockContainer: UIView {
    private var controller: UIViewController?

    init(frame: CGRect, controller: UIViewController) {
        self.controller = controller
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    required init?(coder: NSCoder) { nil }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        synchronizeContainment()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        synchronizeContainment()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        synchronizeContainment()
        controller?.view.frame = bounds
    }

    func dispose() {
        detachController()
        controller = nil
    }

    private func synchronizeContainment() {
        guard let controller else { return }
        guard window != nil, let parent = containingViewController else {
            detachController()
            return
        }
        guard controller.parent !== parent else { return }
        detachController()
        parent.addChild(controller)
        controller.view.frame = bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(controller.view)
        controller.didMove(toParent: parent)
    }

    private var containingViewController: UIViewController? {
        var responder: UIResponder? = next
        while let current = responder {
            if let controller = current as? UIViewController { return controller }
            responder = current.next
        }
        return nil
    }

    private func detachController() {
        guard let controller, controller.parent != nil else { return }
        (controller as? LiquidGlassDockController)?.dismissOverflow()
        controller.willMove(toParent: nil)
        controller.view.removeFromSuperview()
        controller.removeFromParent()
    }
}

private struct LiquidGlassDockItem: Identifiable {
    let id: String
    let label: String
    let symbol: String
    let selectedSymbol: String
    let badge: Bool
    let badgeLabel: String

    init?(arguments: [String: Any]) {
        guard let id = arguments["id"] as? String, !id.isEmpty else { return nil }
        self.id = id
        label = arguments["label"] as? String ?? id
        symbol = arguments["symbol"] as? String ?? "circle"
        selectedSymbol = arguments["selectedSymbol"] as? String ?? symbol
        badge = arguments["badge"] as? Bool ?? false
        badgeLabel = arguments["badgeLabel"] as? String ?? "New activity"
    }
}

private struct LiquidGlassDockConfiguration {
    let items: [LiquidGlassDockItem]
    var selectedId: String
    let tint: UIColor
    let userInterfaceStyle: UIUserInterfaceStyle
    let reduceMotion: Bool
    let highContrast: Bool
    let textScale: CGFloat
    let direction: UISemanticContentAttribute
    let moreLabel: String?
    let cancelLabel: String

    init(arguments: [String: Any]) {
        var ids = Set<String>()
        items = (arguments["items"] as? [[String: Any]] ?? [])
            .compactMap(LiquidGlassDockItem.init)
            .filter { ids.insert($0.id).inserted }
        selectedId = arguments["selectedId"] as? String ?? ""
        let argb = (arguments["tint"] as? NSNumber)?.uint32Value ?? 0xFF6750A4
        tint = UIColor(
            red: CGFloat((argb >> 16) & 0xFF) / 255,
            green: CGFloat((argb >> 8) & 0xFF) / 255,
            blue: CGFloat(argb & 0xFF) / 255,
            alpha: CGFloat((argb >> 24) & 0xFF) / 255
        )
        userInterfaceStyle = arguments["brightness"] as? String == "dark" ? .dark : .light
        reduceMotion = arguments["reduceMotion"] as? Bool ?? false
        highContrast = arguments["highContrast"] as? Bool ?? false
        let scale = (arguments["textScale"] as? NSNumber)?.doubleValue ?? 1
        textScale = CGFloat(scale.isFinite ? min(2, max(1, scale)) : 1)
        direction = arguments["direction"] as? String == "rtl" ? .forceRightToLeft : .forceLeftToRight
        moreLabel = arguments["moreLabel"] as? String
        cancelLabel = arguments["cancelLabel"] as? String ?? "Cancel"
    }

    var contentSizeCategory: UIContentSizeCategory {
        switch textScale {
        case ..<1.1: return .large
        case ..<1.2: return .extraLarge
        case ..<1.3: return .extraExtraLarge
        case ..<1.5: return .extraExtraExtraLarge
        case ..<1.8: return .accessibilityMedium
        default: return .accessibilityLarge
        }
    }
}

/// A system tab controller owns both the Liquid Glass material and the native
/// interactive selection lens. A glassEffect on a custom HStack only supplies a
/// material; it does not provide UITabBar's interaction behavior.
///
/// Flutter still owns page content and selection. Transparent child controllers
/// exist only to give UIKit its normal tab lifecycle; they contain no page UI.
/// Keep the platform view full-width and extended to the bottom edge, including
/// the home-indicator safe area. UIKit computes the tab bar's frame and insets.
private final class LiquidGlassDockController: UITabBarController, UITabBarControllerDelegate {
    private var configuration: LiquidGlassDockConfiguration
    private let onSelect: (String) -> Void
    private var destinations: [String: LiquidGlassDestinationController] = [:]
    private let overflowController = LiquidGlassDestinationController(destinationId: nil)
    private var visibleIDs: [String] = []
    private var lastOverflowId: String?
    private weak var overflowSheet: UIAlertController?

    init(configuration: LiquidGlassDockConfiguration, onSelect: @escaping (String) -> Void) {
        self.configuration = configuration
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.clipsToBounds = false
        delegate = self
        overflowController.tabBarItem = UITabBarItem(tabBarSystemItem: .more, tag: -1)
        // Compact tabs stay at the bottom on iPad as well as iPhone; the
        // surrounding Flutter app retains its own responsive layout traits.
        if #available(iOS 17.0, *) {
            traitOverrides.horizontalSizeClass = .compact
        }
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            tabBarMinimizeBehavior = .never
        }
        #endif
        applyConfiguration(animated: false)
    }

    func update(_ configuration: LiquidGlassDockConfiguration) {
        let oldIDs = self.configuration.items.map(\.id)
        self.configuration = configuration
        if oldIDs != configuration.items.map(\.id) {
            overflowSheet?.dismiss(animated: false)
        }
        guard isViewLoaded else { return }
        applyConfigurationRespectingMotion()
    }

    private func applyConfigurationRespectingMotion() {
        let animated = !configuration.reduceMotion && !UIAccessibility.isReduceMotionEnabled
        if animated {
            applyConfiguration(animated: true)
        } else {
            UIView.performWithoutAnimation { applyConfiguration(animated: false) }
        }
    }

    func dismissOverflow() {
        overflowSheet?.dismiss(animated: false)
    }

    private func applyConfiguration(animated: Bool) {
        overrideUserInterfaceStyle = configuration.userInterfaceStyle
        view.semanticContentAttribute = configuration.direction
        tabBar.semanticContentAttribute = configuration.direction
        // Preserve the system's background, glass and selection appearance.
        // No UITabBarAppearance, custom background, blur or selection image.
        tabBar.tintColor = configuration.highContrast ? .label : configuration.tint
        if #available(iOS 17.0, *) {
            traitOverrides.preferredContentSizeCategory = configuration.contentSizeCategory
            traitOverrides.accessibilityContrast = configuration.highContrast ? .high : .normal
        }

        let validIDs = Set(configuration.items.map(\.id))
        destinations = destinations.filter { validIDs.contains($0.key) }
        for item in configuration.items {
            let controller = destinations[item.id] ?? LiquidGlassDestinationController(destinationId: item.id)
            controller.tabBarItem.title = item.label
            controller.tabBarItem.image = UIImage(systemName: item.symbol)
            controller.tabBarItem.selectedImage = UIImage(systemName: item.selectedSymbol)
            controller.tabBarItem.badgeValue = item.badge ? "" : nil
            controller.tabBarItem.accessibilityLabel = item.label
            controller.tabBarItem.accessibilityValue = item.badge ? item.badgeLabel : nil
            destinations[item.id] = controller
        }

        let items = visibleItems()
        let newIDs = items.map(\.id)
        var controllers: [UIViewController] = items.compactMap { destinations[$0.id] }
        if configuration.items.count > 5 {
            if let label = configuration.moreLabel {
                overflowController.tabBarItem.title = label
            }
            overflowController.tabBarItem.accessibilityLabel = overflowController.tabBarItem.title
            let hiddenBadges = configuration.items.filter { $0.badge && !newIDs.contains($0.id) }
            overflowController.tabBarItem.badgeValue = hiddenBadges.isEmpty ? nil : ""
            overflowController.tabBarItem.accessibilityValue = hiddenBadges.isEmpty ? nil : hiddenBadges.map {
                "\($0.label), \($0.badgeLabel)"
            }.joined(separator: "; ")
            controllers.append(overflowController)
        }
        if newIDs != visibleIDs || controllers.count != viewControllers?.count {
            visibleIDs = newIDs
            setViewControllers(controllers, animated: animated)
            // Reordering already belongs to the Flutter dock settings.
            customizableViewControllers = []
        }
        if let selected = destinations[configuration.selectedId], controllers.contains(where: { $0 === selected }) {
            if selectedViewController !== selected {
                selectedViewController = selected
            }
        }
    }

    /// Never put more than five controllers into the compact system tab bar.
    /// Its built-in More navigation list would be confined to this short native
    /// view. Instead retain three fixed destinations, the current overflow
    /// destination and a More action. Every configured ID remains reachable.
    private func visibleItems() -> [LiquidGlassDockItem] {
        guard configuration.items.count > 5 else { return configuration.items }
        let fixed = Array(configuration.items.prefix(3))
        let overflow = Array(configuration.items.dropFirst(3))
        let current = overflow.first { $0.id == configuration.selectedId }
            ?? overflow.first { $0.id == lastOverflowId }
            ?? overflow[0]
        lastOverflowId = current.id
        return fixed + [current]
    }

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        guard viewController === overflowController else { return true }
        showOverflow()
        return false
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        guard let id = (viewController as? LiquidGlassDestinationController)?.destinationId else { return }
        configuration.selectedId = id
        onSelect(id)
    }

    private func showOverflow() {
        guard view.window != nil, presentedViewController == nil else { return }
        let sheet = UIAlertController(title: configuration.moreLabel, message: nil, preferredStyle: .actionSheet)
        for item in configuration.items.dropFirst(3) {
            let title = item.badge && !item.badgeLabel.isEmpty ? "\(item.label) · \(item.badgeLabel)" : item.label
            sheet.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                guard let self, self.configuration.items.contains(where: { $0.id == item.id }) else { return }
                self.configuration.selectedId = item.id
                self.applyConfigurationRespectingMotion()
                self.onSelect(item.id)
            })
        }
        sheet.addAction(UIAlertAction(title: configuration.cancelLabel, style: .cancel))
        // iOS 26 action sheets use this public source anchor on iPhone too.
        // Anchor the final tab without reaching into UIKit's private subviews.
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = tabBar
            let itemWidth = tabBar.bounds.width / CGFloat(max(1, viewControllers?.count ?? 1))
            let x = configuration.direction == .forceRightToLeft ? 0 : tabBar.bounds.width - itemWidth
            popover.sourceRect = CGRect(x: x, y: 0, width: itemWidth, height: tabBar.bounds.height)
        }
        overflowSheet = sheet
        present(sheet, animated: !configuration.reduceMotion && !UIAccessibility.isReduceMotionEnabled)
    }
}

private final class LiquidGlassDestinationController: UIViewController {
    let destinationId: String?

    init(destinationId: String?) {
        self.destinationId = destinationId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let transparentView = UIView()
        transparentView.backgroundColor = .clear
        transparentView.isOpaque = false
        transparentView.isUserInteractionEnabled = false
        view = transparentView
    }
}
