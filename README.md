# CodeScanner

<p>
    <img src="https://img.shields.io/badge/iOS-16.0+-blue.svg" />
    <img src="https://img.shields.io/badge/Swift-6.0-ff69b4.svg" />
</p>

CodeScanner is a modern SwiftUI library for scanning barcodes and QR codes. It is **optimised for retail barcode scanning** out of the box, with sensible defaults that cover EAN-13, EAN-8, UPC-E, Code 128, and Code 39 — the symbologies found on virtually every retail product worldwide.

Originally forked from [twostraws/CodeScanner](https://github.com/twostraws/CodeScanner), then modernised with Swift 6 concurrency, `Sendable` types, `@MainActor` isolation, and retail-focused defaults.

## Features

- Retail-optimised defaults (EAN-13, UPC, Code 128, Code 39)
- Swift 6 strict concurrency throughout
- `@MainActor`-isolated view controller with off-main-thread capture session setup
- Auto-zoom for small barcode readability
- Tap-to-focus for precise targeting
- Continuous scanning mode for high-throughput retail workflows
- Code-drawn viewfinder overlay (no image assets required)
- Preset barcode type collections (`BarcodeType.retail`, `.allBarcodes`, `.all2D`, `.all`)
- Configurable camera selection (wide, ultra-wide, auto, custom)
- Privacy manifest included

## Requirements

- iOS 16.0+
- Swift 6.0+
- Xcode 16.0+

## Installation

### Swift Package Manager

Add CodeScanner to your project via SPM:

```swift
dependencies: [
    .package(url: "https://github.com/cymr0/CodeScanner.git", branch: "main")
]
```

## Quick Start

The simplest usage — scan retail barcodes with one line:

```swift
CodeScannerView { result in
    switch result {
    case .success(let scan):
        print("Scanned: \(scan.payload) (\(scan.symbology))")
    case .failure(let error):
        print("Error: \(error.localizedDescription)")
    }
}
```

This uses all retail defaults: continuous scanning, EAN-13/UPC/Code 128/Code 39 detection, 1-second scan interval, viewfinder overlay, and wide-angle camera with auto-zoom.

## Configuration

### Barcode Type Presets

```swift
// Retail products (EAN-13, EAN-8, UPC-E, Code 128, Code 39)
CodeScannerView(codeTypes: BarcodeType.retail) { ... }

// All 1D barcodes (adds Code 93, ITF-14, Interleaved 2of5, Codabar, etc.)
CodeScannerView(codeTypes: BarcodeType.allBarcodes) { ... }

// 2D codes only (QR, PDF417, DataMatrix, Aztec)
CodeScannerView(codeTypes: BarcodeType.all2D) { ... }

// Everything
CodeScannerView(codeTypes: BarcodeType.all) { ... }
```

### Scan Modes

```swift
// Scan once and stop
CodeScannerView(scanMode: .once) { ... }

// Each unique code triggers once
CodeScannerView(scanMode: .oncePerCode) { ... }

// Continuous scanning (default for retail)
CodeScannerView(scanMode: .continuous, scanInterval: 1.0) { ... }

// Continuous but skip known codes
CodeScannerView(scanMode: .continuousExcept(ignoredList: ["123456"]), scanInterval: 1.0) { ... }

// Manual trigger only
CodeScannerView(scanMode: .manual) { ... }
```

### Camera Configuration

```swift
// Use the retail preset (default)
CodeScannerView(cameraConfiguration: .retail) { ... }

// Custom configuration
var config = CameraConfiguration.retail
config.isTorchEnabled = true
config.preferredCamera = .ultraWide
config.minimumCodeSize = 15  // mm

CodeScannerView(cameraConfiguration: config) { ... }
```

### Full Example

```swift
struct ScannerScreen: View {
    @State private var isPresentingScanner = false
    @State private var lastScannedCode: String?

    var body: some View {
        VStack(spacing: 20) {
            if let code = lastScannedCode {
                Text("Last scan: \(code)")
                    .font(.headline)
            }

            Button("Scan Barcode") {
                isPresentingScanner = true
            }
        }
        .sheet(isPresented: $isPresentingScanner) {
            CodeScannerView(
                codeTypes: BarcodeType.retail,
                scanMode: .continuous,
                scanInterval: 1.0,
                showViewfinder: true,
                isTorchOn: false
            ) { result in
                if case let .success(scan) = result {
                    lastScannedCode = scan.payload
                    isPresentingScanner = false
                }
            }
        }
    }
}
```

### Checking Barcode Type

```swift
CodeScannerView { result in
    if case let .success(scan) = result {
        if scan.isBarcode {
            print("1D barcode: \(scan.payload)")
        } else {
            print("2D code: \(scan.payload)")
        }
    }
}
```

**Important:** iOS requires you to add the "Privacy - Camera Usage Description" key to your Info.plist file.

## API Reference

| Type | Description |
|------|-------------|
| `CodeScannerView` | Main SwiftUI view — drop-in barcode scanner |
| `ScanResult` | Decoded payload, symbology, corners, optional image |
| `ScanError` | Error cases: camera unavailable, permission denied, etc. |
| `ScanMode` | Scanning behaviour: once, oncePerCode, continuous, manual |
| `BarcodeType` | Preset symbology collections for common use cases |
| `CameraConfiguration` | Camera hardware settings (lens, focus, zoom, torch) |
| `CameraSelection` | Which physical camera to use |
| `ScannerViewController` | Underlying UIKit controller (for advanced use) |

## Credits

Originally created by [Paul Hudson](https://twitter.com/twostraws). Modernised for Swift 6 and retail barcode scanning.

## License

MIT License. See [LICENSE](LICENSE) for details.
