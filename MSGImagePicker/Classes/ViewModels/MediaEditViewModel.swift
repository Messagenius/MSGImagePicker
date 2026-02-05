//
//  MediaEditViewModel.swift
//  MSGImagePicker
//
//  ViewModel for managing media editing state.
//

import Foundation
import Photos
import SwiftUI
import AVFoundation

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
    
    // MARK: - Video Trim Management
    
    /// Whether the current media is a video.
    var currentMediaIsVideo: Bool {
        currentMedia?.isVideo ?? false
    }
    
    /// The duration of the current video in seconds. Returns 0 for images.
    var currentVideoDuration: TimeInterval {
        currentMedia?.videoDuration ?? 0
    }
    
    /// Gets the trim start time for the current video.
    var currentTrimStart: TimeInterval {
        get {
            currentMedia?.effectiveTrimStart ?? 0
        }
        set {
            guard currentIndex >= 0 && currentIndex < mediaItems.count else { return }
            mediaItems[currentIndex].trimStart = newValue > 0 ? newValue : nil
        }
    }
    
    /// Gets the trim end time for the current video.
    var currentTrimEnd: TimeInterval {
        get {
            currentMedia?.effectiveTrimEnd ?? currentVideoDuration
        }
        set {
            guard currentIndex >= 0 && currentIndex < mediaItems.count else { return }
            let duration = currentVideoDuration
            mediaItems[currentIndex].trimEnd = newValue < duration ? newValue : nil
        }
    }
    
    /// Binding for the current video's trim start time.
    var currentTrimStartBinding: Binding<TimeInterval> {
        Binding(
            get: { self.currentTrimStart },
            set: { self.currentTrimStart = $0 }
        )
    }
    
    /// Binding for the current video's trim end time.
    var currentTrimEndBinding: Binding<TimeInterval> {
        Binding(
            get: { self.currentTrimEnd },
            set: { self.currentTrimEnd = $0 }
        )
    }
    
    /// Whether the current video's audio is muted.
    var currentIsAudioMuted: Bool {
        get {
            currentMedia?.isAudioMuted ?? false
        }
        set {
            guard currentIndex >= 0 && currentIndex < mediaItems.count else { return }
            mediaItems[currentIndex].isAudioMuted = newValue
        }
    }
    
    /// Binding for the current video's mute state.
    var currentIsAudioMutedBinding: Binding<Bool> {
        Binding(
            get: { self.currentIsAudioMuted },
            set: { self.currentIsAudioMuted = $0 }
        )
    }

    /// The current video's normalized crop rect (0...1). Nil if not cropped.
    var currentVideoCropNormalizedRect: CGRect? {
        get {
            currentMedia?.videoCropNormalizedRect
        }
        set {
            guard currentIndex >= 0 && currentIndex < mediaItems.count else { return }
            mediaItems[currentIndex].videoCropNormalizedRect = newValue
        }
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
                // Preserve existing edits (caption, editedImage, editedVideoURL, trim settings)
                var preserved = newItem
                preserved.caption = existing.caption
                preserved.editedImage = existing.editedImage
                preserved.editedVideoURL = existing.editedVideoURL
                preserved.videoCropNormalizedRect = existing.videoCropNormalizedRect
                preserved.trimStart = existing.trimStart
                preserved.trimEnd = existing.trimEnd
                preserved.isAudioMuted = existing.isAudioMuted
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

    /// Applies a video crop to the current media item.
    /// - Parameters:
    ///   - url: The URL of the cropped video.
    ///   - normalizedRect: Normalized crop rect (0...1) in oriented video coordinates.
    func applyVideoCrop(url: URL, normalizedRect: CGRect) {
        guard currentIndex >= 0 && currentIndex < mediaItems.count else { return }
        mediaItems[currentIndex].editedVideoURL = url
        mediaItems[currentIndex].videoCropNormalizedRect = normalizedRect
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
    
    /// Loads a thumbnail image for a media item.
    /// - Parameters:
    ///   - media: The media item to load thumbnail for.
    ///   - targetSize: The target size for the thumbnail.
    ///   - completion: Completion handler with the loaded image.
    func loadThumbnail(for media: PickedMedia, targetSize: CGSize = MediaEditViewModel.thumbnailSize, completion: @escaping (UIImage?) -> Void) {
        switch media.source {
        case .library(let asset):
            loadThumbnail(for: asset, targetSize: targetSize, completion: completion)
        case .captured(let data):
            loadCapturedThumbnail(data: data, targetSize: targetSize, completion: completion)
        }
    }
    
    /// Loads a full-size image for a media item.
    /// - Parameters:
    ///   - media: The media item to load.
    ///   - completion: Completion handler with the loaded image.
    func loadFullImage(for media: PickedMedia, completion: @escaping (UIImage?) -> Void) {
        switch media.source {
        case .library(let asset):
            loadFullImage(for: asset, completion: completion)
        case .captured(let data):
            loadCapturedFullImage(data: data, completion: completion)
        }
    }
    
    /// Loads a thumbnail image for a PHAsset.
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
    
    /// Loads a full-size image for a PHAsset.
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
    
    // MARK: - Captured Media Loading
    
    /// Loads a thumbnail for captured media.
    private func loadCapturedThumbnail(data: CapturedMediaData, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) {
        if let image = data.image {
            // For captured photos, resize the image
            let thumbnail = resizeImage(image, to: targetSize)
            completion(thumbnail)
        } else if let videoURL = data.videoURL {
            // For captured videos, generate thumbnail from video
            generateVideoThumbnail(from: videoURL, at: 0, completion: completion)
        } else {
            completion(nil)
        }
    }
    
    /// Loads a full-size image for captured media.
    private func loadCapturedFullImage(data: CapturedMediaData, completion: @escaping (UIImage?) -> Void) {
        if let image = data.image {
            completion(image)
        } else if let videoURL = data.videoURL {
            // For videos, generate a frame from the video
            generateVideoThumbnail(from: videoURL, at: 0, completion: completion)
        } else {
            completion(nil)
        }
    }
    
    /// Resizes an image to fit within the target size while maintaining aspect ratio.
    private func resizeImage(_ image: UIImage, to targetSize: CGSize) -> UIImage {
        let widthRatio = targetSize.width / image.size.width
        let heightRatio = targetSize.height / image.size.height
        let ratio = max(widthRatio, heightRatio)
        
        let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    /// Generates a thumbnail from a video URL.
    private func generateVideoThumbnail(from url: URL, at time: TimeInterval, completion: @escaping (UIImage?) -> Void) {
        Task.detached(priority: .userInitiated) {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 400, height: 400)
            
            let cmTime = CMTime(seconds: time, preferredTimescale: 600)
            
            do {
                let cgImage = try generator.copyCGImage(at: cmTime, actualTime: nil)
                let thumbnail = UIImage(cgImage: cgImage)
                await MainActor.run {
                    completion(thumbnail)
                }
            } catch {
                await MainActor.run {
                    completion(nil)
                }
            }
        }
    }
}
