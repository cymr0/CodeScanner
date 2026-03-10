//
//  CameraConfiguration.swift
//  https://github.com/twostraws/CodeScanner
//
//  Created for CodeScanner.
//  Copyright © 2024 Paul Hudson. All rights reserved.
//

#if os(iOS)
import AVFoundation

// MARK: - CameraSelection

/// Describes which physical camera the scanner should use.
///
/// Most retail barcode scanning works best with the built-in wide-angle camera,
/// which offers the sharpest focus at typical arm's-length distances. Choose
/// ``ultraWide`` when scanning at very close range, or ``auto`` to let the
/// library pick the best camera for the current device.
public enum CameraSelection: @unchecked Sendable {

    /// The built-in wide-angle camera (back).
    ///
    /// Best choice for 1D retail barcodes (EAN-13, UPC-A, Code 128, etc.)
    /// scanned at a typical arm's-length distance of 15-30 cm.
    case wide

    /// The built-in ultra-wide camera (back).
    ///
    /// Useful for scanning codes at very close range or when a wider field of
    /// view is needed. Falls back to wide-angle if unavailable on the device.
    case ultraWide

    /// Let the library pick the best camera for barcode scanning.
    ///
    /// Currently selects the wide-angle camera, which provides the best
    /// combination of focus distance and resolution for 1D barcodes.
    case auto

    /// Use a caller-supplied capture device.
    ///
    /// - Note: `AVCaptureDevice` is not `Sendable`, which is why
    ///   `CameraSelection` is marked `@unchecked Sendable`. Callers must
    ///   ensure the device is not mutated across isolation boundaries once
    ///   stored here.
    case custom(AVCaptureDevice)
}

// MARK: - CameraConfiguration

/// Camera settings tailored for barcode and QR-code scanning.
///
/// `CameraConfiguration` bundles the most common camera knobs into a single
/// value type that can be passed around safely in Swift 6 concurrency
/// (`Sendable`). Use the ``retail`` preset for a sensible starting point,
/// or create a custom configuration for specialised scanning scenarios.
///
/// ```swift
/// // Use the retail preset (default):
/// let config = CameraConfiguration.retail
///
/// // Or customise:
/// var config = CameraConfiguration.retail
/// config.isTorchEnabled = true
/// config.preferredCamera = .ultraWide
/// ```
public struct CameraConfiguration: @unchecked Sendable {

    // MARK: Properties

    /// Which physical camera to use for scanning.
    ///
    /// Defaults to ``CameraSelection/wide``, which is the best all-round
    /// choice for retail barcode scanning.
    public var preferredCamera: CameraSelection

    /// The focus mode applied to the capture device.
    ///
    /// Defaults to `.continuousAutoFocus`, which keeps the image sharp as
    /// the user moves the device toward or away from the barcode.
    ///
    /// - Note: `AVCaptureDevice.FocusMode` is a plain `Int`-backed enum
    ///   that is safe to copy across isolation boundaries, but does not yet
    ///   carry a formal `Sendable` conformance. This is one of the reasons
    ///   ``CameraConfiguration`` is marked `@unchecked Sendable`.
    public var focusMode: AVCaptureDevice.FocusMode

    /// Whether the scanner should automatically zoom the camera to improve
    /// readability of small barcodes.
    ///
    /// When enabled the library calculates the minimum zoom factor needed to
    /// keep a barcode of ``minimumCodeSize`` millimetres within the camera's
    /// focus range. Defaults to `true`.
    public var isAutoZoomEnabled: Bool

    /// The smallest barcode the auto-zoom algorithm should optimise for,
    /// measured in millimetres.
    ///
    /// A typical retail barcode (EAN-13 / UPC-A) is roughly 25-30 mm wide,
    /// so the default of `20` provides a comfortable margin for slightly
    /// smaller or damaged labels. Only meaningful when ``isAutoZoomEnabled``
    /// is `true`.
    public var minimumCodeSize: Float

