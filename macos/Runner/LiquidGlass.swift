import Cocoa
import FlutterMacOS
import SwiftUI

/// Flutter owns navigation/form state; native views own the material and input.
enum LiquidGlassRegistration {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "bugaoshan/liquid_glass", binaryMessenger: registrar.messenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "isSupported" else {
        result(FlutterMethodNotImplemented)
        return
      }
      #if compiler(>=6.2)
      if #available(macOS 26.0, *) { result(true) } else { result(false) }
      #else
      result(false)
      #endif
    }
    for kind in ["dock", "control"] {
      registrar.register(
        GlassViewFactory(messenger: registrar.messenger, kind: kind),
        withId: "bugaoshan/liquid_glass_\(kind)"
      )
    }
  }
}

private final class GlassViewFactory: NSObject, FlutterPlatformViewFactory {
  let messenger: FlutterBinaryMessenger
  let kind: String

  init(messenger: FlutterBinaryMessenger, kind: String) {
    self.messenger = messenger
    self.kind = kind
    super.init()
  }

  func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
    #if compiler(>=6.2)
    if #available(macOS 26.0, *) {
      return GlassPlatformView(
        messenger: messenger, kind: kind, viewId: viewId,
        configuration: args as? [String: Any] ?? [:]
      )
    }
    #endif
    return NSView()
  }
}

#if compiler(>=6.2)
@available(macOS 26.0, *)
private final class GlassModel: ObservableObject {
  @Published var configuration: [String: Any]
  let send: (String, Any?) -> Void
  private var sliderEditing = false

  init(configuration: [String: Any], send: @escaping (String, Any?) -> Void) {
    self.configuration = configuration
    self.send = send
  }

  func string(_ key: String) -> String { configuration[key] as? String ?? "" }
  func bool(_ key: String) -> Bool { configuration[key] as? Bool ?? false }
  func number(_ key: String, fallback: Double) -> Double {
    let value = (configuration[key] as? NSNumber)?.doubleValue ?? fallback
    return value.isFinite ? value : fallback
  }

  func applyControlConfiguration(_ incoming: [String: Any]) {
    var next = incoming
    if sliderEditing && incoming["kind"] as? String == "slider"
        && incoming["enabled"] as? Bool == true {
      // A bridge acknowledgement may be behind the pointer. Keep the system
      // slider's current position until editing ends; still accept theme/range updates.
      let minimum = (incoming["min"] as? NSNumber)?.doubleValue ?? 0
      let maximum = (incoming["max"] as? NSNumber)?.doubleValue ?? 1
      if minimum.isFinite && maximum.isFinite && maximum >= minimum {
        next["value"] = min(maximum, max(minimum, number("value", fallback: minimum)))
      }
    } else {
      sliderEditing = false
    }
    guard !(configuration as NSDictionary).isEqual(to: next) else { return }
    if let value = configuration["value"] as? NSObject, value.isEqual(next["value"]) {
      var transaction = Transaction(animation: nil)
      transaction.disablesAnimations = true
      withTransaction(transaction) { configuration = next }
    } else {
      // External value changes (including a Flutter row tap) reach the system
      // control once. There is no additional glass or SwiftUI value animation.
      configuration = next
    }
  }

  func setSwitchValue(_ value: Bool) {
    guard enabled, value != bool("value") else { return }
    configuration["value"] = value
    send("change", value)
  }

  func setSliderValue(_ value: Double) {
    guard enabled, value.isFinite, value != number("value", fallback: 0) else { return }
    configuration["value"] = value
    send("change", value)
  }

  func setSliderEditing(_ editing: Bool) {
    guard enabled, editing != sliderEditing else { return }
    sliderEditing = editing
    send(editing ? "changeStart" : "changeEnd", number("value", fallback: 0))
  }

