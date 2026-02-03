//
//  MediaItem.swift
//  MSGImagePicker
//
//  Internal model for displaying media in the grid.
//

import Foundation
import Photos
import UIKit

/// Internal model representing a media item in the picker grid.
struct MediaItem: Identifiable, Equatable, Hashable {
    
    /// Unique identifier (PHAsset localIdentifier).
    let id: String
    
    /// The PHAsset reference.
    let asset: PHAsset
    
    /// Whether this is a video.
    var isVideo: Bool {
        asset.mediaType == .video
    }
    
    /// Video duration in seconds (0 for images).
    var duration: TimeInterval {
        asset.duration
    }
    
    /// Formatted duration string for display (e.g., "1:30").
    var formattedDuration: String {
        guard isVideo else { return "" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Creation date of the asset.
    var creationDate: Date? {
        asset.creationDate
    }
    
    /// Pixel width of the asset.
    var pixelWidth: Int {
        asset.pixelWidth
    }
    
    /// Pixel height of the asset.
    var pixelHeight: Int {
        asset.pixelHeight
    }
    
    /// Creates a MediaItem from a PHAsset.
    /// - Parameter asset: The PHAsset to wrap.
    init(asset: PHAsset) {
        self.id = asset.localIdentifier
        self.asset = asset
    }
    
    // MARK: - Equatable & Hashable
    
    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
