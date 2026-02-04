//
//  MSGImagePickerConfig.swift
//  MSGImagePicker
//
//  Configuration options for the media picker.
//

import Foundation
import Photos
import UIKit

/// Configuration for MSGImagePicker behavior and appearance.
public struct MSGImagePickerConfig {
    
    /// Maximum number of items that can be selected. Default is 10.
    public var maxSelection: Int
    
    /// Whether video selection is allowed. Default is true.
    public var allowsVideo: Bool
    
    /// Whether photo selection is allowed. Default is true.
    public var allowsPhoto: Bool
    
    /// Whether to show the caption input field in the action bar. Default is true.
    public var showsCaptions: Bool
    
    /// Name of the recipient, displayed in the send bar of the edit view. Default is empty.
    public var recipientName: String
    
    /// Optional handler for editing selected media.
    /// When provided, the Edit button will invoke this handler with the current selection.
    /// The handler should return the edited media array.
    public var editHandler: (([PickedMedia]) async -> [PickedMedia])?
    
    /// Creates a new configuration with the specified options.
    /// - Parameters:
    ///   - maxSelection: Maximum number of selectable items. Default is 10.
    ///   - allowsVideo: Allow video selection. Default is true.
    ///   - allowsPhoto: Allow photo selection. Default is true.
    ///   - showsCaptions: Show caption input field. Default is true.
    ///   - recipientName: Name of the recipient for the edit view. Default is empty.
    ///   - editHandler: Optional async handler for editing media.
    public init(
        maxSelection: Int = 10,
        allowsVideo: Bool = true,
        allowsPhoto: Bool = true,
        showsCaptions: Bool = true,
        recipientName: String = "",
        editHandler: (([PickedMedia]) async -> [PickedMedia])? = nil
    ) {
        self.maxSelection = maxSelection
        self.allowsVideo = allowsVideo
        self.allowsPhoto = allowsPhoto
        self.showsCaptions = showsCaptions
        self.recipientName = recipientName
        self.editHandler = editHandler
    }
    
    /// The media types to fetch based on current configuration.
    var mediaTypes: [PHAssetMediaType] {
        var types: [PHAssetMediaType] = []
        if allowsPhoto { types.append(.image) }
        if allowsVideo { types.append(.video) }
        return types
    }
}
