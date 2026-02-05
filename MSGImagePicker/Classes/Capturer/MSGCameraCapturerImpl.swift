//
//  MSGCameraCapturerImpl.swift
//  MSGImagePicker
//
//  Default implementation of MSGMediaCapturer protocol.
//

import SwiftUI

/// Default camera capturer implementation using AVFoundation.
///
/// This capturer provides a fullscreen camera UI with:
/// - Photo and video capture
/// - Flash control (auto/on/off)
/// - Front/back camera switching
/// - Pinch-to-zoom
/// - Mode selector (Photo/Video)
/// - Hold-to-record in photo mode
///
/// Usage:
/// ```swift
/// let capturer = MSGCameraCapturerImpl(config: .init())
/// capturer.delegate = self
///
/// // Present the capturer view
/// .fullScreenCover(isPresented: $showCamera) {
///     capturer.makeCapturerView()
/// }
/// ```
public final class MSGCameraCapturerImpl: MSGMediaCapturer {
    
    // MARK: - Properties
    
    /// The delegate to receive capture events.
    public weak var delegate: MSGMediaCapturerDelegate?
    
    /// The configuration for this capturer.
    public let config: MSGMediaCapturerConfig
    
    // MARK: - Private Properties
    
    /// Weak reference to the current view model (for cleanup).
    private weak var currentViewModel: CameraCaptureViewModel?
    
    // MARK: - Initialization
    
    /// Creates a new camera capturer.
    /// - Parameter config: The configuration options. Default allows both photo and video.
    public init(config: MSGMediaCapturerConfig = .init()) {
        self.config = config
    }
    
    // MARK: - MSGMediaCapturer
    
    /// Creates the capture view to be presented.
    /// - Returns: A SwiftUI view wrapped in AnyView for presentation.
    /// The view compensates for device orientation to maintain a portrait-like layout.
    @MainActor
    public func makeCapturerView() -> AnyView {
        let viewModel = CameraCaptureViewModel(config: config)
        currentViewModel = viewModel
        
        // Set up callbacks
        viewModel.onCapture = { [weak self] media in
            guard let self = self else { return }
            self.delegate?.capturer(self, didCapture: media)
        }
        
        viewModel.onCancel = { [weak self] in
            guard let self = self else { return }
            self.delegate?.capturerDidCancel(self)
        }
        
        viewModel.onError = { [weak self] error in
            guard let self = self else { return }
            self.delegate?.capturer(self, didFailWith: error)
        }
        
        return AnyView(
            MSGCameraCaptureView(viewModel: viewModel)
        )
    }
}

// MARK: - Convenience Factory Methods

public extension MSGCameraCapturerImpl {
    
    /// Creates a photo-only capturer.
    /// - Returns: A capturer configured for photo capture only.
    static func photoOnly() -> MSGCameraCapturerImpl {
        MSGCameraCapturerImpl(config: .photoOnly)
    }
    
    /// Creates a video-only capturer.
    /// - Parameter maxDuration: Optional maximum video duration.
    /// - Returns: A capturer configured for video capture only.
    static func videoOnly(maxDuration: TimeInterval? = nil) -> MSGCameraCapturerImpl {
        var config = MSGMediaCapturerConfig.videoOnly
        config.maxVideoDuration = maxDuration
        return MSGCameraCapturerImpl(config: config)
    }
}
