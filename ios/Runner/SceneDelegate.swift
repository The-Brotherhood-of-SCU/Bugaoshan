import Flutter
import UIKit

/// Computes the extra top safe-area inset needed when an iPadOS 26+ scene is
/// presented in windowed mode (floating window / Stage Manager / Split View)
/// so the system traffic-light windowing controls do not overlap top-left
/// `AppBar` back buttons or `SafeArea` headers (#426).
enum WindowingSafeAreaCalculator {
    /// Floating-point tolerance when comparing scene and screen bounds.
    static let fullScreenTolerance: CGFloat = 1.0

    /// Returns `true` only on iPad when the scene bounds do not fill the screen.
    static func isWindowed(
        idiom: UIUserInterfaceIdiom,
        sceneBounds: CGRect,
        screenBounds: CGRect
    ) -> Bool {
        guard idiom == .pad else { return false }
        guard
            sceneBounds.width > 0,
            sceneBounds.height > 0,
            screenBounds.width > 0,
            screenBounds.height > 0
        else {
            return false
        }
        let matchesDirect =
            abs(sceneBounds.width - screenBounds.width) <= fullScreenTolerance &&
            abs(sceneBounds.height - screenBounds.height) <= fullScreenTolerance
        let matchesSwapped =
            abs(sceneBounds.width - screenBounds.height) <= fullScreenTolerance &&
            abs(sceneBounds.height - screenBounds.width) <= fullScreenTolerance
        return !(matchesDirect || matchesSwapped)
    }

    /// Computes the additional top safe-area inset to apply on `FlutterViewController`.
    ///
    /// Full-screen scenes always return `0`, even if UIKit retains a non-zero
    /// corner-adapted region after transitioning from windowed back to full-screen.
    static func additionalTopInset(
        isWindowed: Bool,
        baseSafeAreaTop: CGFloat,
        cornerAdaptedSafeAreaTop: CGFloat,
        cornerAdaptedMarginsTop: CGFloat = 0,
        unadaptedMarginsTop: CGFloat = 0
    ) -> CGFloat {
        guard isWindowed else { return 0 }
        let safeAreaDelta = max(0, cornerAdaptedSafeAreaTop - baseSafeAreaTop)
        if safeAreaDelta > 0 {
            return safeAreaDelta
        }
        let marginsCornerHeight = max(0, cornerAdaptedMarginsTop - unadaptedMarginsTop)
        return max(0, marginsCornerHeight - baseSafeAreaTop)
    }
}

/// Hidden child view attached directly to `UIWindow` (outside `FlutterViewController.view`)
/// so it observes raw window safe-area and corner-inset changes without feedback from
/// `FlutterViewController.additionalSafeAreaInsets`.
final class WindowingSafeAreaObserverView: UIView {
    var onUpdate: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isHidden = true
        isUserInteractionEnabled = false
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        onUpdate?()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        onUpdate?()
    }
}

class SceneDelegate: FlutterSceneDelegate {
    private weak var safeAreaObserverView: WindowingSafeAreaObserverView?

    override func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        super.scene(scene, willConnectTo: session, options: connectionOptions)
        installWindowSafeAreaObserverIfNeeded()
        updateWindowingSafeAreaInsets()
    }

    override func sceneDidBecomeActive(_ scene: UIScene) {
        super.sceneDidBecomeActive(scene)
        installWindowSafeAreaObserverIfNeeded()
        updateWindowingSafeAreaInsets()
    }

    override func windowScene(
        _ windowScene: UIWindowScene,
        didUpdate previousCoordinateSpace: UICoordinateSpace,
        interfaceOrientation previousInterfaceOrientation: UIInterfaceOrientation,
        traitCollection previousTraitCollection: UITraitCollection
    ) {
        updateWindowingSafeAreaInsets(for: windowScene)
    }

    #if compiler(>=6.2)
    @available(iOS 26.0, *)
    override func preferredWindowingControlStyle(
        for windowScene: UIWindowScene
    ) -> UIWindowScene.WindowingControlStyle {
        .minimal
    }

    @available(iOS 26.0, *)
    override func windowScene(
        _ windowScene: UIWindowScene,
        didUpdateEffectiveGeometry previousEffectiveGeometry: UIWindowScene.Geometry
    ) {
        updateWindowingSafeAreaInsets(for: windowScene)
    }
    #endif

    func installWindowSafeAreaObserverIfNeeded() {
        guard let window else { return }
        if let existing = safeAreaObserverView, existing.superview === window {
            return
        }
        safeAreaObserverView?.removeFromSuperview()
        let observer = WindowingSafeAreaObserverView(frame: window.bounds)
        observer.onUpdate = { [weak self] in
            self?.updateWindowingSafeAreaInsets()
        }
        window.addSubview(observer)
        safeAreaObserverView = observer
    }

    func updateWindowingSafeAreaInsets(for windowScene: UIWindowScene? = nil) {
        guard
            let window,
            let rootViewController = window.rootViewController
        else {
            return
        }
        let resolvedScene = windowScene ?? window.windowScene
        let extraTop = computeAdditionalTopInset(
            window: window,
            windowScene: resolvedScene,
            referenceView: safeAreaObserverView ?? window
        )
        var current = rootViewController.additionalSafeAreaInsets
        guard abs(current.top - extraTop) > 0.01 else { return }
        current.top = extraTop
        rootViewController.additionalSafeAreaInsets = current
    }

    private func computeAdditionalTopInset(
        window: UIWindow,
        windowScene: UIWindowScene?,
        referenceView: UIView
    ) -> CGFloat {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            let idiom = windowScene?.traitCollection.userInterfaceIdiom
                ?? window.traitCollection.userInterfaceIdiom
            let sceneBounds = windowScene?.effectiveGeometry.coordinateSpace.bounds
                ?? window.bounds
            let screenBounds = windowScene?.screen.bounds ?? window.bounds
            let isWindowed = WindowingSafeAreaCalculator.isWindowed(
                idiom: idiom,
                sceneBounds: sceneBounds,
                screenBounds: screenBounds
            )
            let baseSafeTop = window.safeAreaInsets.top
            let cornerSafeTop = referenceView.edgeInsets(
                for: .safeArea(cornerAdaptation: .vertical)
            ).top
            let cornerMarginsTop = referenceView.edgeInsets(
                for: .margins(cornerAdaptation: .vertical)
            ).top
            let unadaptedMarginsTop = referenceView.edgeInsets(
                for: .margins(cornerAdaptation: .none)
            ).top
            return WindowingSafeAreaCalculator.additionalTopInset(
                isWindowed: isWindowed,
                baseSafeAreaTop: baseSafeTop,
                cornerAdaptedSafeAreaTop: cornerSafeTop,
                cornerAdaptedMarginsTop: cornerMarginsTop,
                unadaptedMarginsTop: unadaptedMarginsTop
            )
        }
        #endif
        return 0
    }
}
