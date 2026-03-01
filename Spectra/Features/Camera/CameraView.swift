//
//  CameraView.swift
//  Spectra
//
//  Created by Codex on 01.03.2026.
//

import SwiftUI
@preconcurrency import AVFoundation
import UIKit
import Combine
import Foundation
import Photos

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    @State private var focusIndicatorPoint: CGPoint?
    @State private var focusIndicatorScale: CGFloat = 1.25
    @State private var focusIndicatorOpacity: Double = 0
    @State private var hideFocusIndicatorTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if viewModel.authorizationStatus == .authorized {
                CameraPreview(session: viewModel.session) { devicePoint, layerPoint in
                    viewModel.focusAndExpose(at: devicePoint)
                    showFocusIndicator(at: layerPoint)
                }
            } else {
                Color.black
            }

            if let point = focusIndicatorPoint {
                Circle()
                    .stroke(Color.yellow, lineWidth: 2)
                    .frame(width: 86, height: 86)
                    .scaleEffect(focusIndicatorScale)
                    .opacity(focusIndicatorOpacity)
                    .position(point)
                    .allowsHitTesting(false)
            }

#if DEBUG
            if viewModel.authorizationStatus == .authorized, !viewModel.cameraOptions.isEmpty {
                VStack {
                    debugPanel
                    Spacer()
                }
                .padding(.top, 8)
            }
#endif

            if viewModel.authorizationStatus == .authorized, !viewModel.cameraOptions.isEmpty {
                VStack {
                    Spacer()
                    captureButton
                        .padding(.bottom, 174)
                    cameraSwitchButtons
                        .padding(.bottom, 104)
                }
            }
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
            hideFocusIndicatorTask?.cancel()
            hideFocusIndicatorTask = nil
        }
    }

    private var captureButton: some View {
        Button {
            viewModel.capturePhoto()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 74, height: 74)
                Circle()
                    .stroke(Color.black.opacity(0.25), lineWidth: 2)
                    .frame(width: 66, height: 66)
            }
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.28), radius: 8, y: 4)
    }

    private var cameraSwitchButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.cameraOptions) { option in
                    Button {
                        viewModel.selectCamera(withID: option.id)
                    } label: {
                        Text(option.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(
                                viewModel.selectedCameraID == option.id
                                    ? Color.black
                                    : Color.white
                            )
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(
                                    viewModel.selectedCameraID == option.id
                                        ? Color.white.opacity(0.95)
                                        : Color.black.opacity(0.42)
                                )
                            )
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.35), lineWidth: 0.8)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.horizontal, 14)
    }

    private func showFocusIndicator(at point: CGPoint) {
        hideFocusIndicatorTask?.cancel()
        focusIndicatorPoint = point
        focusIndicatorScale = 1.25
        focusIndicatorOpacity = 1

        withAnimation(.easeOut(duration: 0.18)) {
            focusIndicatorScale = 1.0
        }

        hideFocusIndicatorTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 650_000_000)
            withAnimation(.easeIn(duration: 0.2)) {
                focusIndicatorOpacity = 0
            }
            try? await Task.sleep(nanoseconds: 220_000_000)
            focusIndicatorPoint = nil
        }
    }

#if DEBUG
    private var debugPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Camera Debug")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)

            ForEach(viewModel.cameraOptions) { option in
                Text(
                    "\(viewModel.selectedCameraID == option.id ? "•" : " ") \(option.debugLine)"
                )
                .font(.caption2.monospaced())
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
        )
        .padding(.horizontal, 14)
    }
#endif
}

@MainActor
final class CameraViewModel: ObservableObject {
    @Published var authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published var cameraOptions: [CameraOption] = []
    @Published var selectedCameraID: String?

    nonisolated let session = AVCaptureSession()
    nonisolated private let photoOutput = AVCapturePhotoOutput()
    nonisolated private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    nonisolated(unsafe) private var isConfigured = false
    nonisolated(unsafe) private var inFlightPhotoCaptures: [Int64: PhotoCaptureProcessor] = [:]

    func start() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

