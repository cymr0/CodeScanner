//
//  ScanError.swift
//  https://github.com/twostraws/CodeScanner
//
//  Created by Paul Hudson on 14/12/2021.
//  Copyright © 2021 Paul Hudson. All rights reserved.
//

#if os(iOS)
import AVFoundation
import Foundation

/// An enum describing the ways CodeScannerView can encounter scanning problems.
public enum ScanError: LocalizedError, Sendable {
    /// The camera hardware is not accessible on this device.
    case cameraUnavailable

    /// The user denied permission to access the camera.
    case cameraPermissionDenied

    /// The system could not create a video input for the capture session.
    case invalidInput

    /// The system could not add a metadata output to the capture session.
    case invalidOutput

    /// The capture session failed during initialization.
    /// Stores the localized description rather than the `Error` itself,
    /// because `Error` does not conform to `Sendable`.
    case initializationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            "Camera hardware is not available on this device."
        case .cameraPermissionDenied:
            "Camera access was denied. Please enable it in Settings."
        case .invalidInput:
            "Failed to create a video input for the camera."
        case .invalidOutput:
            "Failed to add metadata output to the capture session."
        case .initializationFailed(let message):
            "Capture session initialization failed: \(message)"
        }
    }
}
#endif
