//
//  VideoTrimInfoBar.swift
//  MSGImagePicker
//
//  Info bar displaying mute toggle and duration/size for video trim.
//

import SwiftUI
import Photos

/// A view displaying video trim info: mute button and duration/size label.
struct VideoTrimInfoBar: View {
    
    let media: PickedMedia
    let trimStart: TimeInterval
    let trimEnd: TimeInterval
    @Binding var isMuted: Bool
    
    /// Estimated original file size in bytes (fetched async)
    @State private var originalFileSize: Int64?
    
    private var trimmedDuration: TimeInterval {
        trimEnd - trimStart
    }
    
    private var estimatedSize: Int64? {
        guard let originalSize = originalFileSize else { return nil }
        let originalDuration = media.videoDuration
        guard originalDuration > 0 else { return nil }
        
        let ratio = trimmedDuration / originalDuration
        return Int64(Double(originalSize) * ratio)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Mute button
            muteButton
            
            // Duration and size label
            infoLabel
            
            Spacer()
        }
    }
    
    // MARK: - Mute Button
    
    private var muteButton: some View {
        Button {
            isMuted.toggle()
        } label: {
            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.black.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Info Label
    
    private var infoLabel: some View {
        Text(formattedInfo)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onAppear {
                fetchFileSize()
            }
    }
    
    // MARK: - Formatting
    
    private var formattedInfo: String {
        let durationString = formatDuration(trimmedDuration)
        
        if let size = estimatedSize {
            let sizeString = formatFileSize(size)
            return "\(durationString) • \(sizeString)"
        } else {
            return durationString
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "0:%02d", seconds)
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - File Size Fetching
    
    private func fetchFileSize() {
        switch media.source {
        case .library(let asset):
            let resources = PHAssetResource.assetResources(for: asset)
            
            // Look for the primary video resource
            if let videoResource = resources.first(where: { $0.type == .video }) {
                if let fileSize = videoResource.value(forKey: "fileSize") as? Int64 {
                    originalFileSize = fileSize
                }
            }
            
        case .captured(let data):
            // For captured videos, get file size from URL
            if let url = data.videoURL {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    if let fileSize = attributes[.size] as? Int64 {
                        originalFileSize = fileSize
                    }
                } catch {
                    originalFileSize = nil
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct VideoTrimInfoBar_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var isMuted = false
        
        var body: some View {
            VStack {
                // Mock preview
                HStack(spacing: 12) {
                    Button {
                        isMuted.toggle()
                    } label: {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.black.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    
                    Text("0:16 • 1.3 MB")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    Spacer()
                }
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
