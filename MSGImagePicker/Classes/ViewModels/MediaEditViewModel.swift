//
//  MediaEditViewModel.swift
//  MSGImagePicker
//
//  ViewModel for managing media editing state.
//

import Foundation
import Photos
import SwiftUI

/// ViewModel for the media edit view, managing editing state and media modifications.
@MainActor
final class MediaEditViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The media items being edited.
    @Published var mediaItems: [PickedMedia]
    
    /// Index of the currently displayed media item.
    @Published var currentIndex: Int = 0
    
    /// The current editing mode, if any. Nil when not in editing mode.
    @Published var editingMode: EditingMode?
    
    /// Whether the selection modification picker is being shown.
    @Published var isSelectingMedia: Bool = false
    
    // MARK: - Private Properties
    
    private let imageManager = PHCachingImageManager()
    
    // MARK: - Computed Properties
    
    /// The currently displayed media item.
    var currentMedia: PickedMedia? {
        guard currentIndex >= 0 && currentIndex < mediaItems.count else { return nil }
        return mediaItems[currentIndex]
    }
    
    /// Whether there are any media items.
    var hasMedia: Bool {
        !mediaItems.isEmpty
    }
    
    /// The number of media items.
    var mediaCount: Int {
        mediaItems.count
    }
    
    /// Whether the current media can be deleted (must have at least one remaining).
    var canDeleteCurrent: Bool {
        mediaItems.count > 1
    }
    
    // MARK: - Initialization
    
    /// Creates a new MediaEditViewModel with the given media items.
    /// - Parameter media: The media items to edit.
    init(media: [PickedMedia]) {
        self.mediaItems = media
    }
    
    // MARK: - Caption Management
    
    /// Gets the caption for the current media item.
    var currentCaption: String {
        get {
            currentMedia?.caption ?? ""
        }
        set {
            guard currentIndex >= 0 && currentIndex < mediaItems.count else { return }
            mediaItems[currentIndex].caption = newValue
        }
    }
    
    /// Binding for the current media's caption.
    var currentCaptionBinding: Binding<String> {
        Binding(
            get: { self.currentCaption },
            set: { self.currentCaption = $0 }
        )
    }
    
    // MARK: - Media Management
    
    /// Selects the media at the given index.
    /// - Parameter index: The index of the media to select.
    func selectMedia(at index: Int) {
        guard index >= 0 && index < mediaItems.count else { return }
        currentIndex = index
    }
    
    /// Deletes the media at the given index.
    /// - Parameter index: The index of the media to delete.
    func deleteMedia(at index: Int) {
        guard mediaItems.count > 1 else { return }
        guard index >= 0 && index < mediaItems.count else { return }
        
        mediaItems.remove(at: index)
        
        // Adjust current index if needed
        if currentIndex >= mediaItems.count {
            currentIndex = mediaItems.count - 1
        } else if currentIndex > index {
            currentIndex -= 1
        }
    }
    
    /// Deletes the currently selected media.
    func deleteCurrentMedia() {
        deleteMedia(at: currentIndex)
    }
    
    /// Updates the selection with new media, preserving edits for media that were already selected.
    /// - Parameter newMedia: The new selection of media items.
    func updateSelection(with newMedia: [PickedMedia]) {
        // Create a dictionary of existing media by ID for quick lookup
        let existingMediaById = Dictionary(uniqueKeysWithValues: mediaItems.map { ($0.id, $0) })
        
        // Map new media, preserving edits from existing media
        mediaItems = newMedia.map { newItem in
            if let existing = existingMediaById[newItem.id] {
                // Preserve existing edits (caption, editedImage, editedVideoURL)
                var preserved = newItem
                preserved.caption = existing.caption
                preserved.editedImage = existing.editedImage
                preserved.editedVideoURL = existing.editedVideoURL
                return preserved
            }
            return newItem
        }
        
        // Ensure current index is valid
        if currentIndex >= mediaItems.count {
            currentIndex = max(0, mediaItems.count - 1)
        }
    }
    
    // MARK: - Editing Mode
    
    /// Enters the specified editing mode.
    /// - Parameter mode: The editing mode to enter.
    func enterEditingMode(_ mode: EditingMode) {
        editingMode = mode
    }
    
    /// Exits the current editing mode.
    func exitEditingMode() {
        editingMode = nil
    }
    
    /// Applies an edited image to the current media item.
    /// - Parameter image: The edited image to apply.
    func applyEdit(_ image: UIImage) {
        guard currentIndex >= 0 && currentIndex < mediaItems.count else { return }
        mediaItems[currentIndex].editedImage = image
    }
    
    // MARK: - Selection Modification
    
    /// Opens the media selection picker to modify the current selection.
    func openSelectionPicker() {
        isSelectingMedia = true
    }
    
    /// Closes the media selection picker.
    func closeSelectionPicker() {
        isSelectingMedia = false
    }
    
    // MARK: - Image Loading
    
    /// Thumbnail size for preview strip items.
    nonisolated static let thumbnailSize = CGSize(width: 100, height: 100)
    
    /// Full size for main media viewer.
    nonisolated static let fullSize = CGSize(width: 1200, height: 1200)
    
    /// Loads a thumbnail image for the given asset.
    /// - Parameters:
    ///   - asset: The PHAsset to load.
    ///   - targetSize: The target size for the thumbnail.
    ///   - completion: Completion handler with the loaded image.
    func loadThumbnail(for asset: PHAsset, targetSize: CGSize = MediaEditViewModel.thumbnailSize, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        
        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            completion(image)
        }
    }
    
    /// Loads a full-size image for the given asset.
    /// - Parameters:
    ///   - asset: The PHAsset to load.
    ///   - completion: Completion handler with the loaded image.
    func loadFullImage(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true
        
        imageManager.requestImage(
            for: asset,
            targetSize: Self.fullSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            completion(image)
        }
    }
}
