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
    
    /// Crops a video asset using a normalized crop rect and returns a temporary file URL.
    /// - Parameters:
    ///   - asset: The PHAsset representing the video.
    ///   - normalizedCropRect: Crop rect in normalized coordinates (0...1) based on the oriented video size.
    static func cropVideo(
        asset: PHAsset,
        normalizedCropRect: CGRect
    ) async throws -> URL {
        let avAsset = try await requestAVAsset(for: asset)
        let videoTrack = try videoTrack(from: avAsset)
        
        let orientedSize = orientedVideoSize(for: videoTrack)
        let cropRect = cropRectInOrientedCoordinates(
            normalizedRect: normalizedCropRect,
            orientedSize: orientedSize
        )
        
        let composition = AVMutableVideoComposition()
        composition.renderSize = cropRect.size
        composition.frameDuration = CMTime(value: 1, timescale: 30)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: avAsset.duration)
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        let transform = videoTrack.preferredTransform
            .translatedBy(x: -cropRect.minX, y: -cropRect.minY)
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
    
    private static func orientedVideoSize(for track: AVAssetTrack) -> CGSize {
        let transformed = track.naturalSize.applying(track.preferredTransform)
        return CGSize(width: abs(transformed.width), height: abs(transformed.height))
    }
    
    private static func cropRectInOrientedCoordinates(
        normalizedRect: CGRect,
        orientedSize: CGSize
    ) -> CGRect {
        let clamped = CGRect(
            x: min(max(normalizedRect.origin.x, 0), 1),
            y: min(max(normalizedRect.origin.y, 0), 1),
            width: min(max(normalizedRect.size.width, 0.01), 1),
            height: min(max(normalizedRect.size.height, 0.01), 1)
        )
        
        let originX = clamped.origin.x * orientedSize.width
        let originY = clamped.origin.y * orientedSize.height
        let width = min(clamped.size.width * orientedSize.width, orientedSize.width - originX)
        let height = min(clamped.size.height * orientedSize.height, orientedSize.height - originY)
        
        return CGRect(x: originX, y: originY, width: width, height: height).integral
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
