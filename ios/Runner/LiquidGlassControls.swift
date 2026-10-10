import Flutter
import UIKit

/// System controls own their glass material, press/drag effects and accessibility.
/// Flutter owns the surrounding form layout, state and fallback for older iOS.
enum LiquidGlassControlsRegistration {
    static func register(with registrar: FlutterApplicationRegistrar) {
        registrar.register(
            LiquidGlassControlFactory(messenger: registrar.messenger()),
            withId: "bugaoshan/liquid_glass_control"
        )
    }
}

private final class LiquidGlassControlFactory: NSObject, FlutterPlatformViewFactory {
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
        LiquidGlassControlPlatformView(
            frame: frame,
            viewId: viewId,
            arguments: args as? [String: Any] ?? [:],
            messenger: messenger
        )
    }
}

private final class LiquidGlassControlPlatformView: NSObject, FlutterPlatformView {
    private let channel: FlutterMethodChannel
    private let container: LiquidGlassControlContainer

    init(frame: CGRect, viewId: Int64, arguments: [String: Any], messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: "bugaoshan/liquid_glass_control/\(viewId)",
            binaryMessenger: messenger
        )
        self.channel = channel
        container = LiquidGlassControlContainer(
            frame: frame,
            configuration: LiquidGlassControlConfiguration(arguments: arguments),
            onEvent: { [weak channel] method, value in
                channel?.invokeMethod(method, arguments: value)
            }
        )
        super.init()
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else {
                result(FlutterError(code: "DISPOSED", message: "Control was disposed", details: nil))
                return
            }
            guard call.method == "update" else {
                result(FlutterMethodNotImplemented)
                return
            }
            guard let arguments = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected control configuration", details: nil))
                return
            }
            self.container.update(LiquidGlassControlConfiguration(arguments: arguments))
            result(nil)
        }
    }

    func view() -> UIView { container }

    deinit {
        channel.setMethodCallHandler(nil)
        container.dispose()
    }
}

private struct LiquidGlassControlConfiguration {
    enum Kind { case button, toggle }

    let kind: Kind
    let label: String
    let symbol: String?
    let value: Bool
    let enabled: Bool
    let loading: Bool
    let prominent: Bool
    let tint: UIColor
    let userInterfaceStyle: UIUserInterfaceStyle
    let reduceMotion: Bool
    let highContrast: Bool
    let textScale: CGFloat
    let direction: UISemanticContentAttribute

    init(arguments: [String: Any]) {
        kind = arguments["kind"] as? String == "switch" ? .toggle : .button
        label = arguments["label"] as? String ?? ""
        symbol = arguments["symbol"] as? String
        value = arguments["value"] as? Bool ?? false
        enabled = arguments["enabled"] as? Bool ?? true
        loading = arguments["loading"] as? Bool ?? false
        prominent = arguments["style"] as? String == "prominent"
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
    }

    var acceptsEvents: Bool { enabled && !loading }
    var animatesUpdates: Bool { !reduceMotion && !UIAccessibility.isReduceMotionEnabled }
}

private final class LiquidGlassControlContainer: UIView {
    private var configuration: LiquidGlassControlConfiguration
    private var onEvent: ((String, Any?) -> Void)?
    private var button: UIButton?
    private var toggle: LiquidGlassSwitch?
    private var applyingConfiguration = false

    init(
        frame: CGRect,
        configuration: LiquidGlassControlConfiguration,
        onEvent: @escaping (String, Any?) -> Void
    ) {
        self.configuration = configuration
        self.onEvent = onEvent
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        clipsToBounds = false
        installControl()
        applyConfiguration(animated: false)
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        button?.frame = bounds
        if let toggle {
            // UISwitch owns its native dimensions, including future OS changes.
            // A 64 x 44 Flutter box gives today's switch room without a transform.
            let size = toggle.sizeThatFits(bounds.size)
            toggle.frame = CGRect(
                x: bounds.midX - size.width / 2,
                y: bounds.midY - size.height / 2,
                width: size.width,
                height: size.height
            )
        }
    }

