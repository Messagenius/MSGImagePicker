//
//  SelectionModeActionBar.swift
//  MSGImagePicker
//
//  Bottom action bar for selection modification mode with preview strip and Next button.
//

import SwiftUI
import Photos

/// Action bar for the selection modification mode.
/// Shows a horizontal preview strip of selected media and a "Next" button.
struct SelectionModeActionBar: View {
    @ObservedObject var viewModel: MediaPickerViewModel
    let existingSelection: [PickedMedia]
    let onApply: () -> Void
    
    @ScaledMetric private var thumbnailSize: CGFloat = 48
    @ScaledMetric private var horizontalPadding: CGFloat = 12
    @ScaledMetric private var verticalPadding: CGFloat = 10
    
    private var hasSelection: Bool {
        !viewModel.selectedItems.isEmpty
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Preview strip
            if hasSelection {
                previewStrip
            } else {
                Spacer()
            }
            
            // Next button
            nextButton
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(.regularMaterial)
    }
    
    // MARK: - Preview Strip
    
    private var previewStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(viewModel.selectedItems, id: \.id) { item in
                    SelectionPreviewThumbnail(
                        item: item,
                        viewModel: viewModel
                    )
                    .frame(width: thumbnailSize, height: thumbnailSize)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Next Button
    
    private var nextButton: some View {
        Button(action: onApply) {
            Text("Next")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(hasSelection ? Color.accentColor : Color.gray)
                )
        }
        .buttonStyle(.plain)
        .disabled(!hasSelection)
    }
}

// MARK: - Selection Preview Thumbnail

/// A small thumbnail for the selection preview strip.
private struct SelectionPreviewThumbnail: View {
    let item: MediaItem
    @ObservedObject var viewModel: MediaPickerViewModel
    
    @State private var thumbnail: UIImage?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                
                // Video indicator
                if item.isVideo {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.white)
                        .padding(3)
                        .background(Circle().fill(Color.black.opacity(0.6)))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        guard thumbnail == nil else { return }
        
        viewModel.loadThumbnail(for: item.asset, targetSize: CGSize(width: 96, height: 96)) { image in
            Task { @MainActor in
                self.thumbnail = image
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SelectionModeActionBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            SelectionModeActionBar(
                viewModel: MediaPickerViewModel(config: MSGImagePickerConfig()),
                existingSelection: [],
                onApply: {}
            )
        }
    }
}
#endif
