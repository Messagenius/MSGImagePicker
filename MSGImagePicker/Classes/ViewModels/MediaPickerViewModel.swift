//
//  MediaPickerViewModel.swift
//  MSGImagePicker
//
//  ViewModel for managing media fetching and selection state.
//

import Foundation
import Photos
import SwiftUI
import Combine

/// ViewModel for the media picker, managing photo library access and selection state.
@MainActor
final class MediaPickerViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// All media items available in the photo library.
    @Published private(set) var items: [MediaItem] = []
    
    /// Currently selected media items, ordered by selection.
    @Published private(set) var selectedItems: [MediaItem] = []
    
    /// The shared caption for all selected items.
    @Published var caption: String = ""
    
    /// Authorization status for photo library access.
    @Published private(set) var authorizationStatus: PHAuthorizationStatus = .notDetermined
    
    /// Loading state indicator.
    @Published private(set) var isLoading: Bool = false
    
    /// Error message if something goes wrong.
    @Published private(set) var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let config: MSGImagePickerConfig
    private var fetchResult: PHFetchResult<PHAsset>?
    private let imageManager = PHCachingImageManager()
    
    // MARK: - Initialization
    
    /// Creates a new MediaPickerViewModel with the given configuration.
    /// - Parameter config: The picker configuration.
    init(config: MSGImagePickerConfig) {
        self.config = config
        checkAuthorizationAndFetch()
    }
    
    // MARK: - Public Methods
    
    /// Returns the selection order (1-based) for a given item, or nil if not selected.
    func selectionOrder(for item: MediaItem) -> Int? {
        guard let index = selectedItems.firstIndex(of: item) else { return nil }
        return index + 1
    }
    
    /// Toggles selection state for the given item.
    /// - Parameter item: The media item to toggle.
    func toggleSelection(_ item: MediaItem) {
        if let index = selectedItems.firstIndex(of: item) {
            // Deselect
            selectedItems.remove(at: index)
        } else {
            // Select if under limit
            guard selectedItems.count < config.maxSelection else { return }
            selectedItems.append(item)
        }
    }
    
    /// Whether the given item is currently selected.
    func isSelected(_ item: MediaItem) -> Bool {
        selectedItems.contains(item)
    }
    
    /// Whether more items can be selected.
    var canSelectMore: Bool {
        selectedItems.count < config.maxSelection
    }
    
    /// Clears all selections.
    func clearSelection() {
        selectedItems.removeAll()
        caption = ""
    }
    
    /// Converts selected items to PickedMedia array for output.
    func buildPickedMedia() -> [PickedMedia] {
        selectedItems.enumerated().map { index, item in
            PickedMedia(
                asset: item.asset,
                caption: caption,
                selectionOrder: index + 1
            )
        }
    }
    
    /// Updates the selected items with edited versions.
    /// - Parameter editedMedia: The edited media array from the edit handler.
    func applyEdits(_ editedMedia: [PickedMedia]) {
        // For now, we just keep the selection order intact
        // The editedMedia will be passed to onSend
    }
    
    // MARK: - Photo Library Access
    
    /// Checks authorization and fetches assets if authorized.
    func checkAuthorizationAndFetch() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authorizationStatus = status
        
        switch status {
        case .authorized, .limited:
            fetchAssets()
        case .notDetermined:
            requestAuthorization()
        case .denied, .restricted:
            errorMessage = "Photo library access is required to select media."
        @unknown default:
            break
        }
    }
    
    /// Requests photo library authorization.
    private func requestAuthorization() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            Task { @MainActor in
                self?.authorizationStatus = status
                if status == .authorized || status == .limited {
                    self?.fetchAssets()
                } else {
                    self?.errorMessage = "Photo library access is required to select media."
                }
            }
        }
    }
    
    /// Fetches assets from the photo library based on configuration.
    private func fetchAssets() {
        isLoading = true
        errorMessage = nil
        
        Task.detached(priority: .userInitiated) { [config] in
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            // Build predicate based on config
            var predicates: [NSPredicate] = []
            
            if config.allowsPhoto && config.allowsVideo {
                predicates.append(NSPredicate(format: "mediaType == %d OR mediaType == %d",
                                              PHAssetMediaType.image.rawValue,
                                              PHAssetMediaType.video.rawValue))
            } else if config.allowsPhoto {
                predicates.append(NSPredicate(format: "mediaType == %d",
                                              PHAssetMediaType.image.rawValue))
            } else if config.allowsVideo {
                predicates.append(NSPredicate(format: "mediaType == %d",
                                              PHAssetMediaType.video.rawValue))
            }
            
            if !predicates.isEmpty {
                options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            }
            
            let result = PHAsset.fetchAssets(with: options)
            
            var fetchedItems: [MediaItem] = []
            result.enumerateObjects { asset, _, _ in
                fetchedItems.append(MediaItem(asset: asset))
            }
            let finalItems = fetchedItems
            
            await MainActor.run { [weak self] in
                self?.fetchResult = result
                self?.items = finalItems
                self?.isLoading = false
            }
        }
    }
    
    // MARK: - Image Loading
    
    /// Thumbnail size for grid items.
    nonisolated static let thumbnailSize = CGSize(width: 200, height: 200)
    
    /// Loads a thumbnail image for the given asset.
    /// - Parameters:
    ///   - asset: The PHAsset to load.
    ///   - targetSize: The target size for the thumbnail.
    ///   - completion: Completion handler with the loaded image.
    func loadThumbnail(for asset: PHAsset, targetSize: CGSize = MediaPickerViewModel.thumbnailSize, completion: @escaping (UIImage?) -> Void) {
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
    
    /// Cancels any pending image requests.
    func cancelAllImageRequests() {
        imageManager.stopCachingImagesForAllAssets()
    }
}
