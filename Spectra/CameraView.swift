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

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            switch viewModel.authorizationStatus {
            case .authorized:
                ZStack {
                    CameraPreview(session: viewModel.session)
                        .ignoresSafeArea(edges: .bottom)

                    if let error = viewModel.errorMessage {
                        VStack {
                            Spacer()
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.black.opacity(0.55), in: Capsule())
                                .padding(.bottom, 16)
                        }
                    }
                }
            case .notDetermined:
                ProgressView("Запрашиваем доступ к камере…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.pageBackground)
            case .denied, .restricted:
                ContentUnavailableView(
                    "Нет доступа к камере",
                    systemImage: "camera.fill",
                    description: Text("Разрешите доступ к камере в настройках iOS")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.pageBackground)
                .overlay(alignment: .bottom) {
                    Button("Открыть настройки") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else {
                            return
                        }
                        openURL(url)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 20)
                }
            @unknown default:
                ContentUnavailableView(
                    "Камера недоступна",
                    systemImage: "camera.slash"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.pageBackground)
            }
        }
        .onAppear {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
    }
}

@MainActor
final class CameraViewModel: ObservableObject {
    @Published var authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published var errorMessage: String?

    nonisolated let session = AVCaptureSession()
    nonisolated private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    nonisolated(unsafe) private var isConfigured = false

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
            errorMessage = "Доступ к камере запрещен"
        @unknown default:
            errorMessage = "Неизвестный статус доступа к камере"
        }
    }

    func stop() {
        let session = session
        sessionQueue.async {
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }

    private func configureAndStartSession() {
        let session = session

        sessionQueue.async { [weak self] in
            guard let self else { return }

            if !self.isConfigured {
                do {
                    try self.configureSession()
                    self.isConfigured = true
                } catch {
                    Task { @MainActor in
                        self.errorMessage = "Не удалось настроить камеру"
                    }
                    return
                }
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

    private nonisolated func configureSession() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo

        if session.inputs.isEmpty {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                throw CameraSetupError.missingCamera
            }

            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                throw CameraSetupError.cannotAddInput
            }
            session.addInput(input)
        }
    }
}

private enum CameraSetupError: Error {
    case missingCamera
    case cannotAddInput
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewContainerView {
        let view = CameraPreviewContainerView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: CameraPreviewContainerView, context: Context) {
        uiView.previewLayer.session = session
    }
}

private final class CameraPreviewContainerView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
