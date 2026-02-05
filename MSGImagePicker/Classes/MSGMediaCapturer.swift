//
//  MSGMediaCapturer.swift
//  MSGImagePicker
//
//  Abstract interface for media capture implementations.
//

import SwiftUI
import AVFoundation

// MARK: - Camera Position

/// Preferred camera position for capture.
public enum CameraPosition: Sendable {
    case front
    case back
    
    /// Converts to AVCaptureDevice.Position.
    public var avCapturePosition: AVCaptureDevice.Position {
        switch self {
        case .front: return .front
        case .back: return .back
        }
    }
}

// MARK: - Capturer Configuration

/// Configuration options for media capture.
public struct MSGMediaCapturerConfig: Sendable {
    /// Whether photo capture is allowed.
    public var allowsPhoto: Bool
    
    /// Whether video capture is allowed.
    public var allowsVideo: Bool
    
    /// Maximum video duration in seconds. Nil means no limit.
    public var maxVideoDuration: TimeInterval?
    
    /// Preferred camera position to start with.
    public var preferredCameraPosition: CameraPosition
    
    /// Creates a new capturer configuration.
    /// - Parameters:
    ///   - allowsPhoto: Whether photo capture is allowed. Default is true.
    ///   - allowsVideo: Whether video capture is allowed. Default is true.
    ///   - maxVideoDuration: Maximum video duration in seconds. Nil means no limit.
    ///   - preferredCameraPosition: Preferred camera position. Default is .back.
    public init(
        allowsPhoto: Bool = true,
        allowsVideo: Bool = true,
        maxVideoDuration: TimeInterval? = nil,
        preferredCameraPosition: CameraPosition = .back
    ) {
        self.allowsPhoto = allowsPhoto
        self.allowsVideo = allowsVideo
        self.maxVideoDuration = maxVideoDuration
        self.preferredCameraPosition = preferredCameraPosition
    }
    
    /// Configuration for photo-only capture.
    public static var photoOnly: MSGMediaCapturerConfig {
        MSGMediaCapturerConfig(allowsPhoto: true, allowsVideo: false)
    }
    
    /// Configuration for video-only capture.
    public static var videoOnly: MSGMediaCapturerConfig {
        MSGMediaCapturerConfig(allowsPhoto: false, allowsVideo: true)
    }
}

// MARK: - Capturer Errors

/// Errors that can occur during media capture.
public enum MSGMediaCapturerError: Error, LocalizedError {
    /// Camera access was denied by the user.
    case cameraAccessDenied
    /// Microphone access was denied by the user (required for video).
    case microphoneAccessDenied
    /// The device doesn't have a camera.
    case cameraUnavailable
    /// Failed to configure the capture session.
    case configurationFailed
    /// Failed to capture media.
    case captureFailed(underlying: Error?)
    /// Failed to save the captured media.
    case saveFailed(underlying: Error?)
    
    public var errorDescription: String? {
        switch self {
        case .cameraAccessDenied:
            return "Camera access denied. Please enable camera access in Settings."
        case .microphoneAccessDenied:
            return "Microphone access denied. Please enable microphone access in Settings."
        case .cameraUnavailable:
            return "Camera is not available on this device."
        case .configurationFailed:
            return "Failed to configure camera."
        case .captureFailed(let error):
            return "Failed to capture media: \(error?.localizedDescription ?? "Unknown error")"
        case .saveFailed(let error):
            return "Failed to save media: \(error?.localizedDescription ?? "Unknown error")"
        }
    }
}

// MARK: - Capturer Delegate

/// Delegate protocol for receiving capture events.
public protocol MSGMediaCapturerDelegate: AnyObject {
    /// Called when media is captured successfully.
    /// - Parameters:
    ///   - capturer: The capturer that captured the media.
    ///   - media: The captured media item.
    func capturer(_ capturer: any MSGMediaCapturer, didCapture media: PickedMedia)
    
    /// Called when the user cancels capture.
    /// - Parameter capturer: The capturer that was cancelled.
    func capturerDidCancel(_ capturer: any MSGMediaCapturer)
    
    /// Called when capture fails with an error.
    /// - Parameters:
    ///   - capturer: The capturer that failed.
    ///   - error: The error that occurred.
    func capturer(_ capturer: any MSGMediaCapturer, didFailWith error: Error)
}

// MARK: - Media Capturer Protocol

/// Abstract interface for media capture implementations.
///
/// Implement this protocol to provide custom camera capture UI.
/// The capturer is responsible for:
/// - Presenting capture UI
/// - Handling camera/microphone permissions
/// - Capturing photos and/or videos
/// - Returning captured media via the delegate
///
/// Example usage:
/// ```swift
/// let capturer = MyCameraImplementation(config: .init())
/// capturer.delegate = self
/// present(capturer.makeCapturerView())
/// ```
public protocol MSGMediaCapturer: AnyObject {
    /// The delegate to receive capture events.
    var delegate: MSGMediaCapturerDelegate? { get set }
    
    /// The configuration for this capturer.
    var config: MSGMediaCapturerConfig { get }
    
    /// Creates the capture view to be presented.
    /// - Returns: A SwiftUI view wrapped in AnyView for presentation.
    @MainActor
    func makeCapturerView() -> AnyView
}

// MARK: - Default Delegate Implementation

public extension MSGMediaCapturerDelegate {
    /// Default empty implementation for optional error handling.
    func capturer(_ capturer: any MSGMediaCapturer, didFailWith error: Error) {
        // Default: log the error
        print("[MSGMediaCapturer] Capture failed: \(error.localizedDescription)")
    }
}
