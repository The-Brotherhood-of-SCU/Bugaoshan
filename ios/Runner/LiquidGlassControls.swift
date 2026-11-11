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

struct LiquidGlassControlConfiguration {
    enum Kind { case toggle, slider }

    let kind: Kind
    let label: String
    let value: Bool
    let sliderValue: Float
    let minimum: Float
    let maximum: Float
    let divisions: Int?
    let valueLabel: String?
    let enabled: Bool
    let tint: UIColor
    let inactiveTint: UIColor?
    let userInterfaceStyle: UIUserInterfaceStyle
    let reduceMotion: Bool
    let highContrast: Bool
    let direction: UISemanticContentAttribute

    init(arguments: [String: Any]) {
        kind = arguments["kind"] as? String == "slider" ? .slider : .toggle
        label = arguments["label"] as? String ?? ""
        value = arguments["value"] as? Bool ?? false
        let lower = (arguments["min"] as? NSNumber)?.floatValue ?? 0
        let upper = (arguments["max"] as? NSNumber)?.floatValue ?? 1
        minimum = lower.isFinite ? lower : 0
        maximum = upper.isFinite ? max(minimum, upper) : max(minimum, 1)
        let raw = (arguments["value"] as? NSNumber)?.floatValue ?? minimum
        sliderValue = raw.isFinite ? min(maximum, max(minimum, raw)) : minimum
        let steps = (arguments["divisions"] as? NSNumber)?.intValue ?? 0
        divisions = steps > 0 ? steps : nil
        valueLabel = arguments["valueLabel"] as? String
        enabled = (arguments["enabled"] as? Bool ?? true) && (kind != .slider || maximum > minimum)
        tint = Self.color((arguments["tint"] as? NSNumber)?.uint32Value ?? 0xFF6750A4)
        inactiveTint = (arguments["inactiveTint"] as? NSNumber).map { Self.color($0.uint32Value) }
        userInterfaceStyle = arguments["brightness"] as? String == "dark" ? .dark : .light
        reduceMotion = arguments["reduceMotion"] as? Bool ?? false
        highContrast = arguments["highContrast"] as? Bool ?? false
        direction = arguments["direction"] as? String == "rtl" ? .forceRightToLeft : .forceLeftToRight
    }

    private static func color(_ argb: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((argb >> 16) & 0xFF) / 255,
            green: CGFloat((argb >> 8) & 0xFF) / 255,
            blue: CGFloat(argb & 0xFF) / 255,
            alpha: CGFloat((argb >> 24) & 0xFF) / 255
        )
    }

    var animatesUpdates: Bool { !reduceMotion && !UIAccessibility.isReduceMotionEnabled }
}

final class LiquidGlassControlContainer: UIView {
    private var configuration: LiquidGlassControlConfiguration
    private var onEvent: ((String, Any?) -> Void)?
    private var toggle: LiquidGlassSwitch?
    private var slider: UISlider?
    private var applyingConfiguration = false
    private var sliderEditing = false

    init(frame: CGRect, configuration: LiquidGlassControlConfiguration,
         onEvent: @escaping (String, Any?) -> Void) {
        self.configuration = configuration
        self.onEvent = onEvent
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        clipsToBounds = false
        installControl()
        applyConfiguration(animated: false, updateTrack: true)
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        slider?.frame = bounds
        if let toggle {
            let size = toggle.sizeThatFits(bounds.size)
            toggle.frame = CGRect(x: bounds.midX - size.width / 2,
                                  y: bounds.midY - size.height / 2,
                                  width: size.width, height: size.height)
        }
    }

    func update(_ configuration: LiquidGlassControlConfiguration) {
        let previous = self.configuration
        self.configuration = configuration
        let changedKind = previous.kind != configuration.kind
        if changedKind { installControl() }
        let updateTrack = changedKind || previous.minimum != configuration.minimum ||
            previous.maximum != configuration.maximum || previous.divisions != configuration.divisions
        // Only external switch value transitions may animate. Theme updates and
        // rejected changes must not start another transition over UIKit's gesture.
        let animated = !changedKind && previous.value != configuration.value && configuration.animatesUpdates
        applyConfiguration(animated: animated, updateTrack: updateTrack)
        setNeedsLayout()
    }

