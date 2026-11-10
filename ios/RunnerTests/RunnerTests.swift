import ObjectiveC.runtime
import UIKit
import XCTest
@testable import Runner

/// Observe the actual UIKit setters so a Flutter echo cannot silently replay
/// a native animation. These hooks are installed only for one test at a time.
private enum NativeControlProbe {
  static weak var toggle: UISwitch?
  static weak var slider: UISlider?
  static var switchUpdates: [(Bool, Bool)] = []
  static var sliderUpdates: [(Float, Bool)] = []
}

extension UISwitch {
  @objc fileprivate dynamic func bugaoshan_recordSetOn(_ value: Bool, animated: Bool) {
    if self === NativeControlProbe.toggle {
      NativeControlProbe.switchUpdates.append((value, animated))
    }
    bugaoshan_recordSetOn(value, animated: animated)
  }
}

extension UISlider {
  @objc fileprivate dynamic func bugaoshan_recordSetValue(_ value: Float, animated: Bool) {
    if self === NativeControlProbe.slider {
      NativeControlProbe.sliderUpdates.append((value, animated))
    }
    bugaoshan_recordSetValue(value, animated: animated)
  }
}

final class RunnerTests: XCTestCase {
  private func configuration(_ kind: String, _ value: Any,
                             _ additional: [String: Any] = [:]) -> LiquidGlassControlConfiguration {
    var arguments: [String: Any] = ["kind": kind, "value": value, "enabled": true, "label": "Setting"]
    arguments.merge(additional) { _, new in new }
    return LiquidGlassControlConfiguration(arguments: arguments)
  }

