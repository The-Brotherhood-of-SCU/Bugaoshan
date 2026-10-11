"""Exercise the actual Swift control model without simulating system animations.

Requires macOS 26+, Xcode 26+, and Flutter's universal macOS framework.
"""

import argparse
from pathlib import Path
import subprocess
import tempfile

SWIFT_TESTS = r'''
import Combine

if #available(macOS 26.0, *) {
  var events: [(String, Any?)] = []
  let toggle = GlassModel(configuration: [
    "kind": "switch", "enabled": true, "value": false, "label": "Switch",
  ]) { events.append(($0, $1)) }
  var publications = 0
  let subscription = toggle.objectWillChange.sink { publications += 1 }
  toggle.setSwitchValue(true)
  assert(toggle.bool("value"), "Native toggle must change before the bridge returns")
  assert(events.count == 1 && events[0].0 == "change")
  let afterTap = publications
  toggle.applyControlConfiguration(toggle.configuration)
  assert(publications == afterTap, "Accepted echo must not restart native state updates")
  toggle.setSwitchValue(true)
  assert(events.count == 1, "Duplicate native input must not replay the callback")
  var external = toggle.configuration
  external["value"] = false
  toggle.applyControlConfiguration(external)
  assert(!toggle.bool("value") && events.count == 1,
         "External row change must update the control without echoing an input event")
  external["enabled"] = false
  toggle.applyControlConfiguration(external)
  toggle.setSwitchValue(true)
  assert(!toggle.bool("value") && events.count == 1, "Disabled toggle must ignore input")
  subscription.cancel()

  events.removeAll()
  let slider = GlassModel(configuration: [
    "kind": "slider", "enabled": true, "value": 0.4, "min": 0.0, "max": 1.0,
  ]) { events.append(($0, $1)) }
  slider.setSliderEditing(true)
  slider.setSliderEditing(true)
  slider.setSliderValue(0.8)
  var stale = slider.configuration
  stale["value"] = 0.4
  stale["label"] = "Updated while dragging"
  slider.applyControlConfiguration(stale)
  assert(slider.number("value", fallback: -1) == 0.8,
         "Delayed Flutter value must not pull the thumb behind the pointer")
  assert(slider.string("label") == "Updated while dragging",
         "Other configuration must remain responsive during dragging")
  slider.setSliderValue(0.9)
  slider.setSliderEditing(false)
  slider.setSliderEditing(false)
  assert(events.map { $0.0 } == ["changeStart", "change", "change", "changeEnd"],
         "One drag must have one start/end pair")
  assert(events.last?.1 as? Double == 0.9)
  stale["value"] = 0.5
  slider.applyControlConfiguration(stale)
  assert(slider.number("value", fallback: -1) == 0.5,
         "After editing, a rejected change must restore the authoritative Flutter value")

  slider.setSliderEditing(true)
  slider.setSliderValue(0.9)
  var resized = slider.configuration
  resized["max"] = 0.6
  resized["value"] = 0.5
  slider.applyControlConfiguration(resized)
  assert(slider.number("value", fallback: -1) == 0.6,
         "An updated range must clamp the current thumb position")
  resized["enabled"] = false
  resized["value"] = 0.3
  slider.applyControlConfiguration(resized)
  let beforeDisabledInput = events.count
  slider.setSliderValue(0.4)
  slider.setSliderValue(.nan)
  slider.setSliderEditing(false)
  assert(events.count == beforeDisabledInput && slider.number("value", fallback: -1) == 0.3,
         "Disabling during a drag must restore parent state and ignore late input")
  print("macOS native control state regressions passed")
} else {
  fatalError("Run these interaction-state regressions on macOS 26 or later")
}
'''


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--framework-dir", type=Path, required=True,
                        help="Directory containing the universal FlutterMacOS.framework")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    framework = args.framework_dir.resolve()
    assert (framework / "FlutterMacOS.framework").is_dir()
    with tempfile.TemporaryDirectory(prefix="bugaoshan-macos-glass-state-") as temporary:
        source = Path(temporary) / "main.swift"
        executable = Path(temporary) / "control-state-test"
        source.write_text((root / "macos/Runner/LiquidGlass.swift").read_text() + SWIFT_TESTS)
        subprocess.run([
            "xcrun", "swiftc", str(source), "-F", str(framework),
            "-framework", "FlutterMacOS", "-Xlinker", "-rpath", "-Xlinker", str(framework),
            "-o", str(executable),
        ], check=True)
        subprocess.run([str(executable)], check=True)
