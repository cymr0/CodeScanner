//
//  ScannerViewController.swift
//  https://github.com/twostraws/CodeScanner
//
//  Created by Paul Hudson on 14/12/2021.
//  Copyright © 2021 Paul Hudson. All rights reserved.
//

#if os(iOS)
import AudioToolbox
import AVFoundation
import UIKit

/// The core UIKit view controller that manages camera setup, barcode detection,
/// and photo capture for the CodeScanner library.
///
/// This class is `@MainActor`-isolated and designed for iOS 16+ with Swift 6
/// concurrency. All AVFoundation capture-session work that must leave the main
/// thread is dispatched via `Task.detached`.
@MainActor
public final class ScannerViewController: UIViewController {

    // MARK: - Properties

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let metadataOutput = AVCaptureMetadataOutput()
    private let photoOutput = AVCapturePhotoOutput()

    private var isSessionConfigured = false
    private var isCapturing = false
    private var codesFound = Set<String>()
    private var didFinishScanning = false
    private var lastScanTime = Date(timeIntervalSince1970: 0)
    private var photoHandler: ((UIImage?) -> Void)?

    // Configuration
    private let codeTypes: [AVMetadataObject.ObjectType]
    private let scanMode: ScanMode
    private let scanInterval: Double
    private let showViewfinder: Bool
    private let requiresPhotoOutput: Bool
    private let shouldVibrateOnSuccess: Bool
    private let cameraConfiguration: CameraConfiguration
    private let simulatedData: String
    private let completion: @MainActor (Result<ScanResult, ScanError>) -> Void

    // Mutable state pushed from SwiftUI via updateUIViewController
    private var currentlyPaused = false

    // MARK: - Initialiser