  var enabled: Bool { bool("enabled") && !bool("loading") }
  var scale: CGFloat {
    let value = (configuration["textScale"] as? NSNumber)?.doubleValue ?? 1
    return CGFloat(value.isFinite ? min(2, max(1, value)) : 1)
  }
  var tint: Color {
    let value = (configuration["tint"] as? NSNumber)?.uint32Value ?? 0xFF6750A4
    return Color(
      .sRGB, red: Double((value >> 16) & 255) / 255,
      green: Double((value >> 8) & 255) / 255,
      blue: Double(value & 255) / 255, opacity: Double((value >> 24) & 255) / 255
    )
  }
}

@available(macOS 26.0, *)
private final class GlassPlatformView: NSView {
  private let channel: FlutterMethodChannel
  private let model: GlassModel

  init(messenger: FlutterBinaryMessenger, kind: String, viewId: Int64,
       configuration: [String: Any]) {
    let channel = FlutterMethodChannel(
      name: "bugaoshan/liquid_glass_\(kind)/\(viewId)", binaryMessenger: messenger
    )
    self.channel = channel
    model = GlassModel(configuration: configuration) { [weak channel] method, value in
      channel?.invokeMethod(method, arguments: value)
    }
    super.init(frame: .zero)
    let hosting = NSHostingView(rootView: GlassRoot(model: model, dock: kind == "dock"))
    hosting.sizingOptions = []
    hosting.translatesAutoresizingMaskIntoConstraints = false
    addSubview(hosting)
    NSLayoutConstraint.activate([
      hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
      hosting.trailingAnchor.constraint(equalTo: trailingAnchor),
      hosting.topAnchor.constraint(equalTo: topAnchor),
      hosting.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "DISPOSED", message: "Glass view disposed", details: nil))
        return
      }
      guard call.method == "update" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let configuration = call.arguments as? [String: Any] else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected configuration", details: nil))
        return
      }
      if kind == "control" {
        self.model.applyControlConfiguration(configuration)
      } else {
        self.model.configuration = configuration
      }
      result(nil)
    }
  }

  required init?(coder: NSCoder) { nil }
  deinit { channel.setMethodCallHandler(nil) }
}

@available(macOS 26.0, *)
private struct GlassRoot: View {
  @ObservedObject var model: GlassModel
  let dock: Bool

  var body: some View {
    Group {
      if dock { GlassNavigation(model: model) } else { GlassControl(model: model) }
    }
    .tint(model.bool("highContrast") ? .primary : model.tint)
    .environment(\.colorScheme, model.string("brightness") == "dark" ? .dark : .light)
    .environment(\.layoutDirection, model.string("direction") == "rtl" ? .rightToLeft : .leftToRight)
    .transaction { transaction in
      if model.bool("reduceMotion") || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
        transaction.animation = nil
        transaction.disablesAnimations = true
      }
    }
  }
}

@available(macOS 26.0, *)
private struct GlassControl: View {
  @ObservedObject var model: GlassModel

  private var sliderValue: Binding<Double> {
    Binding(
      get: { model.number("value", fallback: 0) },
      set: { model.setSliderValue($0) }
    )
  }

  var body: some View {
    Group {
      if model.string("kind") == "switch" {
        Toggle(model.string("label"), isOn: Binding(
          get: { model.bool("value") },
          set: { model.setSwitchValue($0) }
        ))
        .labelsHidden()
        .toggleStyle(.switch)
        .controlSize(.regular)
      } else if model.string("kind") == "slider" {
        let minimum = model.number("min", fallback: 0)
        let maximum = max(minimum, model.number("max", fallback: 1))
        let divisions = model.number("divisions", fallback: 0)
        if divisions > 0 && maximum > minimum {
          Slider(value: sliderValue, in: minimum...maximum,
                 step: (maximum - minimum) / divisions, onEditingChanged: model.setSliderEditing)
        } else {
          Slider(value: sliderValue, in: minimum...maximum, onEditingChanged: model.setSliderEditing)
        }
      }
    }
    .disabled(!model.enabled)
    .accessibilityLabel(model.string("label"))
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

}

@available(macOS 26.0, *)
private struct GlassNavigation: View {
  @ObservedObject var model: GlassModel
  private var vertical: Bool { model.string("axis") == "vertical" }
  private var items: [[String: Any]] {
    var ids = Set<String>()
    return (model.configuration["items"] as? [[String: Any]] ?? []).filter {
      guard let id = $0["id"] as? String, !id.isEmpty else { return false }
      return ids.insert(id).inserted
    }
  }

