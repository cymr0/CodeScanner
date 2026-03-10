//
//  BarcodeType.swift
//  https://github.com/twostraws/CodeScanner
//
//  Created by Paul Hudson on 14/12/2021.
//  Copyright © 2021 Paul Hudson. All rights reserved.
//

#if os(iOS)
import AVFoundation

/// A namespace providing preset collections of barcode symbologies for common scanning scenarios.
///
/// Use these presets with `CodeScannerView` to quickly configure which barcode types to detect.
/// Narrowing the set of symbologies improves scanning speed and accuracy, so always prefer
/// the most specific preset that covers your use case.
///
/// ```swift
/// CodeScannerView(codeTypes: BarcodeType.retail) { result in
///     // handle scan
/// }
/// ```
public enum BarcodeType {

    // MARK: - 1D Barcode Presets

    /// The most common retail and point-of-sale barcode symbologies.
    ///
    /// This preset covers approximately 99% of retail products worldwide:
    /// - **EAN-13** — the global standard for product identification.
    /// - **EAN-8** — compact variant of EAN-13 for small packages.
    /// - **UPC-E** — the condensed US product code found on space-constrained packaging.
    /// - **Code 128** — high-density symbology used for shipping labels and internal logistics.
    /// - **Code 39** — alphanumeric symbology widely used for inventory and asset tracking.
    ///
    /// Recommended for retail and POS environments. Limiting detection to these five
    /// symbologies provides optimal scanning speed by avoiding unnecessary decode attempts.
    public static var retail: [AVMetadataObject.ObjectType] {
        [.ean8, .ean13, .upce, .code128, .code39]
    }

    /// Every 1D barcode symbology that AVFoundation supports.
    ///
    /// Includes all symbologies from ``retail`` plus less common formats such as
    /// Code 93, ITF-14, Interleaved 2 of 5, Code 39 mod 43, and Codabar.
    /// Use this when you need to accept any linear barcode regardless of industry.
    public static var allBarcodes: [AVMetadataObject.ObjectType] {
        [
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
    }

    // MARK: - 2D Code Presets

    /// All 2D barcode symbologies supported on iOS 16+.
    ///
    /// Includes QR, PDF 417, Data Matrix, Aztec, Micro QR, and Micro PDF 417.
    /// Use this when scanning tickets, boarding passes, digital IDs, or other
    /// documents that encode data in two-dimensional patterns.
    public static var all2D: [AVMetadataObject.ObjectType] {
        [.qr, .pdf417, .dataMatrix, .aztec, .microQR, .microPDF417]
    }

    // MARK: - Combined Presets

    /// Every barcode and 2D code symbology available — ``allBarcodes`` combined with ``all2D``.
    ///
    /// Use this as a catch-all when you have no control over which symbology the user
    /// will scan. Keep in mind that a wider set of symbologies may slightly reduce
    /// scanning speed compared to a targeted preset like ``retail``.
    public static var all: [AVMetadataObject.ObjectType] {
        allBarcodes + all2D
    }
}
#endif
