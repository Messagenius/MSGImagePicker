//
//  MSGImagePicker.swift
//  MSGImagePicker
//
//  Public entry point for the media picker library.
//

import SwiftUI
import Photos

/// A SwiftUI media picker for selecting photos and videos from the photo library.
///
/// MSGImagePicker provides a grid-based interface for browsing and selecting media
/// from the device's photo library. It supports multi-selection with visual ordering,
/// an optional caption input, and is presentation-agnostic.
///
/// ## Usage
///
/// ```swift
/// MSGImagePicker(
///     config: MSGImagePickerConfig(maxSelection: 5),
///     onCancel: { /* dismiss */ },
///     onSend: { selectedMedia in
///         // Handle selected media
///     }
/// )
/// ```
///
/// The view can be presented as a sheet, fullscreen cover, or pushed onto a navigation stack.
public struct MSGImagePicker: View {
    
    private let config: MSGImagePickerConfig
    private let onCancel: () -> Void
    private let onSend: ([PickedMedia]) -> Void
    
    @StateObject private var viewModel: MediaPickerViewModel
    
    /// Creates a new MSGImagePicker instance.
    ///
    /// - Parameters:
    ///   - config: Configuration options for the picker. Default values allow
    ///     selection of up to 10 photos and videos with captions enabled.
    ///   - onCancel: Callback invoked when the user taps the Cancel button.
    ///   - onSend: Callback invoked when the user taps the Send button,
    ///     receiving the array of selected media items in selection order.
    public init(
        config: MSGImagePickerConfig = MSGImagePickerConfig(),
        onCancel: @escaping () -> Void,
        onSend: @escaping ([PickedMedia]) -> Void
    ) {
        self.config = config
        self.onCancel = onCancel
        self.onSend = onSend
        self._viewModel = StateObject(wrappedValue: MediaPickerViewModel(config: config))
    }
    
    public var body: some View {
        NavigationStack {
            MediaPickerView(
                config: config,
                onCancel: onCancel,
                onSend: onSend
            )
            .environmentObject(viewModel)
        }
    }
}

// MARK: - Convenience Extensions

public extension MSGImagePicker {
    
    /// Creates a picker configured for photos only.
    /// - Parameters:
    ///   - maxSelection: Maximum number of photos to select.
    ///   - onCancel: Cancel callback.
    ///   - onSend: Send callback with selected photos.
    /// - Returns: A configured MSGImagePicker instance.
    static func photosOnly(
        maxSelection: Int = 10,
        onCancel: @escaping () -> Void,
        onSend: @escaping ([PickedMedia]) -> Void
    ) -> MSGImagePicker {
        MSGImagePicker(
            config: MSGImagePickerConfig(
                maxSelection: maxSelection,
                allowsVideo: false,
                allowsPhoto: true
            ),
            onCancel: onCancel,
            onSend: onSend
        )
    }
    
    /// Creates a picker configured for videos only.
    /// - Parameters:
    ///   - maxSelection: Maximum number of videos to select.
    ///   - onCancel: Cancel callback.
    ///   - onSend: Send callback with selected videos.
    /// - Returns: A configured MSGImagePicker instance.
    static func videosOnly(
        maxSelection: Int = 10,
        onCancel: @escaping () -> Void,
        onSend: @escaping ([PickedMedia]) -> Void
    ) -> MSGImagePicker {
        MSGImagePicker(
            config: MSGImagePickerConfig(
                maxSelection: maxSelection,
                allowsVideo: true,
                allowsPhoto: false
            ),
            onCancel: onCancel,
            onSend: onSend
        )
    }
}

// MARK: - Preview

#if DEBUG
struct MSGImagePicker_Previews: PreviewProvider {
    static var previews: some View {
        MSGImagePicker(
            config: MSGImagePickerConfig(),
            onCancel: {},
            onSend: { _ in }
        )
    }
}
#endif
