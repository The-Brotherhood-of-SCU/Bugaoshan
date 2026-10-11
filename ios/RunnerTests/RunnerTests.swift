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
}
