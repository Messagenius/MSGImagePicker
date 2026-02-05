//
//  VideoCropper.swift
//  MSGImagePicker
//
//  Utility to crop videos and export a temporary file.
//

import AVFoundation
import Photos

enum VideoCropperError: Error {
    case assetUnavailable
    case videoTrackUnavailable
    case exportFailed
}

struct VideoCropper {
    
    /// Crops a video from a PickedMedia using a normalized crop rect and returns a temporary file URL.
    /// - Parameters:
    ///   - media: The PickedMedia containing the video.
    ///   - normalizedCropRect: Crop rect in normalized coordinates (0...1) based on the oriented video size.
    static func cropVideo(
        media: PickedMedia,
        normalizedCropRect: CGRect
    ) async throws -> URL {
        let avAsset: AVAsset
        
        switch media.source {
        case .library(let phAsset):
            avAsset = try await requestAVAsset(for: phAsset)
        case .captured(let data):
            guard let videoURL = data.videoURL else {
                throw VideoCropperError.assetUnavailable
            }
            avAsset = AVURLAsset(url: videoURL)
        }
        
        return try await cropAVAsset(avAsset, normalizedCropRect: normalizedCropRect)
    }
    
    /// Crops a video asset using a normalized crop rect and returns a temporary file URL.
    /// - Parameters:
    ///   - asset: The PHAsset representing the video.
    ///   - normalizedCropRect: Crop rect in normalized coordinates (0...1) based on the oriented video size.
    static func cropVideo(
        asset: PHAsset,
        normalizedCropRect: CGRect
    ) async throws -> URL {
        let avAsset = try await requestAVAsset(for: asset)
        return try await cropAVAsset(avAsset, normalizedCropRect: normalizedCropRect)
    }
    
    /// Internal method to crop an AVAsset.
    private static func cropAVAsset(
        _ avAsset: AVAsset,
        normalizedCropRect: CGRect
    ) async throws -> URL {
        let videoTrack = try videoTrack(from: avAsset)
        
        let orientedBounds = orientedVideoBounds(for: videoTrack)
        let cropRect = cropRectInOrientedCoordinates(
            normalizedRect: normalizedCropRect,
            orientedBounds: orientedBounds
        )
        
        // renderSize must have even width/height for H.264
        let renderSize = evenSized(cropRect.size)
        let scaleToRender = CGSize(
            width: cropRect.width > 0 ? renderSize.width / cropRect.width : 1,
            height: cropRect.height > 0 ? renderSize.height / cropRect.height : 1
        )
        
        let composition = AVMutableVideoComposition()
        composition.renderSize = renderSize
        composition.frameDuration = CMTime(value: 1, timescale: 30)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: avAsset.duration)
        
        // Transform: natural → oriented (preferredTransform), then translate so crop origin → (0,0).
        // A.concatenating(B) applies A first, then B. So we do:
        // preferredTransform.concatenating(translate) → first rotate/orient, then translate to crop origin.
        // Then scale for even dimensions if needed.
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        var transform = videoTrack.preferredTransform
            .concatenating(CGAffineTransform(translationX: -cropRect.minX, y: -cropRect.minY))
        if scaleToRender.width != 1 || scaleToRender.height != 1 {
            transform = transform
                .concatenating(CGAffineTransform(scaleX: scaleToRender.width, y: scaleToRender.height))
        }
        layerInstruction.setTransform(transform, at: .zero)
        
        instruction.layerInstructions = [layerInstruction]
        composition.instructions = [instruction]
        
        let outputURL = temporaryOutputURL()
        let exporter = try makeExporter(asset: avAsset, outputURL: outputURL)
        exporter.videoComposition = composition
        
        return try await export(exporter: exporter)
    }
    
    // MARK: - AVAsset Loading
    
    private static func requestAVAsset(for asset: PHAsset) async throws -> AVAsset {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                if let avAsset = avAsset {
                    continuation.resume(returning: avAsset)
                } else {
                    continuation.resume(throwing: VideoCropperError.assetUnavailable)
                }
            }
        }
    }
    
    private static func videoTrack(from asset: AVAsset) throws -> AVAssetTrack {
        guard let track = asset.tracks(withMediaType: .video).first else {
            throw VideoCropperError.videoTrackUnavailable
        }
        return track
    }
    
    // MARK: - Crop Geometry
    
    /// Bounding rect of the video frame in "oriented" (display) coordinates after preferredTransform.
    /// Origin can be non-zero (e.g. after 90° rotation). Use this when converting normalized crop to pixel rect.
    private static func orientedVideoBounds(for track: AVAssetTrack) -> CGRect {
        let naturalRect = CGRect(origin: .zero, size: track.naturalSize)
        let transformed = naturalRect.applying(track.preferredTransform)
        // Bounding rect: transformed can have negative width/height
        let minX = min(transformed.minX, transformed.maxX)
        let minY = min(transformed.minY, transformed.maxY)
        let width = abs(transformed.width)
        let height = abs(transformed.height)
        return CGRect(x: minX, y: minY, width: width, height: height)
    }
    
    /// Converts normalized crop rect (0,0)=top-left from CropView to oriented (preferredTransform) pixel rect.
    private static func cropRectInOrientedCoordinates(
        normalizedRect: CGRect,
        orientedBounds: CGRect
    ) -> CGRect {
        let size = orientedBounds.size
        let clamped = CGRect(
            x: min(max(normalizedRect.origin.x, 0), 1),
            y: min(max(normalizedRect.origin.y, 0), 1),
            width: min(max(normalizedRect.size.width, 0.01), 1),
            height: min(max(normalizedRect.size.height, 0.01), 1)
        )
        
        let originX = orientedBounds.minX + clamped.origin.x * size.width
        let originY = orientedBounds.minY + clamped.origin.y * size.height
        let cropWidth = min(clamped.size.width * size.width, orientedBounds.maxX - originX)
        let cropHeight = min(clamped.size.height * size.height, orientedBounds.maxY - originY)
        
        return CGRect(x: originX, y: originY, width: cropWidth, height: cropHeight).integral
    }
    
    /// Returns size with even width and height (required by H.264).
    private static func evenSized(_ size: CGSize) -> CGSize {
        CGSize(
            width: max(2, CGFloat(Int(size.width) & ~1)),
            height: max(2, CGFloat(Int(size.height) & ~1))
        )
    }
    
    // MARK: - Export
    
    private static func makeExporter(asset: AVAsset, outputURL: URL) throws -> AVAssetExportSession {
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoCropperError.exportFailed
        }
        
        exporter.outputURL = outputURL
        exporter.outputFileType = .mp4
        exporter.shouldOptimizeForNetworkUse = true
        return exporter
    }
    
    private static func export(exporter: AVAssetExportSession) async throws -> URL {
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                exporter.exportAsynchronously {
                    switch exporter.status {
                    case .completed:
                        if let url = exporter.outputURL {
                            continuation.resume(returning: url)
                        } else {
                            continuation.resume(throwing: VideoCropperError.exportFailed)
                        }
                    case .failed, .cancelled:
                        continuation.resume(throwing: VideoCropperError.exportFailed)
                    default:
                        continuation.resume(throwing: VideoCropperError.exportFailed)
                    }
                }
            }
        }, onCancel: {
            exporter.cancelExport()
        })
    }
    
    private static func temporaryOutputURL() -> URL {
        let filename = "video_crop_\(UUID().uuidString).mp4"
        return FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }
}
