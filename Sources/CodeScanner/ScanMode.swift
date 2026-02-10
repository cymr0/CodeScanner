//
//  ScanMode.swift
//  https://github.com/twostraws/CodeScanner
//
//  Created by Paul Hudson on 14/12/2021.
//  Copyright © 2021 Paul Hudson. All rights reserved.
//

#if os(iOS)

/// The operating mode for CodeScannerView.
///
/// Controls how the scanner responds after detecting one or more codes.
/// Choose the mode that best fits your scanning workflow.
public enum ScanMode: Sendable {
    /// Scan exactly one code, then stop.
    case once

    /// Scan each unique code no more than once.
    case oncePerCode

    /// Keep scanning all codes until dismissed, respecting the configured scan interval.
    case continuous

    /// Keep scanning all codes until dismissed, but skip any codes found in the ignored list.
    case continuousExcept(ignoredList: Set<String>)

    /// Scan only when the user explicitly triggers capture by tapping the manual-capture button.
    case manual

    /// Whether this mode requires an explicit user tap to initiate scanning.
    var isManual: Bool {
        switch self {
        case .manual:
            return true
        case .once, .oncePerCode, .continuous, .continuousExcept:
            return false
        }
    }
}

#endif
