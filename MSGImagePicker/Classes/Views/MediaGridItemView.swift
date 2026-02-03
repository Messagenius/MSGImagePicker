//
//  MediaGridItemView.swift
//  MSGImagePicker
//
//  A single grid item displaying a media thumbnail with selection badge.
//

import SwiftUI
import Photos

/// Displays a single media item in the picker grid.
struct MediaGridItemView: View {
    let item: MediaItem
    let selectionOrder: Int?
    let canSelect: Bool
    let onTap: () -> Void
    
    @State private var thumbnail: UIImage?
    @EnvironmentObject private var viewModel: MediaPickerViewModel
    
    private var isSelected: Bool {
        selectionOrder != nil
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                // Thumbnail
                thumbnailView
                    .frame(width: geometry.size.width, height: geometry.size.height)
                
                // Video duration overlay
                if item.isVideo {
                    videoDurationOverlay
                }
                
                // Selection badge
                if let order = selectionOrder {
                    selectionBadge(order: order)
                }
                
                // Dimmed overlay when can't select more
                if !isSelected && !canSelect {
                    Color.black.opacity(0.4)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(isSelected ? Color.green : Color.clear, lineWidth: 3)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if canSelect || isSelected {
                    onTap()
                }
            }
            .onAppear {
                loadThumbnail(size: geometry.size)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var thumbnailView: some View {
        if let image = thumbnail {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .overlay(
                    ProgressView()
                        .tint(.white)
                )
        }
    }
    
    private var videoDurationOverlay: some View {
        HStack(spacing: 4) {
            Image(systemName: "play.fill")
                .font(.system(size: 10))
            Text(item.formattedDuration)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.6))
        )
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }
    
    private func selectionBadge(order: Int) -> some View {
        Text("\(order)")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 24, height: 24)
            .background(Circle().fill(Color.green))
            .padding(6)
    }
    
    // MARK: - Thumbnail Loading
    
    private func loadThumbnail(size: CGSize) {
        guard thumbnail == nil else { return }
        
        let scale = UIScreen.main.scale
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        viewModel.loadThumbnail(for: item.asset, targetSize: targetSize) { image in
            Task { @MainActor in
                self.thumbnail = image
            }
        }
    }
}
