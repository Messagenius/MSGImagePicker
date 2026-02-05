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
    
    let asset: PHAsset?
    let videoURL: URL?
    let frameHeight: CGFloat
    
    @State private var frames: [UIImage] = []
    @State private var isLoading = true
    @State private var extractionTask: Task<Void, Never>?
    @State private var currentGenerator: AVAssetImageGenerator?
    
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
                cancelCurrentExtraction()
                frames = []
                extractFrames(count: frameCount)
            }
            .onAppear {
                extractFrames(count: frameCount)
            }
            .onDisappear {
                cancelCurrentExtraction()
            }
        }
        .frame(height: frameHeight)
    }
    
    // MARK: - Frame Calculation
    
    private func calculateFrameCount(for width: CGFloat) -> Int {
        max(1, Int(floor(width / frameWidth)))
    }
    
    // MARK: - Cancellation
    
    private func cancelCurrentExtraction() {
        extractionTask?.cancel()
        extractionTask = nil
        currentGenerator?.cancelAllCGImageGeneration()
        currentGenerator = nil
    }
    
    // MARK: - Frame Extraction
    
    private func extractFrames(count: Int) {
        cancelCurrentExtraction()
        isLoading = true
        
        // If we have a direct video URL, use it
        if let url = videoURL {
            let avAsset = AVURLAsset(url: url)
            extractionTask = Task {
                let extractedFrames = await extractFramesAsync(from: avAsset, count: count)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    frames = extractedFrames
                    isLoading = false
                }
            }
            return
        }
        
        // If we have a PHAsset, request the video from the library
        guard let asset = asset else {
            isLoading = false
            return
        }
        
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .fastFormat  // Use fast format for thumbnails
        
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            guard let avAsset = avAsset else {
                Task { @MainActor in
                    isLoading = false
                }
                return
            }
            
            extractionTask = Task {
                let extractedFrames = await extractFramesAsync(from: avAsset, count: count)
                guard !Task.isCancelled else { return }
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
        // Allow tolerance for much faster frame extraction
        generator.requestedTimeToleranceBefore = CMTime(seconds: 1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 1, preferredTimescale: 600)
        
        // Store reference for cancellation
        await MainActor.run {
            currentGenerator = generator
        }
        
        let duration = try? await asset.load(.duration).seconds
        guard let duration = duration, duration > 0 else { return [] }
        
        // Generate times for all frames
        var times: [NSValue] = []
        for i in 0..<count {
            let progress = Double(i) / Double(max(1, count - 1))
            let time = CMTime(seconds: progress * duration, preferredTimescale: 600)
            times.append(NSValue(time: time))
        }
        
        // Use async batch generation
        return await withCheckedContinuation { continuation in
            var images: [Int: UIImage] = [:]
            var completedCount = 0
            let totalCount = times.count
            
            generator.generateCGImagesAsynchronously(forTimes: times) { requestedTime, cgImage, actualTime, result, error in
                defer {
                    completedCount += 1
                    if completedCount == totalCount {
                        // Sort by index and return
                        let sortedImages = images.keys.sorted().compactMap { images[$0] }
                        continuation.resume(returning: sortedImages)
                    }
                }
                
                // Find index for this time
                let index = times.firstIndex { ($0 as! NSValue).timeValue == requestedTime } ?? 0
                
                if let cgImage = cgImage {
                    images[index] = UIImage(cgImage: cgImage)
                } else {
                    // Use placeholder for failed frames
                    images[index] = self.createPlaceholderImage() ?? UIImage()
                }
            }
        }
    }
    
    private func createPlaceholderImage() -> UIImage? {
        let size = CGSize(width: frameWidth, height: frameHeight)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.darkGray.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
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
