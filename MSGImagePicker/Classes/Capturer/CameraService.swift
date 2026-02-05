//
//  CameraService.swift
//  MSGImagePicker
//
//  Service for managing AVCaptureSession, photo capture, and video recording.
//

import AVFoundation
import UIKit
import Combine

// MARK: - Flash Mode

/// Flash mode for capture.
enum FlashMode: CaseIterable {
    case auto
    case on
    case off
    
    /// SF Symbol icon name for this mode.
    var iconName: String {
        switch self {
        case .auto: return "bolt.badge.automatic"
        case .on: return "bolt.fill"
        case .off: return "bolt.slash"
        }
    }
    
    /// Convert to AVCaptureDevice.FlashMode.
    var avFlashMode: AVCaptureDevice.FlashMode {
        switch self {
        case .auto: return .auto
        case .on: return .on
        case .off: return .off
        }
    }
    
    /// Convert to AVCaptureDevice.TorchMode (for video).
    var avTorchMode: AVCaptureDevice.TorchMode {
        switch self {
        case .auto: return .auto
        case .on: return .on
        case .off: return .off
        }
    }
    
    /// Cycle to next mode.
    func next() -> FlashMode {
        let all = FlashMode.allCases
        guard let index = all.firstIndex(of: self) else { return .auto }
        let nextIndex = (index + 1) % all.count
        return all[nextIndex]
    }
}

// MARK: - Camera Service

