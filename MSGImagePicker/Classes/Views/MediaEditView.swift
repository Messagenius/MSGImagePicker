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
                    // Main content
                    VStack(spacing: 0) {
                        // Media viewer takes all available space
                        mediaViewer
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        // Bottom controls (above safe area)
                        bottomControls
                    }
                    
                    // Top bar overlay
                    topBar
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    // Empty state
                    emptyState
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .fullScreenCover(isPresented: $showSelectionPicker) {
            selectionPicker
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
    
    private var mediaViewer: some View {
        TabView(selection: $viewModel.currentIndex) {
            ForEach(Array(viewModel.mediaItems.enumerated()), id: \.element.id) { index, media in
                MediaViewerItem(media: media, viewModel: viewModel)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut, value: viewModel.currentIndex)
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
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
    
    private var captionField: some View {
        TextField(
            "Add a caption...",
            text: viewModel.currentCaptionBinding,
            axis: .vertical
        )
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
}

// MARK: - Media Viewer Item

/// Individual media item view with zoom support.
private struct MediaViewerItem: View {
    let media: PickedMedia
    @ObservedObject var viewModel: MediaEditViewModel
    
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let displayImage = media.editedImage ?? image {
                    Image(uiImage: displayImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(zoomGesture)
                        .gesture(dragGesture)
                        .onTapGesture(count: 2) {
                            withAnimation {
                                if scale > 1 {
                                    scale = 1
                                    offset = .zero
                                } else {
                                    scale = 2
                                }
                            }
                        }
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onAppear {
            loadImage()
        }
    }
    
    // MARK: - Gestures
    
    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastScale
                lastScale = value
                scale = min(max(scale * delta, 1), 4)
            }
            .onEnded { _ in
                lastScale = 1.0
                if scale < 1 {
                    withAnimation {
                        scale = 1
                        offset = .zero
                    }
                }
            }
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
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
