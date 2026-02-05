//
//  VideoTrimControlsView.swift
//  MSGImagePicker
//
//  Video trim controls with frame strip, draggable handles, and selection overlay.
//

import SwiftUI
import Photos

/// A view that displays video trim controls with a frame strip and draggable handles.
struct VideoTrimControlsView: View {
    
    let media: PickedMedia
    
    @Binding var trimStart: TimeInterval
    @Binding var trimEnd: TimeInterval
    
    /// The video duration from the media
    private var duration: TimeInterval {
        media.videoDuration
    }
    
    /// The PHAsset if from library
    private var asset: PHAsset? {
        media.asset
    }
    
    /// The video URL (edited or original captured)
    private var videoURL: URL? {
        media.editedVideoURL ?? media.originalCapturedVideoURL
    }
    
    /// Minimum selection duration in seconds
    private let minimumDuration: TimeInterval = 1.0
    
    /// Height of the frame strip
    private let stripHeight: CGFloat = 50
    
    /// Width of each handle
    private let handleWidth: CGFloat = 20
    
    /// Whether the trim has been modified from full selection
    private var isModified: Bool {
        trimStart > 0 || trimEnd < duration
    }
    
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width - (handleWidth * 2)
            
            ZStack(alignment: .leading) {
                // Frame strip (background)
                VideoFrameStripView(asset: asset, videoURL: videoURL, frameHeight: stripHeight)
                    .padding(.horizontal, handleWidth)
                
                // Non-selected overlay (left side)
                nonSelectedOverlay(
                    width: leftOverlayWidth(availableWidth: availableWidth),
                    alignment: .leading
                )
                .padding(.leading, handleWidth)
                
                // Non-selected overlay (right side)
                nonSelectedOverlay(
                    width: rightOverlayWidth(availableWidth: availableWidth),
                    alignment: .trailing
                )
                .padding(.trailing, handleWidth)
                
                // Selection border
                selectionBorder(availableWidth: availableWidth)
                
                // Left handle
                trimHandle(isLeft: true, availableWidth: availableWidth)
                
                // Right handle
                trimHandle(isLeft: false, availableWidth: availableWidth)
            }
        }
        .frame(height: stripHeight)
    }
    
    // MARK: - Overlay Calculations
    
    private func leftOverlayWidth(availableWidth: CGFloat) -> CGFloat {
        let progress = trimStart / duration
        return availableWidth * progress
    }
    
    private func rightOverlayWidth(availableWidth: CGFloat) -> CGFloat {
        let progress = (duration - trimEnd) / duration
        return availableWidth * progress
    }
    
    // MARK: - Non-Selected Overlay
    
    @ViewBuilder
    private func nonSelectedOverlay(width: CGFloat, alignment: Alignment) -> some View {
        if width > 0 {
            Rectangle()
                .fill(Color.white.opacity(0.5))
                .frame(width: width, height: stripHeight)
                .frame(maxWidth: .infinity, alignment: alignment)
                .allowsHitTesting(false)
        }
    }
    
    // MARK: - Selection Border
    
    @ViewBuilder
    private func selectionBorder(availableWidth: CGFloat) -> some View {
        let leftOffset = handleWidth + leftOverlayWidth(availableWidth: availableWidth)
        let selectionWidth = availableWidth - leftOverlayWidth(availableWidth: availableWidth) - rightOverlayWidth(availableWidth: availableWidth)
        
        RoundedRectangle(cornerRadius: 4)
            .strokeBorder(
                isModified ? Color.yellow : Color.black,
                lineWidth: 2
            )
            .frame(width: selectionWidth + handleWidth * 2, height: stripHeight)
            .offset(x: leftOffset - handleWidth)
            .allowsHitTesting(false)
    }
    
    // MARK: - Trim Handle
    
    @ViewBuilder
    private func trimHandle(isLeft: Bool, availableWidth: CGFloat) -> some View {
        let xOffset: CGFloat = isLeft
            ? leftOverlayWidth(availableWidth: availableWidth)
            : handleWidth + availableWidth - rightOverlayWidth(availableWidth: availableWidth)
        
        TrimHandleView(isLeft: isLeft)
            .frame(width: handleWidth, height: stripHeight)
            .offset(x: xOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        handleDrag(value: value, isLeft: isLeft, availableWidth: availableWidth)
                    }
            )
    }
    
    // MARK: - Drag Handling
    
    private func handleDrag(value: DragGesture.Value, isLeft: Bool, availableWidth: CGFloat) {
        let dragPosition = value.location.x
        let progress = max(0, min(1, dragPosition / availableWidth))
        let time = progress * duration
        
        if isLeft {
            // Left handle: can't go past right handle minus minimum duration
            let maxStart = trimEnd - minimumDuration
            trimStart = max(0, min(maxStart, time))
        } else {
            // Right handle: can't go before left handle plus minimum duration
            let minEnd = trimStart + minimumDuration
            trimEnd = max(minEnd, min(duration, time))
        }
    }
}

// MARK: - Trim Handle View

/// A single trim handle with chevron appearance.
private struct TrimHandleView: View {
    let isLeft: Bool
    
    var body: some View {
        ZStack {
            // Handle background
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.yellow)
            
            // Chevron icon
            Image(systemName: isLeft ? "chevron.compact.left" : "chevron.compact.right")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct VideoTrimControlsView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var trimStart: TimeInterval = 0
        @State private var trimEnd: TimeInterval = 10
        
        var body: some View {
            VStack {
                // Mock preview - requires real PHAsset
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 50)
                    .overlay(
                        Text("VideoTrimControlsView Preview")
                            .foregroundColor(.white)
                    )
            }
            .padding()
            .background(Color.black)
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
    }
}
#endif
