//
//  CameraCaptureViewModel.swift
//  MSGImagePicker
//
//  ViewModel for coordinating camera capture UI and CameraService.
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - Capture Mode

/// The current capture mode.
enum CaptureMode: String, CaseIterable {
    case photo = "Photo"
    case video = "Video"
}

// MARK: - View Model

/// ViewModel for the camera capture view.
@MainActor
final class CameraCaptureViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current capture mode (photo or video).
    @Published var captureMode: CaptureMode = .photo
    
    /// Whether a capture is in progress.
    @Published var isCapturing = false
    
    /// Whether video recording is in progress.
    @Published var isRecording = false
    
    /// Current recording time in seconds.
    @Published var recordingTime: TimeInterval = 0
    
    /// Current zoom factor.
    @Published var zoomFactor: CGFloat = 1.0
    
    /// Whether the zoom indicator should be visible.
    @Published var showZoomIndicator = false
    
    /// Current flash mode.
    @Published var flashMode: FlashMode = .auto
    
    /// Whether flash is available.
    @Published var isFlashAvailable = false
    
    /// Current camera position.
    @Published var currentPosition: CameraPosition = .back
    
    /// Whether the session is running.
    @Published var isSessionRunning = false
    
    /// Error message to display.
    @Published var errorMessage: String?
    
    /// Whether permissions have been checked.
    @Published var permissionsChecked = false
    
    /// Whether permissions are granted.
    @Published var permissionsGranted = false
    
    // MARK: - Public Properties
    
    /// The camera service instance.
    let cameraService: CameraService
    
    /// The configuration.
    let config: MSGMediaCapturerConfig
    
    /// Callback when media is captured.
    var onCapture: ((PickedMedia) -> Void)?
    
    /// Callback when capture is cancelled.
    var onCancel: (() -> Void)?
    
    /// Callback when an error occurs.
    var onError: ((Error) -> Void)?
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var recordingTimer: Timer?
    private var zoomHideTask: Task<Void, Never>?
    
    // MARK: - Computed Properties
    
    /// Formatted recording time string.
    var formattedRecordingTime: String {
        let minutes = Int(recordingTime) / 60
        let seconds = Int(recordingTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Formatted max duration string, if configured.
    var formattedMaxDuration: String? {
        guard let maxDuration = config.maxVideoDuration else { return nil }
        let minutes = Int(maxDuration) / 60
        let seconds = Int(maxDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Whether only photo mode is available.
    var isPhotoOnly: Bool {
        config.allowsPhoto && !config.allowsVideo
    }
    
    /// Whether only video mode is available.
    var isVideoOnly: Bool {
        !config.allowsPhoto && config.allowsVideo
    }
    
    /// Whether mode selector should be shown.
    var showModeSelector: Bool {
        config.allowsPhoto && config.allowsVideo
    }
    
    // MARK: - Initialization
    
    init(config: MSGMediaCapturerConfig = .init()) {
        self.config = config
        self.cameraService = CameraService()
        
        // Set initial mode based on config
        if isVideoOnly {
            captureMode = .video
        } else {
            captureMode = .photo
        }
        
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Bind camera service properties
        cameraService.$isSessionRunning
            .receive(on: DispatchQueue.main)
            .assign(to: &$isSessionRunning)
        
        cameraService.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)
        
        cameraService.$zoomFactor
            .receive(on: DispatchQueue.main)
            .assign(to: &$zoomFactor)
        
        cameraService.$isFlashAvailable
            .receive(on: DispatchQueue.main)
            .assign(to: &$isFlashAvailable)
        
        cameraService.$currentPosition
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentPosition)
        
        cameraService.$flashMode
            .receive(on: DispatchQueue.main)
            .assign(to: &$flashMode)
        
        // Handle errors
        cameraService.$captureError
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.handleError(error)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Lifecycle
    
    /// Checks permissions and starts the camera session.
    func onAppear() {
        Task {
            await checkPermissionsAndStart()
        }
    }
    
    /// Stops the camera session.
    func onDisappear() {
        stopRecordingTimer()
        cameraService.stopSession()
    }
    
    private func checkPermissionsAndStart() async {
        do {
            try await CameraService.checkPermissions(includeAudio: config.allowsVideo)
            permissionsGranted = true
            permissionsChecked = true
            cameraService.startSession(position: config.preferredCameraPosition)
        } catch {
            permissionsGranted = false
            permissionsChecked = true
            handleError(error)
        }
    }
    
    // MARK: - Actions
    
    /// Captures a photo. Orientation is used for EXIF metadata only (no pixel rotation).
    /// - Parameter orientation: Physical device orientation at capture time.
    func capturePhoto(orientation: AVCaptureVideoOrientation? = nil) {
        guard !isCapturing && !isRecording else { return }
        
        isCapturing = true
        
        cameraService.capturePhoto(orientation: orientation) { [weak self] result in
            guard let self = self else { return }
            
            self.isCapturing = false
            
            switch result {
            case .success(let image):
                let media = PickedMedia(capturedImage: image)
                self.onCapture?(media)
                
            case .failure(let error):
                self.handleError(error)
            }
        }
    }
    
    /// Starts video recording. Orientation is fixed at start (metadata only, no pixel rotation).
    /// - Parameter orientation: Physical device orientation at start of recording.
    func startVideoRecording(orientation: AVCaptureVideoOrientation? = nil) {
        guard !isRecording && !isCapturing else { return }
        guard config.allowsVideo else { return }
        
        cameraService.startRecording(orientation: orientation)
        startRecordingTimer()
    }
    
    /// Stops video recording.
    func stopVideoRecording() {
        guard isRecording else { return }
        
        stopRecordingTimer()
        
        cameraService.stopRecording { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let url):
                // Get video duration
                let asset = AVURLAsset(url: url)
                let duration = asset.duration.seconds
                let media = PickedMedia(capturedVideoURL: url, duration: duration)
                self.onCapture?(media)
                
            case .failure(let error):
                self.handleError(error)
            }
        }
    }
    
    /// Toggles video recording (start if stopped, stop if recording).
    /// - Parameter orientation: Physical device orientation at start of recording (used when starting).
    func toggleVideoRecording(orientation: AVCaptureVideoOrientation? = nil) {
        if isRecording {
            stopVideoRecording()
        } else {
            startVideoRecording(orientation: orientation)
        }
    }
    
    /// Switches between front and back camera.
    func switchCamera() {
        guard !isRecording else { return }
        cameraService.switchCamera()
    }
    
    /// Cycles to the next flash mode.
    func cycleFlashMode() {
        cameraService.cycleFlashMode()
    }
    
    /// Cancels capture and dismisses.
    func cancel() {
        if isRecording {
            // Cancel recording without saving
            cameraService.stopRecording { _ in }
        }
        onCancel?()
    }
    
    // MARK: - Zoom
    
    /// Handles zoom gesture.
    /// - Parameter scale: The gesture scale factor.
    func handleZoomGesture(_ scale: CGFloat) {
        cameraService.setZoom(scale)
        showZoomIndicator = true
        
        // Hide zoom indicator after delay
        zoomHideTask?.cancel()
        zoomHideTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
            guard !Task.isCancelled else { return }
            showZoomIndicator = false
        }
    }
    
    // MARK: - Recording Timer
    
    private func startRecordingTimer() {
        recordingTime = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.recordingTime += 0.1
                
                // Check max duration
                if let maxDuration = self.config.maxVideoDuration,
                   self.recordingTime >= maxDuration {
                    self.stopVideoRecording()
                }
            }
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingTime = 0
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error) {
        if let capturerError = error as? MSGMediaCapturerError {
            errorMessage = capturerError.errorDescription
        } else {
            errorMessage = error.localizedDescription
        }
        onError?(error)
    }
}
