//
//  MediaPreviewStrip.swift
//  MSGImagePicker
//
//  Horizontal strip of media thumbnails for the edit view.
//

import SwiftUI
import Photos

/// Horizontal scrollable strip of media thumbnails with selection and add functionality.
struct MediaPreviewStrip: View {
    @ObservedObject var viewModel: MediaEditViewModel
    let onAddMedia: () -> Void
    
    @ScaledMetric private var thumbnailSize: CGFloat = 60
    @ScaledMetric private var spacing: CGFloat = 8
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    // Media thumbnails
                    ForEach(Array(viewModel.mediaItems.enumerated()), id: \.element.id) { index, media in
                        PreviewThumbnailView(
                            media: media,
                            isSelected: index == viewModel.currentIndex,
                            canDelete: viewModel.canDeleteCurrent && index == viewModel.currentIndex,
                            viewModel: viewModel,
                            onSelect: {
                                viewModel.selectMedia(at: index)
                            },
                            onDelete: {
                                viewModel.deleteMedia(at: index)
                            }
                        )
                        .frame(width: thumbnailSize, height: thumbnailSize)
                        .id(media.id)
                    }
                    
                    // Add button
                    addButton
                        .frame(width: thumbnailSize, height: thumbnailSize)
                }
                .padding(.horizontal)
            }
            .onChange(of: viewModel.currentIndex) { _, newIndex in
                guard newIndex < viewModel.mediaItems.count else { return }
                withAnimation {
                    proxy.scrollTo(viewModel.mediaItems[newIndex].id, anchor: .center)
                }
            }
        }
        .frame(height: thumbnailSize + 16)
    }
    
    // MARK: - Add Button
    
    private var addButton: some View {
        Button(action: onAddMedia) {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5]))
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.secondary)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview Thumbnail View

/// A single thumbnail in the preview strip.
private struct PreviewThumbnailView: View {
    let media: PickedMedia
    let isSelected: Bool
    let canDelete: Bool
    @ObservedObject var viewModel: MediaEditViewModel
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var thumbnail: UIImage?
    
    var body: some View {
        ZStack {
            // Thumbnail image
            thumbnailImage
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                )
            
            // Delete button overlay (centered, only on selected item and when more than one item)
            if canDelete {
                deleteOverlay
            }
            
            // Video indicator
            if media.isVideo && !canDelete {
                videoIndicator
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var thumbnailImage: some View {
        GeometryReader { geometry in
            if let editedImage = media.editedImage {
                Image(uiImage: editedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            } else if let image = thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.5)
                    )
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private var deleteOverlay: some View {
        Button(action: onDelete) {
            ZStack {
                // Semi-transparent background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.4))
                
                // Trash icon centered
                Image(systemName: "trash")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var videoIndicator: some View {
        Image(systemName: "play.fill")
            .font(.system(size: 10))
            .foregroundColor(.white)
            .padding(4)
            .background(Circle().fill(Color.black.opacity(0.6)))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(4)
    }
    
    // MARK: - Thumbnail Loading
    
    private func loadThumbnail() {
        guard thumbnail == nil else { return }
        
        viewModel.loadThumbnail(for: media.asset) { image in
            Task { @MainActor in
                self.thumbnail = image
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct MediaPreviewStrip_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            MediaPreviewStrip(
                viewModel: MediaEditViewModel(media: []),
                onAddMedia: {}
            )
            .background(Color.gray.opacity(0.2))
        }
    }
}
#endif
