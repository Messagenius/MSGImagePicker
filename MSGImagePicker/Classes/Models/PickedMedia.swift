//
//  PickedMedia.swift
//  MSGImagePicker
//
//  Model representing a selected media item with optional edits.
//

import Foundation
import Photos
import UIKit

// MARK: - Media Source

/// Represents the source of a media item.
public enum MediaSource: Sendable {
    /// Media selected from the Photo Library.
    case library(PHAsset)
    /// Media captured directly from the camera.
    case captured(CapturedMediaData)
}

/// Data for media captured directly from camera.
public struct CapturedMediaData: Sendable {
    /// The captured image (for photos).
    public let image: UIImage?
    /// The URL to the captured video file (for videos).
    public let videoURL: URL?
    /// The duration of the video in seconds. 0 for images.
    public let duration: TimeInterval
    
    /// Creates captured media data for a photo.
    public static func photo(_ image: UIImage) -> CapturedMediaData {
        CapturedMediaData(image: image, videoURL: nil, duration: 0)
    }
    
    /// Creates captured media data for a video.
    public static func video(url: URL, duration: TimeInterval) -> CapturedMediaData {
        CapturedMediaData(image: nil, videoURL: url, duration: duration)
    }
    
    public init(image: UIImage?, videoURL: URL?, duration: TimeInterval) {
        self.image = image
        self.videoURL = videoURL
        self.duration = duration
    }
}

// MARK: - PickedMedia

/// Represents a media item selected by the user.
/// This is the output model returned via the `onSend` callback.
public struct PickedMedia: Identifiable, Sendable {
    
    /// Unique identifier for the media item.
    public let id: String
    
    /// The source of the media (library or captured).
    public let source: MediaSource
    
    /// The edited image, if the user made modifications. Nil if unedited.
    public var editedImage: UIImage?
    
    /// The URL to the edited video file, if the user made modifications. Nil if unedited.
    public var editedVideoURL: URL?
    
    /// Normalized crop rect for video (0...1) in oriented video coordinates.
    public var videoCropNormalizedRect: CGRect?

    /// Video trim start time in seconds. Nil means start from beginning.
    public var trimStart: TimeInterval?
    
    /// Video trim end time in seconds. Nil means end at video duration.
    public var trimEnd: TimeInterval?
    
    /// Whether audio is muted for this video.
    public var isAudioMuted: Bool = false
    
    /// User-entered caption for this media item.
    public var caption: String
    
    /// The order in which this item was selected (1-based).
    public let selectionOrder: Int
    
    /// Whether this media has been edited.
    public var isEdited: Bool {
        editedImage != nil || editedVideoURL != nil || videoCropNormalizedRect != nil || isTrimmed || isAudioMuted
    }
    
    /// Whether the video has been trimmed from its original duration.
    public var isTrimmed: Bool {
        trimStart != nil || trimEnd != nil
    }
    
    /// The effective trim start time (0 if not set).
    public var effectiveTrimStart: TimeInterval {
        trimStart ?? 0
    }
    
    /// The effective trim end time (video duration if not set).
    public var effectiveTrimEnd: TimeInterval {
        trimEnd ?? videoDuration
    }
    
    /// The trimmed video duration in seconds.
    public var trimmedDuration: TimeInterval {
        effectiveTrimEnd - effectiveTrimStart
    }
    
    /// Whether this is a video.
    public var isVideo: Bool {
        switch source {
        case .library(let asset):
            return asset.mediaType == .video
        case .captured(let data):
            return data.videoURL != nil
        }
    }
    
    /// Whether this is an image.
    public var isImage: Bool {
        switch source {
        case .library(let asset):
            return asset.mediaType == .image
        case .captured(let data):
            return data.image != nil
        }
    }
    
    /// The duration of the video in seconds. Returns 0 for images.
    public var videoDuration: TimeInterval {
        switch source {
        case .library(let asset):
            return asset.duration
        case .captured(let data):
            return data.duration
        }
    }
    
    /// Whether this media is from the photo library.
    public var isFromLibrary: Bool {
        if case .library = source { return true }
        return false
    }
    
    /// Whether this media was captured from camera.
    public var isCaptured: Bool {
        if case .captured = source { return true }
        return false
    }
    
    /// The PHAsset if this media is from the library, nil otherwise.
    public var asset: PHAsset? {
        if case .library(let asset) = source { return asset }
        return nil
    }
    
    /// The captured media data if this was captured, nil otherwise.
    public var capturedData: CapturedMediaData? {
        if case .captured(let data) = source { return data }
        return nil
    }
    