  @MainActor
  func testSwitchEchoDoesNotRestartNativeAnimation() throws {
    var changes: [Bool] = []
    let container = LiquidGlassControlContainer(
      frame: CGRect(x: 0, y: 0, width: 64, height: 44),
      configuration: configuration("switch", false),
      onEvent: { method, value in
        if method == "change", let value = value as? Bool { changes.append(value) }
      }
    )
    let toggle = try XCTUnwrap(container.subviews.first as? UISwitch)
    let original = try XCTUnwrap(class_getInstanceMethod(UISwitch.self, #selector(UISwitch.setOn(_:animated:))))
    let recorder = try XCTUnwrap(class_getInstanceMethod(UISwitch.self, #selector(UISwitch.bugaoshan_recordSetOn(_:animated:))))
    method_exchangeImplementations(original, recorder)
    NativeControlProbe.toggle = toggle
    defer {
      method_exchangeImplementations(original, recorder)
      NativeControlProbe.toggle = nil
      NativeControlProbe.switchUpdates = []
      container.dispose()
    }

    // UIKit completes a user's toggle, then Flutter acknowledges the same value.
    toggle.setOn(true, animated: false)
    toggle.sendActions(for: .valueChanged)
    NativeControlProbe.switchUpdates = []
    container.update(configuration("switch", true))
    container.update(configuration("switch", true, ["brightness": "dark"]))
    XCTAssertEqual(changes, [true])
    XCTAssertTrue(NativeControlProbe.switchUpdates.isEmpty)

    // A genuinely external change uses exactly one system transition.
    container.update(configuration("switch", false))
    XCTAssertEqual(NativeControlProbe.switchUpdates.count, 1)
    XCTAssertFalse(NativeControlProbe.switchUpdates[0].0)
    XCTAssertEqual(NativeControlProbe.switchUpdates[0].1, !UIAccessibility.isReduceMotionEnabled)

    // If Flutter declines a user change, restore its value without another animation.
    toggle.setOn(true, animated: false)
    toggle.sendActions(for: .valueChanged)
    NativeControlProbe.switchUpdates = []
    container.update(configuration("switch", false))
    XCTAssertEqual(NativeControlProbe.switchUpdates.count, 1)
    XCTAssertFalse(NativeControlProbe.switchUpdates[0].1)
    XCTAssertFalse(toggle.isOn)
    container.update(configuration("switch", true, ["reduceMotion": true]))
    XCTAssertFalse(NativeControlProbe.switchUpdates.last!.1)
  }

  @MainActor
  func testSliderEchoAndExternalChangesDoNotAddAnimations() throws {
    var events: [String] = []
    let container = LiquidGlassControlContainer(
      frame: CGRect(x: 0, y: 0, width: 280, height: 48),
      configuration: configuration("slider", 0.5),
      onEvent: { method, _ in events.append(method) }
    )
    let slider = try XCTUnwrap(container.subviews.first as? UISlider)
    let original = try XCTUnwrap(class_getInstanceMethod(UISlider.self, #selector(UISlider.setValue(_:animated:))))
    let recorder = try XCTUnwrap(class_getInstanceMethod(UISlider.self, #selector(UISlider.bugaoshan_recordSetValue(_:animated:))))
    method_exchangeImplementations(original, recorder)
    NativeControlProbe.slider = slider
    defer {
      method_exchangeImplementations(original, recorder)
      NativeControlProbe.slider = nil
      NativeControlProbe.sliderUpdates = []
      container.dispose()
    }

    slider.sendActions(for: .touchDown)
    slider.setValue(0.7, animated: false)
    slider.sendActions(for: .valueChanged)
    NativeControlProbe.sliderUpdates = []
    container.update(configuration("slider", 0.7))
    slider.sendActions(for: .touchUpInside)
    XCTAssertEqual(events, ["changeStart", "change", "changeEnd"])
    XCTAssertTrue(NativeControlProbe.sliderUpdates.isEmpty)

    container.update(configuration("slider", 0.2))
    XCTAssertEqual(NativeControlProbe.sliderUpdates.count, 1)
    XCTAssertFalse(NativeControlProbe.sliderUpdates[0].1)
    XCTAssertEqual(slider.value, 0.2, accuracy: 0.000001)
    XCTAssertEqual(events.count, 3, "Programmatic updates must not emit business events")
  }

  @MainActor
  func testSliderTicksRangesAndContinuousFallback() throws {
    guard #available(iOS 26.0, *) else { throw XCTSkip("Native ticks require iOS 26") }
    let container = LiquidGlassControlContainer(
      frame: CGRect(x: 0, y: 0, width: 280, height: 48),
      configuration: configuration("slider", 500.0, ["min": 0.0, "max": 1000.0, "divisions": 20]),
      onEvent: { _, _ in }
    )
    defer { container.dispose() }
    let slider = try XCTUnwrap(container.subviews.first as? UISlider)
    XCTAssertEqual(slider.minimumValue, 0)
    XCTAssertEqual(slider.maximumValue, 1000)
    XCTAssertEqual(slider.value, 500)
    XCTAssertEqual(slider.trackConfiguration?.ticks.count, 21)
    XCTAssertEqual(slider.trackConfiguration?.allowsTickValuesOnly, true)

    container.update(configuration("slider", 14.0, ["min": 8.0, "max": 20.0, "divisions": 12]))
    XCTAssertEqual(slider.minimumValue, 8)
    XCTAssertEqual(slider.maximumValue, 20)
    XCTAssertEqual(slider.value, 14)
    XCTAssertEqual(slider.trackConfiguration?.ticks.count, 13)

    container.update(configuration("slider", 0.35))
    XCTAssertEqual(slider.trackConfiguration?.ticks.count, 0)
    XCTAssertEqual(slider.trackConfiguration?.allowsTickValuesOnly, false)
    XCTAssertEqual(slider.value, 0.35, accuracy: 0.000001)
  }

  @MainActor
  func testSliderAccessibilityDisabledAndDisposedEvents() throws {
    var events: [String] = []
    let container = LiquidGlassControlContainer(
      frame: CGRect(x: 0, y: 0, width: 280, height: 48),
      configuration: configuration("slider", 0.5),
      onEvent: { method, _ in events.append(method) }
    )
    let slider = try XCTUnwrap(container.subviews.first as? UISlider)
    // Keyboard and VoiceOver changes have no touchDown/touchUp sequence.
    slider.setValue(0.6, animated: false)
    slider.sendActions(for: .valueChanged)
    XCTAssertEqual(events, ["changeStart", "change", "changeEnd"])
    XCTAssertEqual(slider.accessibilityLabel, "Setting")
    container.update(configuration("slider", 0.6, ["enabled": false]))
    slider.sendActions(for: .valueChanged)
    XCTAssertFalse(slider.isEnabled)
    XCTAssertEqual(events.count, 3)
    container.dispose()
    slider.sendActions(for: .valueChanged)
    XCTAssertEqual(events.count, 3)
  }

  @MainActor
  func testWindowingSafeAreaCalculatorDistinguishesFullScreenAndWindowedOnIPad() {
    let screen = CGRect(x: 0, y: 0, width: 1024, height: 1366)

    // Full-screen portrait and landscape match screen bounds -> not windowed.
    XCTAssertFalse(
      WindowingSafeAreaCalculator.isWindowed(
        idiom: .pad,
        sceneBounds: screen,
        screenBounds: screen
      )
    )
    XCTAssertFalse(
      WindowingSafeAreaCalculator.isWindowed(
        idiom: .pad,
        sceneBounds: CGRect(x: 0, y: 0, width: 1366, height: 1024),
        screenBounds: screen
      )
    )

    // Floating window and Split View are smaller than screen -> windowed.
    XCTAssertTrue(
      WindowingSafeAreaCalculator.isWindowed(
        idiom: .pad,
        sceneBounds: CGRect(x: 0, y: 0, width: 420, height: 760),
        screenBounds: screen
      )
    )
    XCTAssertTrue(
      WindowingSafeAreaCalculator.isWindowed(
        idiom: .pad,
        sceneBounds: CGRect(x: 0, y: 0, width: 507, height: 1366),
        screenBounds: screen
      )
    )

    // iPhone is never treated as iPad windowed mode.
    XCTAssertFalse(
      WindowingSafeAreaCalculator.isWindowed(
        idiom: .phone,
        sceneBounds: CGRect(x: 0, y: 0, width: 393, height: 852),
        screenBounds: screen
      )
    )
  }

  @MainActor
  func testWindowingSafeAreaCalculatorComputesDeltaAndResetsOnFullScreen() {
    // Floating window with 0 base safe area and 36pt traffic-light vertical adaptation.
    XCTAssertEqual(
      WindowingSafeAreaCalculator.additionalTopInset(
        isWindowed: true,
        baseSafeAreaTop: 0,
        cornerAdaptedSafeAreaTop: 36,
        cornerAdaptedMarginsTop: 44,
        unadaptedMarginsTop: 8
      ),
      36
    )

    // Window partially overlapping status bar (baseSafeAreaTop = 12, corner = 36) -> delta 24.
    XCTAssertEqual(
      WindowingSafeAreaCalculator.additionalTopInset(
        isWindowed: true,
        baseSafeAreaTop: 12,
        cornerAdaptedSafeAreaTop: 36,
        cornerAdaptedMarginsTop: 44,
        unadaptedMarginsTop: 8
      ),
      24
    )

    // Fallback when only margins layout region reports the corner control height.
    XCTAssertEqual(
      WindowingSafeAreaCalculator.additionalTopInset(
        isWindowed: true,
        baseSafeAreaTop: 0,
        cornerAdaptedSafeAreaTop: 0,
        cornerAdaptedMarginsTop: 40,
        unadaptedMarginsTop: 8
      ),
      32
    )

    // Dragging back to full-screen must force 0 even if layout guide retains stale value.
    XCTAssertEqual(
      WindowingSafeAreaCalculator.additionalTopInset(
        isWindowed: false,
        baseSafeAreaTop: 24,
        cornerAdaptedSafeAreaTop: 56,
        cornerAdaptedMarginsTop: 64,
        unadaptedMarginsTop: 8
      ),
      0
    )
  }

  @MainActor
  func testSceneDelegateInstallsObserverAndResetsFullScreenAdditionalSafeArea() {
    let delegate = SceneDelegate()
    let window = UIWindow(frame: UIScreen.main.bounds)
    let rootVC = UIViewController()
    rootVC.additionalSafeAreaInsets = UIEdgeInsets(top: 36, left: 4, bottom: 8, right: 4)
    window.rootViewController = rootVC
    delegate.window = window

    delegate.installWindowSafeAreaObserverIfNeeded()
    let observers = window.subviews.compactMap { $0 as? WindowingSafeAreaObserverView }
    XCTAssertEqual(observers.count, 1)
    XCTAssertTrue(observers[0].isHidden)
    XCTAssertFalse(observers[0].isUserInteractionEnabled)

    // Calling install again is idempotent.
    delegate.installWindowSafeAreaObserverIfNeeded()
    XCTAssertEqual(window.subviews.compactMap { $0 as? WindowingSafeAreaObserverView }.count, 1)

    // Full-screen window resets top additionalSafeAreaInsets to 0 while preserving other edges.
    delegate.updateWindowingSafeAreaInsets()
    XCTAssertEqual(rootVC.additionalSafeAreaInsets.top, 0)
    XCTAssertEqual(rootVC.additionalSafeAreaInsets.left, 4)
    XCTAssertEqual(rootVC.additionalSafeAreaInsets.bottom, 8)
    XCTAssertEqual(rootVC.additionalSafeAreaInsets.right, 4)
  }
}
