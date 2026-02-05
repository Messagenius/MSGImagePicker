//
//  InlineVideoPlayer.swift
//  MSGImagePicker
//
//  Custom inline video player without system controls.
//

import SwiftUI
import AVFoundation
import Photos

struct InlineVideoPlayer: View {
    let media: PickedMedia
    let isMuted: Bool
    let trimStart: TimeInterval
    let trimEnd: TimeInterval
    
    @StateObject private var loader = VideoPlayerLoader()
    
    /// The video URL to use (edited or original captured)
    private var effectiveVideoURL: URL? {
        media.editedVideoURL ?? media.originalCapturedVideoURL
    }
    
    var body: some View {
        ZStack {
            if let player = loader.player {
                VideoPlayerView(player: player)
                    .onTapGesture {
                        loader.togglePlay()
                    }
                
                if !loader.isPlaying {
                    playButton
                }
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .onAppear {
            loader.load(
                media: media,
                isMuted: isMuted,
                trimStart: trimStart,
                trimEnd: trimEnd
            )
        }
        .onChange(of: effectiveVideoURL?.absoluteString) { _, _ in
            loader.load(
                media: media,
                isMuted: isMuted,
                trimStart: trimStart,
                trimEnd: trimEnd
            )
        }
        .onChange(of: isMuted) { _, newValue in
            loader.setMuted(newValue)
        }
        .onChange(of: trimStart) { _, _ in
            loader.updateTrim(start: trimStart, end: trimEnd)
        }
        .onChange(of: trimEnd) { _, _ in
            loader.updateTrim(start: trimStart, end: trimEnd)
        }
        .onDisappear {
            loader.pause()
        }
    }
    
    private var playButton: some View {
        Button(action: {
            loader.togglePlay()
        }) {
            Image(systemName: "play.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Color.black.opacity(0.6))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

final class VideoPlayerLoader: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isPlaying: Bool = false
    
    private var timeControlObservation: NSKeyValueObservation?
    private var endObserver: Any?
    private var lastVideoURL: URL?
    private var timeObserver: Any?
    private var trimStart: TimeInterval = 0
    private var trimEnd: TimeInterval = 0
    
    deinit {
        cleanupObservers()
    }
    
    func load(media: PickedMedia, isMuted: Bool, trimStart: TimeInterval, trimEnd: TimeInterval) {
        self.trimStart = trimStart
        self.trimEnd = trimEnd
        
        // Check for edited video URL first
        if let editedURL = media.editedVideoURL {
            if lastVideoURL != editedURL || player == nil {
                lastVideoURL = editedURL
                setPlayer(AVPlayer(url: editedURL), isMuted: isMuted)
            } else {
                setMuted(isMuted)
            }
            return
        }
        
        // Check for captured video URL
        if let capturedURL = media.originalCapturedVideoURL {
            if lastVideoURL != capturedURL || player == nil {
                lastVideoURL = capturedURL
                setPlayer(AVPlayer(url: capturedURL), isMuted: isMuted)
            } else {
                setMuted(isMuted)
            }
            return
        }
        
        // Load from PHAsset (library media)
        guard let asset = media.asset else { return }
        
        lastVideoURL = nil
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { [weak self] avAsset, _, _ in
            guard let self = self else { return }
            guard let avAsset = avAsset else { return }
            
            DispatchQueue.main.async {
                self.setPlayer(AVPlayer(playerItem: AVPlayerItem(asset: avAsset)), isMuted: isMuted)
            }
        }
    }
    
    func togglePlay() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }
    
    func pause() {
        player?.pause()
    }
    
    func setMuted(_ muted: Bool) {
        player?.isMuted = muted
    }

    func updateTrim(start: TimeInterval, end: TimeInterval) {
        trimStart = start
        trimEnd = end
        guard let player = player else { return }
        
        // Pause when user drags trim handles
        player.pause()
        
        let currentTime = player.currentTime().seconds
        if currentTime < trimStart || currentTime > trimEnd {
            player.seek(to: CMTime(seconds: trimStart, preferredTimescale: 600))
        }
    }
    
    private func setPlayer(_ newPlayer: AVPlayer, isMuted: Bool) {
        cleanupObservers()
        player = newPlayer
        player?.isMuted = isMuted
        
        timeControlObservation = player?.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                self?.isPlaying = player.timeControlStatus == .playing
            }
        }
        
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            // Seek to trim start so next play starts from the beginning of the trim range
            self.player?.seek(to: CMTime(seconds: self.trimStart, preferredTimescale: 600))
            self.player?.pause()
        }
        
        addTimeObserver()
        if trimStart > 0 {
            player?.seek(to: CMTime(seconds: trimStart, preferredTimescale: 600))
        }
    }
    
    private func cleanupObservers() {
        timeControlObservation?.invalidate()
        timeControlObservation = nil
        if let timeObserver = timeObserver, let player = player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        if let endObserver = endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }

    private func addTimeObserver() {
        guard let player = player else { return }
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let seconds = time.seconds
            if seconds >= self.trimEnd {
                player.pause()
            }
        }
    }
}

struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }
    
    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.playerLayer.player = player
    }
}

final class PlayerView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }
    
    var playerLayer: AVPlayerLayer {
        layer as? AVPlayerLayer ?? AVPlayerLayer()
    }
}
