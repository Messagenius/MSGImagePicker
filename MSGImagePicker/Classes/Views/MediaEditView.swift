//
//  MediaEditView.swift
//  MSGImagePicker
//
//  View for editing selected media with per-item captions and selection modification.
//

import SwiftUI
import Photos

/// A view for editing selected media items before sending.
///
/// This view displays the selected media with options to:
/// - View and zoom each media item
/// - Edit captions per-media
/// - Remove media from the selection
/// - Add more media via the selection picker
/// - Access editing controls (crop, etc.)
public struct MediaEditView: View {
    
    @StateObject private var viewModel: MediaEditViewModel
    
    private let config: MSGImagePickerConfig
    private let recipientName: String
    private let onDismiss: () -> Void
    private let onSend: ([PickedMedia]) -> Void
    
    @State private var showSelectionPicker: Bool = false
    @State private var scrolledMediaId: String?
    @FocusState private var isCaptionFocused: Bool
    
    /// Image for the crop view (loaded when entering crop mode)
    @State private var cropImage: UIImage?

    /// Whether a video crop export is in progress
    @State private var isExportingVideoCrop: Bool = false

    /// Task for video crop export
    @State private var videoCropTask: Task<Void, Never>?
    
    /// Namespace for matched geometry effect transitions
    @Namespace private var imageTransitionNamespace
    