    func dispose() {
        onEvent = nil
        toggle?.removeTarget(nil, action: nil, for: .allEvents)
        slider?.removeTarget(nil, action: nil, for: .allEvents)
        isUserInteractionEnabled = false
    }

    private func installControl() {
        toggle?.removeTarget(nil, action: nil, for: .allEvents)
        slider?.removeTarget(nil, action: nil, for: .allEvents)
        toggle?.removeFromSuperview()
        slider?.removeFromSuperview()
        toggle = nil
        slider = nil
        sliderEditing = false
        switch configuration.kind {
        case .toggle:
            let toggle = LiquidGlassSwitch()
            toggle.addTarget(self, action: #selector(changeSwitch), for: .valueChanged)
            self.toggle = toggle
            addSubview(toggle)
        case .slider:
            let slider = UISlider()
            slider.isContinuous = true
            slider.addTarget(self, action: #selector(startSlider), for: .touchDown)
            slider.addTarget(self, action: #selector(changeSlider), for: .valueChanged)
            slider.addTarget(self, action: #selector(endSlider), for: [.touchUpInside, .touchUpOutside, .touchCancel])
            self.slider = slider
            addSubview(slider)
        }
    }

    private func applyConfiguration(animated: Bool, updateTrack: Bool) {
        applyingConfiguration = true
        defer { applyingConfiguration = false }
        overrideUserInterfaceStyle = configuration.userInterfaceStyle
        semanticContentAttribute = configuration.direction
        if #available(iOS 17.0, *) {
            traitOverrides.accessibilityContrast = configuration.highContrast ? .high : .normal
        }
        if let toggle {
            toggle.semanticContentAttribute = configuration.direction
            if toggle.onTintColor != configuration.tint { toggle.onTintColor = configuration.tint }
            toggle.accessibilityLabel = configuration.label
            toggle.isEnabled = configuration.enabled
            if toggle.isOn != configuration.value {
                // UIKit already animates native taps/drags. Accepted Flutter
                // echoes match isOn and must never call setOn a second time.
                toggle.setOn(configuration.value, animated: animated)
            }
        }
        if let slider {
            slider.semanticContentAttribute = configuration.direction
            slider.minimumTrackTintColor = configuration.tint
            slider.maximumTrackTintColor = configuration.inactiveTint
            slider.accessibilityLabel = configuration.label
            slider.accessibilityValue = configuration.valueLabel
            slider.isEnabled = configuration.enabled
            if updateTrack {
                slider.minimumValue = configuration.minimum
                slider.maximumValue = configuration.maximum
                #if compiler(>=6.2)
                if #available(iOS 26.0, *) {
                    // Native ticks own snapping and momentum; no extra Flutter
                    // thumb or custom snapping animation layered on the slider.
                    if let divisions = configuration.divisions {
                        slider.trackConfiguration = .init(allowsTickValuesOnly: true, numberOfTicks: divisions + 1)
                    } else {
                        // Explicitly clear tick-only snapping. Assigning nil on
                        // iOS 26 can retain snapping and pin the value to zero.
                        slider.trackConfiguration = .init(allowsTickValuesOnly: false, ticks: [])
                    }
                }
                #endif
            }
            // Do not pull the thumb backward with a delayed Flutter echo while
            // UIKit is tracking. Reconcile the authoritative value after release.
            if !slider.isTracking && slider.value != configuration.sliderValue {
                slider.setValue(configuration.sliderValue, animated: false)
            }
        }
    }

    @objc private func changeSwitch() {
        guard !applyingConfiguration, configuration.enabled, let toggle, toggle.isEnabled else { return }
        onEvent?("change", toggle.isOn)
    }

    @objc private func startSlider() {
        guard configuration.enabled, let slider, slider.isEnabled, !sliderEditing else { return }
        sliderEditing = true
        onEvent?("changeStart", Double(slider.value))
    }

    @objc private func changeSlider() {
        guard !applyingConfiguration, configuration.enabled, let slider, slider.isEnabled else { return }
        // VoiceOver/keyboard changes do not send touchDown/touchUp events.
        let accessibilityEdit = !sliderEditing
        if accessibilityEdit { startSlider() }
        onEvent?("change", Double(slider.value))
        if accessibilityEdit { endSlider() }
    }

    @objc private func endSlider() {
        guard sliderEditing, let slider else { return }
        sliderEditing = false
        onEvent?("changeEnd", Double(slider.value))
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