    /// The original image for captured photos, nil for library media or videos.
    public var originalCapturedImage: UIImage? {
        capturedData?.image
    }
    
    /// The original video URL for captured videos, nil for library media or photos.
    public var originalCapturedVideoURL: URL? {
        capturedData?.videoURL
    }
    
    // MARK: - Initializers
    
    /// Creates a new PickedMedia instance with a media source.
    /// - Parameters:
    ///   - id: Unique identifier. Auto-generated if nil.
    ///   - source: The source of the media (library or captured).
    ///   - editedImage: Optional edited image.
    ///   - editedVideoURL: Optional URL to edited video.
    ///   - videoCropNormalizedRect: Optional normalized crop rect for video.
    ///   - trimStart: Video trim start time.
    ///   - trimEnd: Video trim end time.
    ///   - isAudioMuted: Whether audio is muted.
    ///   - caption: Caption text. Default is empty.
    ///   - selectionOrder: The selection order (1-based).
    public init(
        id: String? = nil,
        source: MediaSource,
        editedImage: UIImage? = nil,
        editedVideoURL: URL? = nil,
        videoCropNormalizedRect: CGRect? = nil,
        trimStart: TimeInterval? = nil,
        trimEnd: TimeInterval? = nil,
        isAudioMuted: Bool = false,
        caption: String = "",
        selectionOrder: Int
    ) {
        switch source {
        case .library(let asset):
            self.id = id ?? asset.localIdentifier
        case .captured:
            self.id = id ?? UUID().uuidString
        }
        self.source = source
        self.editedImage = editedImage
        self.editedVideoURL = editedVideoURL
        self.videoCropNormalizedRect = videoCropNormalizedRect
        self.trimStart = trimStart
        self.trimEnd = trimEnd
        self.isAudioMuted = isAudioMuted
        self.caption = caption
        self.selectionOrder = selectionOrder
    }
    
    /// Convenience initializer for library media (backward compatibility).
    /// - Parameters:
    ///   - id: Unique identifier (defaults to asset's localIdentifier).
    ///   - asset: The PHAsset from the photo library.
    ///   - editedImage: Optional edited image.
    ///   - editedVideoURL: Optional URL to edited video.
    ///   - videoCropNormalizedRect: Optional normalized crop rect for video.
    ///   - trimStart: Video trim start time.
    ///   - trimEnd: Video trim end time.
    ///   - isAudioMuted: Whether audio is muted.
    ///   - caption: Caption text. Default is empty.
    ///   - selectionOrder: The selection order (1-based).
    public init(
        id: String? = nil,
        asset: PHAsset,
        editedImage: UIImage? = nil,
        editedVideoURL: URL? = nil,
        videoCropNormalizedRect: CGRect? = nil,
        trimStart: TimeInterval? = nil,
        trimEnd: TimeInterval? = nil,
        isAudioMuted: Bool = false,
        caption: String = "",
        selectionOrder: Int
    ) {
        self.init(
            id: id,
            source: .library(asset),
            editedImage: editedImage,
            editedVideoURL: editedVideoURL,
            videoCropNormalizedRect: videoCropNormalizedRect,
            trimStart: trimStart,
            trimEnd: trimEnd,
            isAudioMuted: isAudioMuted,
            caption: caption,
            selectionOrder: selectionOrder
        )
    }
    
    /// Convenience initializer for captured photo.
    /// - Parameters:
    ///   - image: The captured image.
    ///   - caption: Caption text. Default is empty.
    ///   - selectionOrder: The selection order (1-based). Default is 1.
    public init(
        capturedImage image: UIImage,
        caption: String = "",
        selectionOrder: Int = 1
    ) {
        self.init(
            source: .captured(.photo(image)),
            caption: caption,
            selectionOrder: selectionOrder
        )
    }
    
    /// Convenience initializer for captured video.
    /// - Parameters:
    ///   - videoURL: The URL to the captured video file.
    ///   - duration: The duration of the video in seconds.
    ///   - caption: Caption text. Default is empty.
    ///   - selectionOrder: The selection order (1-based). Default is 1.
    public init(
        capturedVideoURL videoURL: URL,
        duration: TimeInterval,
        caption: String = "",
        selectionOrder: Int = 1
    ) {
        self.init(
            source: .captured(.video(url: videoURL, duration: duration)),
            caption: caption,
            selectionOrder: selectionOrder
        )
    }
}

// MARK: - Equatable & Hashable

extension PickedMedia: Equatable {
    public static func == (lhs: PickedMedia, rhs: PickedMedia) -> Bool {
        lhs.id == rhs.id
    }
}

extension PickedMedia: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