        switch authorizationStatus {
        case .authorized:
            configureAndStartSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                Task { @MainActor in
                    self.handleCameraAccess(granted: granted)
                }
            }
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    func stop() {
        let session = session
        sessionQueue.async {
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }

    func selectCamera(withID optionID: String) {
        guard selectedCameraID != optionID else { return }
        switchToCamera(withOptionID: optionID)
    }

    func capturePhoto() {
        let output = photoOutput
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning else { return }

            let settings = AVCapturePhotoSettings()
            settings.isHighResolutionPhotoEnabled = output.isHighResolutionCaptureEnabled

            let processor = PhotoCaptureProcessor(
                onPhotoData: { [weak self] data in
                    self?.savePhotoDataToLibrary(data)
                },
                onFinish: { [weak self] uniqueID in
                self?.sessionQueue.async {
                    self?.inFlightPhotoCaptures.removeValue(forKey: uniqueID)
                }
            })

            self.inFlightPhotoCaptures[settings.uniqueID] = processor
            output.capturePhoto(with: settings, delegate: processor)
        }
    }

    func focusAndExpose(at devicePoint: CGPoint) {
        let point = CGPoint(
            x: min(max(devicePoint.x, 0), 1),
            y: min(max(devicePoint.y, 0), 1)
        )

        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentVideoDevice() else { return }

            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }

                if device.isFocusPointOfInterestSupported {
                    if device.isFocusModeSupported(.autoFocus) {
                        device.focusPointOfInterest = point
                        device.focusMode = .autoFocus
                    } else if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusPointOfInterest = point
                        device.focusMode = .continuousAutoFocus
                    }
                }

                if device.isExposurePointOfInterestSupported {
                    if device.isExposureModeSupported(.autoExpose) {
                        device.exposurePointOfInterest = point
                        device.exposureMode = .autoExpose
                    } else if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposurePointOfInterest = point
                        device.exposureMode = .continuousAutoExposure
                    }
                }
            } catch {
                return
            }
        }
    }

    private func configureAndStartSession() {
        let session = session
        let currentSelected = selectedCameraID

        sessionQueue.async { [weak self] in
            guard let self else { return }

            let options = self.discoverCameraOptions()
            let preferred = Self.preferredCameraID(
                from: options,
                currentSelectedID: currentSelected
            )

            Task { @MainActor in
                self.cameraOptions = options
                if self.selectedCameraID == nil {
                    self.selectedCameraID = preferred
                }
            }

            guard
                let targetID = preferred,
                let preferredOption = options.first(where: { $0.id == targetID })
            else {
                return
            }

            do {
                try self.configureSession(with: preferredOption)
                self.isConfigured = true
            } catch {
                return
            }

            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    private func handleCameraAccess(granted: Bool) {
        authorizationStatus = granted ? .authorized : .denied
        if granted {
            configureAndStartSession()
        }
    }

    private func switchToCamera(withOptionID optionID: String) {
        let session = session
        let options = cameraOptions
        sessionQueue.async { [weak self] in
            guard
                let self,
                let selectedOption = options.first(where: { $0.id == optionID })
            else {
                return
            }
            do {
                try self.configureSession(with: selectedOption)
                if !session.isRunning {
                    session.startRunning()
                }
                Task { @MainActor in
                    self.selectedCameraID = optionID
                }
            } catch {
                Task { @MainActor in
                    self.refreshAvailableCameras()
                }
            }
        }
    }

    private func refreshAvailableCameras() {
        let options = discoverCameraOptions()
        cameraOptions = options
        selectedCameraID = Self.preferredCameraID(
            from: options,
            currentSelectedID: selectedCameraID
        )
    }

    private nonisolated func configureSession(with option: CameraOption) throws {
        guard let device = cameraDevice(withID: option.deviceID) else {
            throw CameraSetupError.missingCamera
        }

        let input = try AVCaptureDeviceInput(device: device)

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo

        for existingInput in session.inputs {
            guard let currentVideoInput = existingInput as? AVCaptureDeviceInput else { continue }
            session.removeInput(currentVideoInput)
        }

        guard session.canAddInput(input) else {
            throw CameraSetupError.cannotAddInput
        }
        session.addInput(input)

        if session.outputs.contains(where: { $0 === photoOutput }) == false {
            guard session.canAddOutput(photoOutput) else {
                throw CameraSetupError.cannotAddOutput
            }
            session.addOutput(photoOutput)
            photoOutput.isHighResolutionCaptureEnabled = true
        }

        let minZoom = device.minAvailableVideoZoomFactor
        let maxZoom = device.maxAvailableVideoZoomFactor
        let zoom = min(max(option.preferredZoomFactor, minZoom), maxZoom)
        if device.videoZoomFactor != zoom {
            try device.lockForConfiguration()
            device.videoZoomFactor = zoom
            device.unlockForConfiguration()
        }
    }

    private nonisolated func cameraDevice(withID uniqueID: String) -> AVCaptureDevice? {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: CameraOption.supportedDeviceTypes,
            mediaType: .video,
            position: .unspecified
        ).devices

        return devices.first { $0.uniqueID == uniqueID }
    }

    private nonisolated func currentVideoDevice() -> AVCaptureDevice? {
        session.inputs
            .compactMap { $0 as? AVCaptureDeviceInput }
            .first { $0.device.hasMediaType(.video) }?
            .device
    }

    private nonisolated func savePhotoDataToLibrary(_ data: Data) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            writePhotoToLibrary(data)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] newStatus in
                guard let self else { return }
                guard newStatus == .authorized || newStatus == .limited else { return }
                self.writePhotoToLibrary(data)
            }
        default:
            break
        }
    }

    private nonisolated func writePhotoToLibrary(_ data: Data) {
        PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: data, options: nil)
        }
    }

    private nonisolated func discoverCameraOptions() -> [CameraOption] {
        let allDevices = AVCaptureDevice.DiscoverySession(
            deviceTypes: CameraOption.supportedDeviceTypes,
            mediaType: .video,
            position: .unspecified
        ).devices

        let backDevices = allDevices.filter {
            $0.position == .back && CameraOption.physicalBackTypes.contains($0.deviceType)
        }
        let frontDevices = allDevices.filter { $0.position == .front }

        let wideFieldOfView = backDevices
            .first(where: { $0.deviceType == .builtInWideAngleCamera })?
            .activeFormat
            .videoFieldOfView

        var options = backDevices
            .map {
                CameraOption(
                    device: $0,
                    wideAngleFieldOfView: wideFieldOfView
                )
            }
            .sorted(by: CameraOption.sorting(lhs:rhs:))

        if let preferredFront = frontDevices.sorted(by: CameraOption.frontPreference(lhs:rhs:)).first {
            options.append(
                CameraOption(
                    device: preferredFront,
                    wideAngleFieldOfView: nil
                )
            )
        }

        return options
    }

    private nonisolated static func preferredCameraID(
        from options: [CameraOption],
        currentSelectedID: String?
    ) -> String? {
        if let currentSelectedID, options.contains(where: { $0.id == currentSelectedID }) {
            return currentSelectedID
        }

        if let oneXBack = options.first(where: { $0.position == .back && $0.label == "1x" }) {
            return oneXBack.id
        }

        if let back = options.first(where: { $0.position == .back }) {
            return back.id
        }

        return options.first?.id
    }
}

