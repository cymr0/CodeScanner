//
//  CodeScannerView.swift
//  https://github.com/twostraws/CodeScanner
//
//  Created by Paul Hudson on 14/12/2021.
//  Copyright © 2021 Paul Hudson. All rights reserved.
//

#if os(iOS)
import AVFoundation
import SwiftUI

// MARK: - CodeScannerView

/// A SwiftUI view that wraps a camera-based barcode and QR code scanner.
///
/// `CodeScannerView` bridges UIKit's `AVCaptureSession` machinery into SwiftUI
/// via `UIViewControllerRepresentable`. It is optimised for retail scanning out
/// of the box — the defaults target the most common point-of-sale symbologies
/// (EAN-13, EAN-8, UPC-E, Code 128, Code 39) in continuous-scan mode with a
/// fast 1-second interval.
///
/// ```swift
/// CodeScannerView { result in
///     switch result {
///     case .success(let scan):
///         print("Scanned: \(scan.payload)")
///     case .failure(let error):
///         print("Error: \(error.localizedDescription)")
///     }
/// }
/// ```
public struct CodeScannerView: UIViewControllerRepresentable {

    // MARK: - Stored Properties

    private let codeTypes: [AVMetadataObject.ObjectType]
    private let scanMode: ScanMode
    private let scanInterval: Double
    private let showViewfinder: Bool
    private let requiresPhotoOutput: Bool
    private let shouldVibrateOnSuccess: Bool
    private let cameraConfiguration: CameraConfiguration
    private let isPaused: Bool
    private let isTorchOn: Bool
    private let manualCaptureRequested: Bool
    private let simulatedData: String
    private let completion: @MainActor (Result<ScanResult, ScanError>) -> Void

    // MARK: - Initialiser

    /// Creates a new barcode scanner view.
    ///
    /// The defaults are tuned for retail point-of-sale scanning:
    /// - `codeTypes` covers EAN-13, EAN-8, UPC-E, Code 128, and Code 39.
    /// - `scanMode` is `.continuous` so retail workers can scan many items in
    ///   quick succession.
    /// - `scanInterval` is `1.5` seconds — a comfortable pace for scanning
    ///   items in quick succession.
    /// - `requiresPhotoOutput` is `false` for faster throughput when a captured
    ///   image is not needed.
    ///
    /// - Parameters:
    ///   - codeTypes: The barcode symbologies to detect.
    ///   - scanMode: How the scanner behaves after detecting a code.
    ///   - scanInterval: Minimum seconds between successive scan callbacks in
    ///     continuous modes.
    ///   - showViewfinder: Whether to display a viewfinder overlay.
    ///   - requiresPhotoOutput: Capture a photo alongside each scan result.
    ///   - shouldVibrateOnSuccess: Trigger haptic feedback on a successful scan.
    ///   - cameraConfiguration: Camera hardware settings.
    ///   - isPaused: Temporarily pause scanning without tearing down the session.
    ///   - isTorchOn: Turn the device torch on or off.
    ///   - manualCaptureRequested: Set to `true` to trigger a capture in `.manual`
    ///     scan mode. Toggle back to `false` after the scan fires.
    ///   - simulatedData: Data returned when running in the iOS Simulator.
    ///   - completion: Called on the main actor with each scan result or error.
    public init(
        codeTypes: [AVMetadataObject.ObjectType] = BarcodeType.retail,
        scanMode: ScanMode = .continuous,
        scanInterval: Double = 1.5,
        showViewfinder: Bool = true,
        requiresPhotoOutput: Bool = false,
        shouldVibrateOnSuccess: Bool = true,
        cameraConfiguration: CameraConfiguration = .retail,
        isPaused: Bool = false,
        isTorchOn: Bool = false,
        manualCaptureRequested: Bool = false,
        simulatedData: String = "",
        completion: @escaping @MainActor (Result<ScanResult, ScanError>) -> Void
    ) {
        self.codeTypes = codeTypes
        self.scanMode = scanMode
        self.scanInterval = scanInterval
        self.showViewfinder = showViewfinder
        self.requiresPhotoOutput = requiresPhotoOutput
        self.shouldVibrateOnSuccess = shouldVibrateOnSuccess
        self.cameraConfiguration = cameraConfiguration
        self.isPaused = isPaused
        self.isTorchOn = isTorchOn
        self.manualCaptureRequested = manualCaptureRequested
        self.simulatedData = simulatedData
        self.completion = completion
    }

    // MARK: - UIViewControllerRepresentable

    public func makeUIViewController(context: Context) -> ScannerViewController {
        #if targetEnvironment(simulator)
        return ScannerViewController(
            codeTypes: codeTypes,
            scanMode: scanMode,
            scanInterval: scanInterval,
            showViewfinder: false,
            requiresPhotoOutput: false,
            shouldVibrateOnSuccess: false,
            cameraConfiguration: cameraConfiguration,
            isPaused: isPaused,
            simulatedData: simulatedData,
            completion: completion
        )
        #else
        return ScannerViewController(
            codeTypes: codeTypes,
            scanMode: scanMode,
            scanInterval: scanInterval,
            showViewfinder: showViewfinder,
            requiresPhotoOutput: requiresPhotoOutput,
            shouldVibrateOnSuccess: shouldVibrateOnSuccess,
            cameraConfiguration: cameraConfiguration,
            isPaused: isPaused,
            simulatedData: simulatedData,
            completion: completion
        )
        #endif
    }

    public func updateUIViewController(_ controller: ScannerViewController, context: Context) {
        controller.updatePaused(isPaused)
        controller.updateTorch(isTorchOn)

        if manualCaptureRequested {
            controller.triggerManualCapture()
        }
    }
}

// MARK: - Convenience Initialiser

extension CodeScannerView {

    /// Quick initializer for retail barcode scanning with minimal configuration.
    ///
    /// Uses all retail-optimised defaults — just supply a completion handler:
    ///
    /// ```swift
    /// CodeScannerView { result in
    ///     // handle result
    /// }
    /// ```
    public init(
        onScan: @escaping @MainActor (Result<ScanResult, ScanError>) -> Void
    ) {
        self.init(completion: onScan)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    CodeScannerView { result in
        switch result {
        case .success(let scan):
            print("Scanned: \(scan.payload)")
        case .failure(let error):
            print("Error: \(error.localizedDescription)")
        }
    }
}
#endif

#endif
