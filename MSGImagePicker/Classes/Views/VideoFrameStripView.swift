//
//  VideoFrameStripView.swift
//  MSGImagePicker
//
//  Strip view displaying video frames at regular intervals.
//

import SwiftUI
import AVFoundation
import Photos

/// A view that displays a horizontal strip of video frames extracted at regular intervals.
struct VideoFrameStripView: View {
    
    let asset: PHAsset
    let videoURL: URL?
    let frameHeight: CGFloat
    
    @State private var frames: [UIImage] = []
    @State private var isLoading = true
    
    /// Width of each frame thumbnail
    private let frameWidth: CGFloat = 44
    
    var body: some View {
        GeometryReader { geometry in
            let frameCount = calculateFrameCount(for: geometry.size.width)
            
            ZStack {
                if isLoading && frames.isEmpty {
                    // Loading placeholder
                    HStack(spacing: 0) {
                        ForEach(0..<frameCount, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: frameWidth, height: frameHeight)
                        }
                    }
                } else {
                    // Actual frames
                    HStack(spacing: 0) {
                        ForEach(Array(frames.enumerated()), id: \.offset) { index, frame in
                            Image(uiImage: frame)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: frameWidth, height: frameHeight)
                                .clipped()
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onChange(of: geometry.size.width) { _, newWidth in
                let newCount = calculateFrameCount(for: newWidth)
                if newCount != frames.count {
                    extractFrames(count: newCount)
                }
            }
            .onChange(of: videoURL?.absoluteString) { _, _ in
                frames = []
                extractFrames(count: frameCount)
            }
            .onAppear {
                extractFrames(count: frameCount)
            }
        }
        .frame(height: frameHeight)
    }
    
    // MARK: - Frame Calculation
    
    private func calculateFrameCount(for width: CGFloat) -> Int {
        max(1, Int(floor(width / frameWidth)))
    }
    
    // MARK: - Frame Extraction
    
    private func extractFrames(count: Int) {
        isLoading = true
        
        if let url = videoURL {
            let avAsset = AVAsset(url: url)
            Task {
                let extractedFrames = await extractFramesAsync(from: avAsset, count: count)
                await MainActor.run {
                    frames = extractedFrames
                    isLoading = false
                }
            }
            return
        }
        
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .mediumQualityFormat
        
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            guard let avAsset = avAsset else {
                Task { @MainActor in
                    isLoading = false
                }
                return
            }
            
            Task {
                let extractedFrames = await extractFramesAsync(from: avAsset, count: count)
                await MainActor.run {
                    frames = extractedFrames
                    isLoading = false
                }
            }
        }
    }
    
    private func extractFramesAsync(from asset: AVAsset, count: Int) async -> [UIImage] {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: frameWidth * 2, height: frameHeight * 2)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        
        let duration = asset.duration.seconds
        guard duration > 0 else { return [] }
        
        var images: [UIImage] = []
        
        for i in 0..<count {
            let progress = Double(i) / Double(max(1, count - 1))
            let time = CMTime(seconds: progress * duration, preferredTimescale: 600)
            
            do {
                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                let image = UIImage(cgImage: cgImage)
                images.append(image)
            } catch {
                // If frame extraction fails, add a placeholder
                if let placeholder = createPlaceholderImage() {
                    images.append(placeholder)
                }
            }
        }
        
        return images
    }
    
    private func createPlaceholderImage() -> UIImage? {
        let size = CGSize(width: frameWidth, height: frameHeight)
        UIGraphicsBeginImageContextWithOptions(size, true, 0)
        UIColor.darkGray.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}

// MARK: - Preview

#if DEBUG
struct VideoFrameStripView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview requires a real PHAsset, showing placeholder
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(height: 50)
            .padding()
            .background(Color.black)
    }
}
#endif