    /// Creates a new MediaEditView.
    /// - Parameters:
    ///   - media: The media items to edit.
    ///   - config: Configuration options (used for maxSelection when modifying selection).
    ///   - recipientName: Name of the recipient, displayed in the send bar.
    ///   - onDismiss: Callback when the user dismisses the edit view.
    ///   - onSend: Callback when the user sends the edited media.
    public init(
        media: [PickedMedia],
        config: MSGImagePickerConfig = MSGImagePickerConfig(),
        recipientName: String = "",
        onDismiss: @escaping () -> Void,
        onSend: @escaping ([PickedMedia]) -> Void
    ) {
        self._viewModel = StateObject(wrappedValue: MediaEditViewModel(media: media))
        self.config = config
        self.recipientName = recipientName.isEmpty ? config.recipientName : recipientName
        self.onDismiss = onDismiss
        self.onSend = onSend
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                if viewModel.hasMedia {
                    // Check if in editing mode
                    if let editingMode = viewModel.editingMode {
                        editingView(for: editingMode, geometry: geometry)
                            .transition(.opacity.animation(.easeInOut(duration: 0.25)))
                    } else {
                        // Normal media view
                        normalMediaView(geometry: geometry)
                            .transition(.opacity.animation(.easeInOut(duration: 0.25)))
                    }
                } else {
                    // Empty state
                    emptyState
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.editingMode)
        }
        .fullScreenCover(isPresented: $showSelectionPicker) {
            selectionPicker
        }
    }
    
    // MARK: - Normal Media View
    
    @ViewBuilder
    private func normalMediaView(geometry: GeometryProxy) -> some View {
        // Media viewer - full screen, centered, behind all controls
        mediaViewer
            .frame(width: geometry.size.width, height: geometry.size.height)
        
        // Overlay controls with transparent backgrounds
        VStack(spacing: 0) {
            // Top bar
            topBar
            
            // Video trim controls (only for videos) - positioned below top bar
            if viewModel.currentMediaIsVideo, let currentMedia = viewModel.currentMedia {
                videoTrimSection(for: currentMedia)
                    .id(currentMedia.id) // Force view recreation when media changes
                    .padding(.top, 8)
            }
            
            Spacer()
            
            // Bottom controls
            bottomControls
        }
    }
    
    // MARK: - Editing View
    
    @ViewBuilder
    private func editingView(for mode: EditingMode, geometry: GeometryProxy) -> some View {
        switch mode {
        case .crop:
            if let image = cropImage {
                ZStack {
                    CropView(
                        image: image,
                        onCancel: {
                            videoCropTask?.cancel()
                            withAnimation(.easeInOut(duration: 0.25)) {
                                viewModel.exitEditingMode()
                            }
                            cropImage = nil
                        },
                        onDone: { result in
                            handleCropDone(result)
                        }
                    )
                    
                    if isExportingVideoCrop {
                        Color.black.opacity(0.5)
                            .ignoresSafeArea()
                        ProgressView()
                            .tint(.white)
                    }
                }
            } else {
                // Loading state while image loads
                ProgressView()
                    .tint(.white)
                    .onAppear {
                        loadCurrentImageForCrop()
                    }
            }
        }
    }
    
    // MARK: - Image Loading for Crop
    
    private func loadCurrentImageForCrop() {
        guard let currentMedia = viewModel.currentMedia else { return }
        
        // Use edited image if available, otherwise load original
        if let editedImage = currentMedia.editedImage {
            cropImage = editedImage
        } else {
            viewModel.loadFullImage(for: currentMedia.asset) { loadedImage in
                Task { @MainActor in
                    cropImage = loadedImage
                }
            }
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
            
            Spacer()
            
            // Editing controls (only show when not in editing mode)
            if viewModel.editingMode == nil {
                editingControls
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var editingControls: some View {
        HStack(spacing: 12) {
            // Crop button (placeholder - to be implemented later)
            Button(action: { viewModel.enterEditingMode(.crop) }) {
                Image(systemName: "crop")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
        }
    }
    
    // MARK: - Media Viewer
    
    @ViewBuilder
    private var mediaViewer: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(viewModel.mediaItems) { media in
                        MediaViewerItem(
                            media: media,
                            viewModel: viewModel,
                            size: geometry.size,
                            onTap: { isCaptionFocused = false }
                        )
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .id(media.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $scrolledMediaId)
            .onChange(of: scrolledMediaId) { _, newValue in
                if let newId = newValue,
                   let index = viewModel.mediaItems.firstIndex(where: { $0.id == newId }) {
                    viewModel.currentIndex = index
                }
            }
            .onChange(of: viewModel.currentIndex) { _, newIndex in
                let newId = viewModel.mediaItems[safe: newIndex]?.id
                if scrolledMediaId != newId {
                    withAnimation {
                        scrolledMediaId = newId
                    }
                }
            }
            .onAppear {
                // Initialize scroll position
                scrolledMediaId = viewModel.mediaItems[safe: viewModel.currentIndex]?.id
            }
        }
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        VStack(spacing: 12) {
            // Preview strip
            MediaPreviewStrip(
                viewModel: viewModel,
                onAddMedia: { showSelectionPicker = true }
            )
            
            // Caption field
            captionField
            
            // Send bar
            sendBar
        }
        .padding(.bottom)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }
    
    // MARK: - Video Trim Section
    
    @ViewBuilder
    private func videoTrimSection(for media: PickedMedia) -> some View {
        VStack(spacing: 8) {
            // Frame strip with trim handles
            VideoTrimControlsView(
                asset: media.asset,
                videoURL: media.editedVideoURL,
                duration: media.videoDuration,
                trimStart: viewModel.currentTrimStartBinding,
                trimEnd: viewModel.currentTrimEndBinding
            )
            .padding(.horizontal)
            
            // Info bar (mute + duration/size)
            VideoTrimInfoBar(
                asset: media.asset,
                trimStart: viewModel.currentTrimStart,
                trimEnd: viewModel.currentTrimEnd,
                isMuted: viewModel.currentIsAudioMutedBinding
            )
            .padding(.horizontal)
        }
    }
    
    private var captionField: some View {
        TextField(
            "Add a caption...",
            text: viewModel.currentCaptionBinding,
            axis: .vertical
        )
        .focused($isCaptionFocused)
        .textFieldStyle(.plain)
        .lineLimit(1...4)
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.15))
        )
        .foregroundColor(.white)
        .tint(.white)
        .padding(.horizontal)
    }
    
    private var sendBar: some View {
        HStack {
            // Recipient name
            if !recipientName.isEmpty {
                Text(recipientName)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Send button
            Button(action: handleSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white, .blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.5))
            Text("No media selected")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
            Button("Add Media") {
                showSelectionPicker = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Selection Picker
    
    private var selectionPicker: some View {
        MSGImagePickerSelectionMode(
            config: config,
            existingSelection: viewModel.mediaItems,
            onCancel: { showSelectionPicker = false },
            onApply: { newSelection in
                viewModel.updateSelection(with: newSelection)
                showSelectionPicker = false
            }
        )
    }
    
    // MARK: - Actions
    
    private func handleSend() {
        onSend(viewModel.mediaItems)
    }

    // MARK: - Crop Handling

    private func handleCropDone(_ result: CropResult) {
        guard let currentMedia = viewModel.currentMedia else { return }
        
        if currentMedia.isVideo {
            isExportingVideoCrop = true
            videoCropTask?.cancel()
            videoCropTask = Task {
                do {
                    let url = try await VideoCropper.cropVideo(
                        asset: currentMedia.asset,
                        normalizedCropRect: result.normalizedCropRect
                    )
                    
                    await MainActor.run {
                        viewModel.applyVideoCrop(url: url, normalizedRect: result.normalizedCropRect)
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.exitEditingMode()
                        }
                        cropImage = nil
                        isExportingVideoCrop = false
                    }
                } catch {
                    await MainActor.run {
                        isExportingVideoCrop = false
                    }
                }
            }
        } else {
            viewModel.applyEdit(result.croppedImage)
            withAnimation(.easeInOut(duration: 0.25)) {
                viewModel.exitEditingMode()
            }
            cropImage = nil
        }
    }
}

// MARK: - Media Viewer Item

/// Individual media item view with zoom support.
private struct MediaViewerItem: View {
    let media: PickedMedia
    @ObservedObject var viewModel: MediaEditViewModel
    let size: CGSize
    let onTap: () -> Void
    
    @State private var image: UIImage?
    
    var body: some View {
        ZStack {
            if let displayImage = media.editedImage ?? image {
                Image(uiImage: displayImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .contentShape(.rect)
                    .zoomable()
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded { _ in
                                onTap()
                            }
                    )
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .frame(width: size.width, height: size.height)
        .onAppear {
            loadImage()
        }
    }
    
    // MARK: - Image Loading
    
    private func loadImage() {
        guard image == nil else { return }
        
        viewModel.loadFullImage(for: media.asset) { loadedImage in
            Task { @MainActor in
                self.image = loadedImage
            }
        }
    }
}

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

#if DEBUG
struct MediaEditView_Previews: PreviewProvider {
    static var previews: some View {
        MediaEditView(
            media: [],
            recipientName: "John Doe",
            onDismiss: {},
            onSend: { _ in }
        )
    }
}
#endif
