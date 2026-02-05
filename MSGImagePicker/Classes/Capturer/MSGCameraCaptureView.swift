//
//  MSGCameraCaptureView.swift
//  MSGImagePicker
//
//  Main camera capture view composing preview and controls.
//  Presented in portrait-locked modal via PortraitLockedFullScreenCover.
//

import SwiftUI

/// The main camera capture view.
struct MSGCameraCaptureView: View {

    @StateObject private var viewModel: CameraCaptureViewModel
    @StateObject private var orientationManager = DeviceOrientationManager()

    /// Base zoom factor for pinch gesture calculations.
    @State private var baseZoomFactor: CGFloat = 1.0
    
    init(viewModel: CameraCaptureViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if viewModel.permissionsChecked {
                if viewModel.permissionsGranted {
                    cameraContent
                } else {
                    permissionDeniedView
                }
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .statusBarHidden(true)
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let message = viewModel.errorMessage {
                Text(message)
            }
        }
    }
    
    // MARK: - Camera Content
    
    private var cameraContent: some View {
        ZStack {
            CameraPreviewView(session: viewModel.cameraService.session)
                .ignoresSafeArea()
                .gesture(zoomGesture)

            CaptureControlsOverlay(viewModel: viewModel, orientationManager: orientationManager)
        }
    }
    
    // MARK: - Zoom Gesture
    
    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newZoom = baseZoomFactor * value
                viewModel.handleZoomGesture(newZoom)
            }
            .onEnded { _ in
                baseZoomFactor = viewModel.zoomFactor
            }
    }
    
    // MARK: - Permission Denied View
    
    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.5))
            
            Text("Camera Access Required")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Please enable camera access in Settings to take photos and videos.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Open Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
            
            Button("Cancel") {
                viewModel.cancel()
            }
            .foregroundColor(.white)
            .padding(.top, 4)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct MSGCameraCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        MSGCameraCaptureView(
            viewModel: CameraCaptureViewModel()
        )
    }
}
#endif