/// Service that manages camera capture session, photo capture, and video recording.
final class CameraService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    /// Whether the capture session is running.
    @Published private(set) var isSessionRunning = false
    
    /// Current flash mode.
    @Published var flashMode: FlashMode = .auto
    
    /// Current camera position.
    @Published private(set) var currentPosition: CameraPosition = .back
    
    /// Whether video recording is in progress.
    @Published private(set) var isRecording = false
    
    /// Current zoom factor.
    @Published private(set) var zoomFactor: CGFloat = 1.0
    
    /// Whether flash is available on the current device.
    @Published private(set) var isFlashAvailable = false
    
    /// Error that occurred during capture.
    @Published var captureError: Error?
    
    // MARK: - Public Properties
    
    /// The capture session for the preview layer.
    let session = AVCaptureSession()
    
    // MARK: - Private Properties
    
    private let sessionQueue = DispatchQueue(label: "com.msgimagepicker.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    
    private var photoCompletion: ((Result<UIImage, Error>) -> Void)?
    private var videoCompletion: ((Result<URL, Error>) -> Void)?
    
    private var minZoomFactor: CGFloat = 1.0
    private var maxZoomFactor: CGFloat = 1.0
    
    // MARK: - Initialization
    
    override init() {
        super.init()
    }
    
    // MARK: - Session Management
    
    /// Configures and starts the capture session.
    /// - Parameter position: Initial camera position.
    func startSession(position: CameraPosition = .back) {
        sessionQueue.async { [weak self] in
            self?.configureSession(position: position)
            self?.session.startRunning()
            
            DispatchQueue.main.async {
                self?.isSessionRunning = self?.session.isRunning ?? false
            }
        }
    }
    
    /// Stops the capture session.
    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
            
            DispatchQueue.main.async {
                self?.isSessionRunning = false
            }
        }
    }
    
    // MARK: - Session Configuration
    
    private func configureSession(position: CameraPosition) {
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        // Add video input
        do {
            try addVideoInput(position: position)
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.captureError = error
            }
            session.commitConfiguration()
            return
        }
        
        // Add audio input for video recording
        addAudioInput()
        
        // Add photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.maxPhotoQualityPrioritization = .balanced
        }
        
        // Add movie output
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            if let connection = movieOutput.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
            }
        }
        
        session.commitConfiguration()
        
        // Update flash availability
        updateFlashAvailability()
    }
    
    private func addVideoInput(position: CameraPosition) throws {
        // Remove existing video input
        if let existingInput = videoDeviceInput {
            session.removeInput(existingInput)
        }
        
        // Get camera device
        guard let videoDevice = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: position.avCapturePosition
        ) else {
            throw MSGMediaCapturerError.cameraUnavailable
        }
        
        let videoInput = try AVCaptureDeviceInput(device: videoDevice)
        
        guard session.canAddInput(videoInput) else {
            throw MSGMediaCapturerError.configurationFailed
        }
        
        session.addInput(videoInput)
        videoDeviceInput = videoInput
        
        DispatchQueue.main.async { [weak self] in
            self?.currentPosition = position
            self?.updateZoomFactorLimits(for: videoDevice)
        }
    }
    
    private func addAudioInput() {
        // Remove existing audio input
        if let existingInput = audioDeviceInput {
            session.removeInput(existingInput)
        }
        
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else { return }
        
        do {
            let audioInput = try AVCaptureDeviceInput(device: audioDevice)
            if session.canAddInput(audioInput) {
                session.addInput(audioInput)
                audioDeviceInput = audioInput
            }
        } catch {
            // Audio input is optional, continue without it
            print("[CameraService] Failed to add audio input: \(error)")
        }
    }
    
    // MARK: - Camera Switch
    
    /// Switches between front and back camera.
    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let newPosition: CameraPosition = self.currentPosition == .back ? .front : .back
            
            self.session.beginConfiguration()
            
            do {
                try self.addVideoInput(position: newPosition)
            } catch {
                DispatchQueue.main.async {
                    self.captureError = error
                }
            }
            
            self.session.commitConfiguration()
            self.updateFlashAvailability()
        }
    }
    
    // MARK: - Flash
    
    /// Cycles to the next flash mode.
    func cycleFlashMode() {
        flashMode = flashMode.next()
    }
    
    private func updateFlashAvailability() {
        guard let device = videoDeviceInput?.device else {
            DispatchQueue.main.async { [weak self] in
                self?.isFlashAvailable = false
            }
            return
        }
        
        let available = device.hasFlash && device.isFlashAvailable
        DispatchQueue.main.async { [weak self] in
            self?.isFlashAvailable = available
        }
    }
    
    // MARK: - Zoom
    
    private func updateZoomFactorLimits(for device: AVCaptureDevice) {
        minZoomFactor = device.minAvailableVideoZoomFactor
        maxZoomFactor = min(device.maxAvailableVideoZoomFactor, 10.0) // Cap at 10x
        zoomFactor = device.videoZoomFactor
    }
    
    /// Sets the zoom factor.
    /// - Parameter factor: The desired zoom factor.
    func setZoom(_ factor: CGFloat) {
        guard let device = videoDeviceInput?.device else { return }
        
        let clampedFactor = max(minZoomFactor, min(factor, maxZoomFactor))
        
        sessionQueue.async { [weak self] in
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clampedFactor
                device.unlockForConfiguration()
                
                DispatchQueue.main.async {
                    self?.zoomFactor = clampedFactor
                }
            } catch {
                print("[CameraService] Failed to set zoom: \(error)")
            }
        }
    }
    
    // MARK: - Photo Capture
    
    /// Captures a photo.
    /// - Parameter completion: Completion handler with the captured image or error.
    func capturePhoto(completion: @escaping (Result<UIImage, Error>) -> Void) {
        guard !isRecording else {
            completion(.failure(MSGMediaCapturerError.captureFailed(underlying: nil)))
            return
        }
        
        photoCompletion = completion
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let settings = AVCapturePhotoSettings()
            
            // Configure flash
            if self.photoOutput.supportedFlashModes.contains(self.flashMode.avFlashMode) {
                settings.flashMode = self.flashMode.avFlashMode
            }
            
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
    
    // MARK: - Video Recording
    
    /// Starts video recording.
    func startRecording() {
        guard !isRecording else { return }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Set torch mode for video
            if let device = self.videoDeviceInput?.device,
               device.hasTorch && device.isTorchAvailable {
                do {
                    try device.lockForConfiguration()
                    device.torchMode = self.flashMode.avTorchMode
                    device.unlockForConfiguration()
                } catch {
                    print("[CameraService] Failed to set torch: \(error)")
                }
            }
            
            // Create temp file URL
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("video_\(UUID().uuidString).mov")
            
            self.movieOutput.startRecording(to: outputURL, recordingDelegate: self)
            
            DispatchQueue.main.async {
                self.isRecording = true
            }
        }
    }
    
    /// Stops video recording.
    /// - Parameter completion: Completion handler with the video URL or error.
    func stopRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        guard isRecording else {
            completion(.failure(MSGMediaCapturerError.captureFailed(underlying: nil)))
            return
        }
        
        videoCompletion = completion
        
        sessionQueue.async { [weak self] in
            self?.movieOutput.stopRecording()
        }
    }
    
    // MARK: - Permissions
    
    /// Checks and requests camera and microphone permissions.
    /// - Parameter includeAudio: Whether to also request microphone access.
    /// - Returns: Whether all required permissions are granted.
    static func checkPermissions(includeAudio: Bool) async throws {
        // Camera permission
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted {
                throw MSGMediaCapturerError.cameraAccessDenied
            }
        default:
            throw MSGMediaCapturerError.cameraAccessDenied
        }
        
        // Microphone permission (for video)
        if includeAudio {
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                break
            case .notDetermined:
                let granted = await AVCaptureDevice.requestAccess(for: .audio)
                if !granted {
                    throw MSGMediaCapturerError.microphoneAccessDenied
                }
            default:
                throw MSGMediaCapturerError.microphoneAccessDenied
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            DispatchQueue.main.async { [weak self] in
                self?.photoCompletion?(.failure(MSGMediaCapturerError.captureFailed(underlying: error)))
                self?.photoCompletion = nil
            }
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            DispatchQueue.main.async { [weak self] in
                self?.photoCompletion?(.failure(MSGMediaCapturerError.captureFailed(underlying: nil)))
                self?.photoCompletion = nil
            }
            return
        }
        
        // Fix orientation for front camera (mirror)
        let finalImage: UIImage
        if currentPosition == .front {
            finalImage = image.withHorizontallyFlippedOrientation()
        } else {
            finalImage = image
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.photoCompletion?(.success(finalImage))
            self?.photoCompletion = nil
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraService: AVCaptureFileOutputRecordingDelegate {
    
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = true
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        // Turn off torch
        if let device = videoDeviceInput?.device, device.hasTorch {
            do {
                try device.lockForConfiguration()
                device.torchMode = .off
                device.unlockForConfiguration()
            } catch {
                print("[CameraService] Failed to turn off torch: \(error)")
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
            
            if let error = error {
                self?.videoCompletion?(.failure(MSGMediaCapturerError.captureFailed(underlying: error)))
            } else {
                self?.videoCompletion?(.success(outputFileURL))
            }
            self?.videoCompletion = nil
        }
    }
}
