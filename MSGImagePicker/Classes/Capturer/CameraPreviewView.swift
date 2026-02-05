//
//  CameraPreviewView.swift
//  MSGImagePicker
//
//  SwiftUI wrapper for AVCaptureVideoPreviewLayer.
//

import SwiftUI
import AVFoundation

/// A SwiftUI view that displays the camera preview.
struct CameraPreviewView: UIViewRepresentable {
    
    /// The capture session to display.
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        // Show full capture frame (matches photo/video capture area); letterboxing if needed
        view.previewLayer.videoGravity = .resizeAspect
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.previewLayer.session = session
    }
}

/// UIView subclass with AVCaptureVideoPreviewLayer as its layer.
final class CameraPreviewUIView: UIView {
    
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    /// The preview layer.
    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}