    /// Whether the device torch (flashlight) should be turned on during
    /// scanning.
    ///
    /// Useful in dimly-lit environments such as warehouses or stock rooms.
    /// Defaults to `false`.
    public var isTorchEnabled: Bool

    // MARK: Initialiser

    /// Creates a new camera configuration.
    ///
    /// - Parameters:
    ///   - preferredCamera: The camera to use. Defaults to ``CameraSelection/wide``.
    ///   - focusMode: The AVFoundation focus mode. Defaults to `.continuousAutoFocus`.
    ///   - isAutoZoomEnabled: Enable automatic zoom for small codes. Defaults to `true`.
    ///   - minimumCodeSize: Minimum code size in mm for auto-zoom. Defaults to `20`.
    ///   - isTorchEnabled: Turn on the torch during scanning. Defaults to `false`.
    public init(
        preferredCamera: CameraSelection = .wide,
        focusMode: AVCaptureDevice.FocusMode = .continuousAutoFocus,
        isAutoZoomEnabled: Bool = true,
        minimumCodeSize: Float = 20,
        isTorchEnabled: Bool = false
    ) {
        self.preferredCamera = preferredCamera
        self.focusMode = focusMode
        self.isAutoZoomEnabled = isAutoZoomEnabled
        self.minimumCodeSize = minimumCodeSize
        self.isTorchEnabled = isTorchEnabled
    }

    // MARK: Presets

    /// A configuration optimised for retail barcode scanning.
    ///
    /// - Wide-angle back camera for sharp 1D barcode decoding.
    /// - Continuous auto-focus to track the user's hand movement.
    /// - Auto-zoom enabled at 20 mm minimum code size.
    /// - Torch off (most retail environments are well-lit).
    public static let retail = CameraConfiguration(
        preferredCamera: .wide,
        focusMode: .continuousAutoFocus,
        isAutoZoomEnabled: true,
        minimumCodeSize: 20,
        isTorchEnabled: false
    )

    /// The default configuration, identical to ``retail``.
    public static let `default` = retail
}

// MARK: - Device Resolution

extension CameraConfiguration {

    /// Resolves the ``preferredCamera`` selection to a concrete
    /// `AVCaptureDevice`, if one is available on the current hardware.
    ///
    /// Resolution strategy per selection:
    /// - ``CameraSelection/wide``: Discovery session for
    ///   `.builtInWideAngleCamera` in the back position.
    /// - ``CameraSelection/ultraWide``: Discovery session for
    ///   `.builtInUltraWideCamera` in the back position, falling back to
    ///   wide-angle if the ultra-wide is not available.
    /// - ``CameraSelection/auto``: Prefers the wide-angle camera, which
    ///   provides the best focus characteristics for 1D retail barcodes at
    ///   typical arm's-length distance.
    /// - ``CameraSelection/custom(_:)``: Returns the caller-supplied device
    ///   as-is.
    ///
    /// - Returns: An `AVCaptureDevice` ready for use, or `nil` if no
    ///   suitable camera could be found.
    func resolveDevice() -> AVCaptureDevice? {
        switch preferredCamera {
        case .wide:
            return Self.discoveredDevice(type: .builtInWideAngleCamera)

        case .ultraWide:
            return Self.discoveredDevice(type: .builtInUltraWideCamera)
                ?? Self.discoveredDevice(type: .builtInWideAngleCamera)

        case .auto:
            // For barcode scanning the wide-angle lens gives the best
            // combination of resolution and minimum focus distance, making
            // it ideal for 1D codes at typical arm's-length distances.
            return Self.discoveredDevice(type: .builtInWideAngleCamera)

        case .custom(let device):
            return device
        }
    }

    // MARK: Private Helpers

    /// Runs a discovery session for a single device type on the back camera.
    private static func discoveredDevice(
        type: AVCaptureDevice.DeviceType
    ) -> AVCaptureDevice? {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [type],
            mediaType: .video,
            position: .back
        ).devices.first
    }
}
#endif
