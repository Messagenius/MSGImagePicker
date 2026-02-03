//
//  PickedMedia.swift
//  MSGImagePicker
//
//  Model representing a selected media item with optional edits.
//

import Foundation
import Photos
import UIKit

/// Represents a media item selected by the user.
/// This is the output model returned via the `onSend` callback.
public struct PickedMedia: Identifiable, Sendable {
    
    /// Unique identifier for the media item.
    public let id: String
    
    /// The original PHAsset from the photo library.
    public let asset: PHAsset
    
    /// The edited image, if the user made modifications. Nil if unedited.
    public var editedImage: UIImage?
    
    /// The URL to the edited video file, if the user made modifications. Nil if unedited.
    public var editedVideoURL: URL?
    
    /// User-entered caption for this media item.
    public var caption: String
    
    /// The order in which this item was selected (1-based).
    public let selectionOrder: Int
    
    /// Whether this media has been edited.
    public var isEdited: Bool {
        editedImage != nil || editedVideoURL != nil
    }
    
    /// Whether this is a video asset.
    public var isVideo: Bool {
        asset.mediaType == .video
    }
    
    /// Whether this is an image asset.
    public var isImage: Bool {
        asset.mediaType == .image
    }
    
    /// The duration of the video in seconds. Returns 0 for images.
    public var videoDuration: TimeInterval {
        asset.duration
    }
    
    /// Creates a new PickedMedia instance.
    /// - Parameters:
    ///   - id: Unique identifier (defaults to asset's localIdentifier).
    ///   - asset: The PHAsset from the photo library.
    ///   - editedImage: Optional edited image.
    ///   - editedVideoURL: Optional URL to edited video.
    ///   - caption: Caption text. Default is empty.
    ///   - selectionOrder: The selection order (1-based).
    public init(
        id: String? = nil,
        asset: PHAsset,
        editedImage: UIImage? = nil,
        editedVideoURL: URL? = nil,
        caption: String = "",
        selectionOrder: Int
    ) {
        self.id = id ?? asset.localIdentifier
        self.asset = asset
        self.editedImage = editedImage
        self.editedVideoURL = editedVideoURL
        self.caption = caption
        self.selectionOrder = selectionOrder
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
