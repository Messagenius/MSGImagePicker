//
//  MediaGridView.swift
//  MSGImagePicker
//
//  Grid view displaying all available media items.
//

import SwiftUI

/// Displays a scrollable grid of media items from the photo library.
struct MediaGridView: View {
    @EnvironmentObject private var viewModel: MediaPickerViewModel
    
    /// Number of columns in the grid. Adapts to available width.
    private let spacing: CGFloat = 2
    
    var body: some View {
        GeometryReader { geometry in
            let columns = calculateColumns(for: geometry.size.width)
            
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns),
                    spacing: spacing
                ) {
                    ForEach(viewModel.items) { item in
                        MediaGridItemView(
                            item: item,
                            selectionOrder: viewModel.selectionOrder(for: item),
                            canSelect: viewModel.canSelectMore,
                            onTap: {
                                viewModel.toggleSelection(item)
                            }
                        )
                    }
                }
                .padding(spacing)
            }
        }
    }
    
    /// Calculates the number of columns based on available width.
    /// - Parameter width: The available width.
    /// - Returns: Number of columns (minimum 3).
    private func calculateColumns(for width: CGFloat) -> Int {
        // Target item size around 120pt, minimum 3 columns
        let targetSize: CGFloat = 120
        let count = max(3, Int(width / targetSize))
        return count
    }
}

// MARK: - Preview

#if DEBUG
struct MediaGridView_Previews: PreviewProvider {
    static var previews: some View {
        MediaGridView()
            .environmentObject(MediaPickerViewModel(config: MSGImagePickerConfig()))
    }
}
#endif