  var body: some View {
    Group {
      if vertical {
        List(selection: Binding<String?>(
          get: { model.string("selectedId") },
          set: { id in
            if let id, id != model.string("selectedId") { model.send("select", id) }
          }
        )) {
          ForEach(items, id: \.selfID) { item in
            let selected = item.selfID == model.string("selectedId")
            HStack(spacing: 8 * model.scale) {
              Image(systemName: item[selected ? "selectedSymbol" : "symbol"] as? String ?? "circle")
                .font(.system(size: 15 * model.scale))
                .frame(width: 18 * model.scale)
              Text(item["label"] as? String ?? "")
                .font(.system(size: 13 * model.scale, weight: selected ? .semibold : .regular))
                .lineLimit(1)
              Spacer(minLength: 0)
              if item["badge"] as? Bool == true {
                Circle().fill(.red).frame(width: 6, height: 6).accessibilityHidden(true)
              }
            }
            .frame(minHeight: 24 * model.scale)
            .listRowInsets(EdgeInsets(
              top: 2 * model.scale, leading: 6 * model.scale,
              bottom: 2 * model.scale, trailing: 6 * model.scale
            ))
            .tag(item.selfID)
            .accessibilityValue(item["badge"] as? Bool == true ? item["badgeLabel"] as? String ?? "" : "")
          }
        }
        .listStyle(.sidebar)
        .environment(\.defaultMinListRowHeight, 24 * model.scale)
        .scrollContentBackground(.hidden)
        .padding(.top, 4)
      } else {
        GlassEffectContainer(spacing: 12) {
          ScrollView(.horizontal) {
          HStack(spacing: 12) { destinations }
            .padding(12)
          }
          .scrollIndicators(.hidden)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: vertical ? .top : .center)
  }

  @ViewBuilder private var destinations: some View {
    ForEach(items, id: \.selfID) { item in
      let id = item["id"] as? String ?? ""
      let selected = id == model.string("selectedId")
      if selected {
        destination(item, selected: true).buttonStyle(.glassProminent)
      } else {
        destination(item, selected: false).buttonStyle(.glass).tint(.primary)
      }
    }
  }

  private func destination(_ item: [String: Any], selected: Bool) -> some View {
    let label = item["label"] as? String ?? ""
    let symbol = item[selected ? "selectedSymbol" : "symbol"] as? String ?? "circle"
    let badge = item["badge"] as? Bool ?? false
    return Button {
      guard let id = item["id"] as? String, id != model.string("selectedId") else { return }
      model.send("select", id)
    } label: {
      VStack(spacing: 5) {
        Image(systemName: symbol).font(.system(size: 21 * model.scale))
        Text(label).font(.system(size: 12 * model.scale)).lineLimit(1)
      }
      .frame(width: (vertical ? 104 : 76) * model.scale, height: 54 * model.scale)
      .overlay(alignment: .topTrailing) {
        if badge { Circle().fill(.red).frame(width: 7, height: 7).accessibilityHidden(true) }
      }
    }
    .help(label)
    .accessibilityLabel(label)
    .accessibilityValue(badge ? (item["badgeLabel"] as? String ?? "") : "")
    .accessibilityAddTraits(selected ? [.isSelected] : [])
  }
}

// A stable key survives Flutter reordering and removes duplicate destinations.
private extension Dictionary where Key == String, Value == Any {
  var selfID: String { self["id"] as? String ?? "" }
}
#endif