private enum CameraSetupError: Error {
    case missingCamera
    case cannotAddInput
    case cannotAddOutput
}

struct CameraOption: Identifiable, Hashable {
    nonisolated static let supportedDeviceTypes: [AVCaptureDevice.DeviceType] = [
        .builtInTripleCamera,
        .builtInDualWideCamera,
        .builtInDualCamera,
        .builtInUltraWideCamera,
        .builtInWideAngleCamera,
        .builtInTelephotoCamera,
        .builtInTrueDepthCamera
    ]
    nonisolated static let physicalBackTypes: Set<AVCaptureDevice.DeviceType> = [
        .builtInUltraWideCamera,
        .builtInWideAngleCamera,
        .builtInTelephotoCamera
    ]

    let id: String
    let deviceID: String
    let label: String
    let position: AVCaptureDevice.Position
    let deviceType: AVCaptureDevice.DeviceType
    let preferredZoomFactor: CGFloat
    let fieldOfView: Float
    private let priority: Int

    nonisolated init(
        device: AVCaptureDevice,
        wideAngleFieldOfView: Float?
    ) {
        id = device.uniqueID
        deviceID = device.uniqueID
        position = device.position
        deviceType = device.deviceType
        fieldOfView = device.activeFormat.videoFieldOfView
        let description = CameraOption.labelAndPriority(
            for: device,
            wideAngleFieldOfView: wideAngleFieldOfView
        )
        label = description.label
        priority = description.priority
        preferredZoomFactor = description.zoomFactor
    }