    public init(
        codeTypes: [AVMetadataObject.ObjectType],
        scanMode: ScanMode = .once,
        scanInterval: Double = 2.0,
        showViewfinder: Bool = false,
        requiresPhotoOutput: Bool = false,
        shouldVibrateOnSuccess: Bool = true,
        cameraConfiguration: CameraConfiguration = .retail,
        isPaused: Bool = false,
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
        self.currentlyPaused = isPaused
        self.simulatedData = simulatedData
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Use init(...) instead")
    }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        #if targetEnvironment(simulator)
        setupSimulatorView()
        #else
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCaptureSession()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if granted {
                        self.setupCaptureSession()
                    } else {
                        self.completion(.failure(.cameraPermissionDenied))
                    }
                }
            }

        case .denied, .restricted:
            completion(.failure(.cameraPermissionDenied))

        @unknown default:
            break
        }
        #endif
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startRunning()
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopRunning()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    // MARK: - Status Bar & Orientation

    public override var prefersStatusBarHidden: Bool {
        true
    }

    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .all
    }

    public override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate { _ in
            self.updateVideoOrientation()
        }
    }

    // MARK: - Capture Session Setup

    private func setupCaptureSession() {
        let captureSession = self.captureSession
        let metadataOutput = self.metadataOutput
        let photoOutput = self.photoOutput
        let codeTypes = self.codeTypes
        let requiresPhotoOutput = self.requiresPhotoOutput
        let cameraConfiguration = self.cameraConfiguration

        Task.detached(priority: .userInitiated) { [weak self] in
            captureSession.beginConfiguration()

            captureSession.sessionPreset = .high

            // Resolve camera device
            guard let device = cameraConfiguration.resolveDevice() else {
                captureSession.commitConfiguration()
                await MainActor.run { [weak self] in
                    self?.completion(.failure(.cameraUnavailable))
                }
                return
            }

            // Create and add video input
            let videoInput: AVCaptureDeviceInput
            do {
                videoInput = try AVCaptureDeviceInput(device: device)
            } catch {
                captureSession.commitConfiguration()
                await MainActor.run { [weak self] in
                    self?.completion(.failure(.initializationFailed(error.localizedDescription)))
                }
                return
            }

            guard captureSession.canAddInput(videoInput) else {
                captureSession.commitConfiguration()
                await MainActor.run { [weak self] in
                    self?.completion(.failure(.invalidInput))
                }
                return
            }
            captureSession.addInput(videoInput)

            // Add metadata output
            guard captureSession.canAddOutput(metadataOutput) else {
                captureSession.commitConfiguration()
                await MainActor.run { [weak self] in
                    self?.completion(.failure(.invalidOutput))
                }
                return
            }
            captureSession.addOutput(metadataOutput)

            // Set delegate on main queue so callbacks arrive on main
            await MainActor.run { [weak self] in
                guard let self else { return }
                metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            }

            // Filter requested code types to those actually available
            metadataOutput.metadataObjectTypes = codeTypes.filter {
                metadataOutput.availableMetadataObjectTypes.contains($0)
            }

            // Optionally add photo output
            if requiresPhotoOutput, captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
            }

            // Configure device for barcode scanning
            do {
                try device.lockForConfiguration()
                if device.isFocusModeSupported(cameraConfiguration.focusMode) {
                    device.focusMode = cameraConfiguration.focusMode
                }
                if device.isFocusModeSupported(.autoFocus) {
                    device.autoFocusRangeRestriction = .near
                }
                device.unlockForConfiguration()
            } catch {
                // Focus configuration is not critical; continue without it
            }

            // Apply auto-zoom if enabled
            if cameraConfiguration.isAutoZoomEnabled {
                self?.applyAutoZoom(to: device, minimumCodeSize: cameraConfiguration.minimumCodeSize)
            }

            // Apply torch setting from configuration
            if cameraConfiguration.isTorchEnabled, device.hasTorch {
                do {
                    try device.lockForConfiguration()
                    device.torchMode = .on
                    device.unlockForConfiguration()
                } catch {
                    // Torch not critical; continue without it
                }
            }

            captureSession.commitConfiguration()

            // Switch back to MainActor for UI setup and session start
            await MainActor.run { [weak self] in
                self?.isSessionConfigured = true
                self?.setupPreviewLayer()
                self?.startRunning()
            }
        }
    }

    // MARK: - Auto Zoom

    private nonisolated func applyAutoZoom(to device: AVCaptureDevice, minimumCodeSize: Float) {
        let minFocusDistance = Float(device.minimumFocusDistance)
        guard minFocusDistance > 0 else { return }

        let fieldOfView = device.activeFormat.videoFieldOfView
        let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        let rectWidth = Float(dimensions.height) / Float(dimensions.width)

        let radians = (fieldOfView / 2) * .pi / 180
        let filledCodeSize = minimumCodeSize / rectWidth
        let minSubjectDistance = filledCodeSize / tan(radians)

        guard minSubjectDistance < minFocusDistance else { return }

        let zoomFactor = min(minFocusDistance / minSubjectDistance, 2.0)
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = CGFloat(zoomFactor)
            device.unlockForConfiguration()
        } catch {
            // Zoom not critical, continue without it
        }
    }

    // MARK: - Preview Layer

    private func setupPreviewLayer() {
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.frame = view.layer.bounds
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        previewLayer = layer

        if showViewfinder {
            addViewfinderOverlay()
        }
    }

    private func addViewfinderOverlay() {
        let overlay = UIView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.layer.borderColor = UIColor.white.withAlphaComponent(0.7).cgColor
        overlay.layer.borderWidth = 2
        overlay.layer.cornerRadius = 12
        overlay.backgroundColor = .clear
        view.addSubview(overlay)

        NSLayoutConstraint.activate([
            overlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            overlay.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            overlay.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.75),
            overlay.heightAnchor.constraint(equalToConstant: 120)
        ])
    }

    // MARK: - Session Control

    private func startRunning() {
        guard isSessionConfigured, !captureSession.isRunning else { return }
        Task.detached { [captureSession] in
            captureSession.startRunning()
        }
    }

    private func stopRunning() {
        guard captureSession.isRunning else { return }
        Task.detached { [captureSession] in
            captureSession.stopRunning()
        }
    }

    // MARK: - Orientation

    private func updateVideoOrientation() {
        guard let connection = previewLayer?.connection,
              connection.isVideoOrientationSupported,
              let orientation = view.window?.windowScene?.interfaceOrientation else { return }

        let videoOrientation: AVCaptureVideoOrientation
        switch orientation {
        case .portrait: videoOrientation = .portrait
        case .landscapeLeft: videoOrientation = .landscapeLeft
        case .landscapeRight: videoOrientation = .landscapeRight
        case .portraitUpsideDown: videoOrientation = .portraitUpsideDown
        @unknown default: videoOrientation = .portrait
        }
        connection.videoOrientation = videoOrientation
    }

    // MARK: - Touch to Focus

    #if !targetEnvironment(simulator)
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let device = cameraConfiguration.resolveDevice(),
              device.isFocusPointOfInterestSupported else { return }

        let point = touch.location(in: view)
        let focusPoint = previewLayer?.captureDevicePointConverted(fromLayerPoint: point)
            ?? CGPoint(x: 0.5, y: 0.5)

        do {
            try device.lockForConfiguration()
            device.focusPointOfInterest = focusPoint
            device.focusMode = .autoFocus
            device.exposurePointOfInterest = focusPoint
            device.exposureMode = .autoExpose
            device.unlockForConfiguration()
        } catch { }
    }
    #endif

    // MARK: - Public Methods

    /// Resets the scanner so it can detect codes again.
    public func reset() {
        codesFound.removeAll()
        didFinishScanning = false
        lastScanTime = Date(timeIntervalSince1970: 0)
    }

    /// Triggers a manual capture window (only effective in `.manual` scan mode).
    public func triggerManualCapture() {
        guard scanMode.isManual else { return }
        reset()
        lastScanTime = Date()
    }

    /// Updates the paused state. Called from `updateUIViewController` so
    /// SwiftUI state changes propagate live.
    public func updatePaused(_ paused: Bool) {
        currentlyPaused = paused
    }

    /// Turns the device torch on or off.
    public func updateTorch(_ isOn: Bool) {
        guard let device = cameraConfiguration.resolveDevice(),
              device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = isOn ? .on : .off
        device.unlockForConfiguration()
    }

    // MARK: - Scan Handling

    private func handleMetadataObjects(_ metadataObjects: [AVMetadataObject]) {
        guard let metadataObject = metadataObjects.first,
              !currentlyPaused,
              !didFinishScanning,
              !isCapturing,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else { return }

        let handler: (UIImage?) -> Void = { [weak self] image in
            guard let self else { return }
            let result = ScanResult(
                payload: stringValue,
                symbology: readableObject.type,
                corners: readableObject.corners,
                capturedImage: image
            )
            self.processResult(result)
        }

        if requiresPhotoOutput {
            isCapturing = true
            photoHandler = handler
            photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        } else {
            handler(nil)
        }
    }

    private func processResult(_ result: ScanResult) {
        switch scanMode {
        case .once:
            didFinishScanning = true
            reportSuccess(result)

        case .manual:
            if !didFinishScanning, Date().timeIntervalSince(lastScanTime) <= 0.5 {
                didFinishScanning = true
                reportSuccess(result)
            }

        case .oncePerCode:
            if !codesFound.contains(result.payload) {
                codesFound.insert(result.payload)
                reportSuccess(result)
            }

        case .continuous:
            if Date().timeIntervalSince(lastScanTime) >= scanInterval {
                reportSuccess(result)
            }

        case .continuousExcept(let ignoredList):
            if Date().timeIntervalSince(lastScanTime) >= scanInterval,
               !ignoredList.contains(result.payload) {
                reportSuccess(result)
            }
        }
    }

    private func reportSuccess(_ result: ScanResult) {
        lastScanTime = Date()
        if shouldVibrateOnSuccess {
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        }
        completion(.success(result))
    }
}

// MARK: - Simulator Support

#if targetEnvironment(simulator)
extension ScannerViewController {
    fileprivate func setupSimulatorView() {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.text = "Camera is not available in the Simulator.\nTap anywhere to return simulated data."
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !simulatedData.isEmpty else { return }
        let result = ScanResult(
            payload: simulatedData,
            symbology: codeTypes.first ?? .ean13,
            corners: [],
            capturedImage: nil
        )
        reportSuccess(result)
    }
}
#endif

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension ScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated public func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        Task { @MainActor [weak self] in
            self?.handleMetadataObjects(metadataObjects)
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension ScannerViewController: AVCapturePhotoCaptureDelegate {
    nonisolated public func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isCapturing = false
            let image = photo.fileDataRepresentation().flatMap { UIImage(data: $0) }
            self.photoHandler?(image)
            self.photoHandler = nil
        }
    }
}
#endif
