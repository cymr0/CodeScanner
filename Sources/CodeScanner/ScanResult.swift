//
//  ScanResult.swift
//  https://github.com/twostraws/CodeScanner
//
//  Created by Paul Hudson on 14/12/2021.
//  Copyright © 2021 Paul Hudson. All rights reserved.
//

#if os(iOS)
import AVFoundation
import UIKit

/// The result from a successful scan, containing the decoded payload,
/// the symbology that was detected, corner coordinates of the code
/// in the camera frame, and an optional captured image.
public struct ScanResult: @unchecked Sendable {
    /// The decoded string value of the scanned code.
    public let payload: String

    /// The barcode or 2D-code symbology that was detected.
    public let symbology: AVMetadataObject.ObjectType

    /// The corner coordinates of the detected code in the camera preview.
    public let corners: [CGPoint]

    /// An optional photo of the scanned code captured at the moment of detection.
    ///
    /// `UIImage` is not `Sendable`, which is why `ScanResult` is marked
    /// `@unchecked Sendable`. The image should be treated as a value type
    /// once stored here — do not mutate it across isolation boundaries.
    public let capturedImage: UIImage?
}

// MARK: - Convenience

extension ScanResult {
    /// A set of the common 1D (linear) barcode symbologies.
    private static let oneDimensionalSymbologies: Set<AVMetadataObject.ObjectType> = [
        .ean8,
        .ean13,
        .upce,
        .code128,
        .code39,
        .code93,
        .itf14,
        .interleaved2of5,
        .code39Mod43,
        .codabar
    ]

    /// `true` when the detected symbology is a 1D (linear) barcode rather
    /// than a 2D code such as QR, Data Matrix, or Aztec.
    public var isBarcode: Bool {
        Self.oneDimensionalSymbologies.contains(symbology)
    }
}
#endif