    func update(_ configuration: LiquidGlassControlConfiguration) {
        let changedKind = self.configuration.kind != configuration.kind
        self.configuration = configuration
        if changedKind { installControl() }
        if configuration.animatesUpdates {
            applyConfiguration(animated: true)
        } else {
            UIView.performWithoutAnimation { applyConfiguration(animated: false) }
        }
        setNeedsLayout()
    }

    func dispose() {
        onEvent = nil
        button?.removeTarget(self, action: nil, for: .allEvents)
        toggle?.removeTarget(self, action: nil, for: .allEvents)
        isUserInteractionEnabled = false
    }

    private func installControl() {
        button?.removeTarget(self, action: nil, for: .allEvents)
        toggle?.removeTarget(self, action: nil, for: .allEvents)
        button?.removeFromSuperview()
        toggle?.removeFromSuperview()
        button = nil
        toggle = nil
        switch configuration.kind {
        case .button:
            let button = UIButton(type: .system)
            button.addTarget(self, action: #selector(activate), for: .primaryActionTriggered)
            self.button = button
            addSubview(button)
        case .toggle:
            let toggle = LiquidGlassSwitch()
            toggle.addTarget(self, action: #selector(change), for: .valueChanged)
            self.toggle = toggle
            addSubview(toggle)
        }
    }

    private func applyConfiguration(animated: Bool) {
        applyingConfiguration = true
        defer { applyingConfiguration = false }
        overrideUserInterfaceStyle = configuration.userInterfaceStyle
        semanticContentAttribute = configuration.direction
        if #available(iOS 17.0, *) {
            traitOverrides.accessibilityContrast = configuration.highContrast ? .high : .normal
        }
        if let button {
            button.semanticContentAttribute = configuration.direction
            button.tintColor = configuration.tint
            button.accessibilityLabel = configuration.label
            button.isEnabled = configuration.acceptsEvents
            var appearance = buttonAppearance()
            appearance.title = configuration.label
            appearance.buttonSize = .large
            appearance.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
            appearance.image = configuration.symbol.flatMap { UIImage(systemName: $0) }
            appearance.imagePlacement = .leading
            appearance.imagePadding = 8
            appearance.showsActivityIndicator = configuration.loading
            if configuration.prominent {
                appearance.baseBackgroundColor = configuration.tint
            } else {
                appearance.baseForegroundColor = configuration.highContrast ? .label : configuration.tint
            }
            // Flutter has already applied its Dynamic Type/text scaling policy.
            // Recompute on every update without multiplying system scaling twice.
            let font = UIFont.systemFont(ofSize: 17 * configuration.textScale, weight: .semibold)
            appearance.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = font
                return attributes
            }
            button.configuration = appearance
        }
        if let toggle {
            toggle.semanticContentAttribute = configuration.direction
            toggle.onTintColor = configuration.tint
            toggle.accessibilityLabel = configuration.label
            // Leave the native On/Off accessibility value and switch traits intact.
            toggle.isEnabled = configuration.acceptsEvents
            if toggle.isOn != configuration.value {
                // Programmatic setOn never sends valueChanged. The guard above
                // also prevents a redundant Flutter echo restarting the drag.
                toggle.setOn(configuration.value, animated: animated)
            }
        }
    }

    private func buttonAppearance() -> UIButton.Configuration {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            return configuration.prominent ? .prominentGlass() : .glass()
        }
        #endif
        return configuration.prominent ? .filled() : .tinted()
    }

    @objc private func activate() {
        guard !applyingConfiguration, configuration.acceptsEvents, button?.isEnabled == true else { return }
        onEvent?("activate", nil)
    }

    @objc private func change() {
        guard !applyingConfiguration, configuration.acceptsEvents, let toggle, toggle.isEnabled else { return }
        onEvent?("change", toggle.isOn)
    }
}

/// Expand the touch area while preserving the system switch's visual geometry.
private final class LiquidGlassSwitch: UISwitch {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard isEnabled else { return false }
        let dx = max(0, (44 - bounds.width) / 2)
        let dy = max(0, (44 - bounds.height) / 2)
        return bounds.insetBy(dx: -dx, dy: -dy).contains(point)
    }
}
