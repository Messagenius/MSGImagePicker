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
    let asset: PHAsset
    let editedVideoURL: URL?
    let isMuted: Bool
    
    @StateObject private var loader = VideoPlayerLoader()
    
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
            loader.load(asset: asset, editedVideoURL: editedVideoURL, isMuted: isMuted)
        }
        .onChange(of: editedVideoURL?.absoluteString) { _, _ in
            loader.load(asset: asset, editedVideoURL: editedVideoURL, isMuted: isMuted)
        }
        .onChange(of: isMuted) { _, newValue in
            loader.setMuted(newValue)
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
    private var lastEditedURL: URL?
    
    deinit {
        cleanupObservers()
    }
    
    func load(asset: PHAsset, editedVideoURL: URL?, isMuted: Bool) {
        if let url = editedVideoURL {
            if lastEditedURL != url || player == nil {
                lastEditedURL = url
                setPlayer(AVPlayer(url: url), isMuted: isMuted)
            } else {
                setMuted(isMuted)
            }
            return
        }
        
        lastEditedURL = nil
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
            self?.player?.seek(to: .zero)
            self?.player?.pause()
        }
    }
    
    private func cleanupObservers() {
        timeControlObservation?.invalidate()
        timeControlObservation = nil
        if let endObserver = endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
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