    nonisolated static func sorting(lhs: CameraOption, rhs: CameraOption) -> Bool {
        if lhs.priority == rhs.priority {
            return lhs.label < rhs.label
        }
        return lhs.priority < rhs.priority
    }

    nonisolated static func frontPreference(lhs: AVCaptureDevice, rhs: AVCaptureDevice) -> Bool {
        frontPriority(for: lhs.deviceType) < frontPriority(for: rhs.deviceType)
    }

    private nonisolated static func labelAndPriority(
        for device: AVCaptureDevice,
        wideAngleFieldOfView: Float?
    ) -> (label: String, priority: Int, zoomFactor: CGFloat) {
        switch device.position {
        case .back:
            switch device.deviceType {
            case .builtInUltraWideCamera:
                return ("0.5x", 0, 1.0)
            case .builtInWideAngleCamera:
                return ("1x", 1, 1.0)
            case .builtInTelephotoCamera:
                let rawMagnification = telephotoMagnification(
                    telephotoFieldOfView: device.activeFormat.videoFieldOfView,
                    wideAngleFieldOfView: wideAngleFieldOfView
                )
                let magnification = normalizedTelephotoMagnification(rawMagnification)
                return (formattedMagnification(magnification), 2, 1.0)
            default:
                return ("Назад", 3, 1.0)
            }
        case .front:
            return ("Фронт", 10, 1.0)
        default:
            return ("Камера", 20, 1.0)
        }
    }

    private nonisolated static func frontPriority(for deviceType: AVCaptureDevice.DeviceType) -> Int {
        switch deviceType {
        case .builtInTrueDepthCamera:
            return 0
        case .builtInWideAngleCamera:
            return 1
        default:
            return 2
        }
    }

    private nonisolated static func telephotoMagnification(
        telephotoFieldOfView: Float,
        wideAngleFieldOfView: Float?
    ) -> Double {
        guard let wideAngleFieldOfView, telephotoFieldOfView > 0 else {
            return 2.0
        }
        let ratio = Double(wideAngleFieldOfView / telephotoFieldOfView)
        return max(2.0, ratio)
    }

    private nonisolated static func normalizedTelephotoMagnification(_ rawValue: Double) -> Double {
        // Align raw optical ratio with user-facing iPhone camera steps.
        if rawValue >= 4.0 { return 5.0 }
        if rawValue >= 2.5 { return 3.0 }
        return 2.0
    }

    private nonisolated static func formattedMagnification(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if abs(rounded.rounded() - rounded) < 0.05 {
            return "\(Int(rounded.rounded()))x"
        }
        return String(format: "%.1fx", rounded)
    }

    nonisolated var debugLine: String {
        let fov = String(format: "%.1f", fieldOfView)
        let positionName: String
        switch position {
        case .back:
            positionName = "back"
        case .front:
            positionName = "front"
        default:
            positionName = "unspecified"
        }

        return "\(label) | \(positionName) | \(deviceType.rawValue) | fov:\(fov) | id:\(deviceID.suffix(6))"
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let onTap: (CGPoint, CGPoint) -> Void

    func makeUIView(context: Context) -> CameraPreviewContainerView {
        let view = CameraPreviewContainerView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewContainerView, context: Context) {
        uiView.previewLayer.session = session
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    final class Coordinator: NSObject {
        let onTap: (CGPoint, CGPoint) -> Void

        init(onTap: @escaping (CGPoint, CGPoint) -> Void) {
            self.onTap = onTap
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let view = recognizer.view as? CameraPreviewContainerView else { return }
            let layerPoint = recognizer.location(in: view)
            let devicePoint = view.previewLayer.captureDevicePointConverted(fromLayerPoint: layerPoint)
            onTap(devicePoint, layerPoint)
        }
    }
}

private final class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    private let onPhotoData: (Data) -> Void
    private let onFinish: (Int64) -> Void

    init(
        onPhotoData: @escaping (Data) -> Void,
        onFinish: @escaping (Int64) -> Void
    ) {
        self.onPhotoData = onPhotoData
        self.onFinish = onFinish
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil else { return }
        guard let data = photo.fileDataRepresentation() else { return }
        onPhotoData(data)
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        onFinish(resolvedSettings.uniqueID)
    }
}

private final class CameraPreviewContainerView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
