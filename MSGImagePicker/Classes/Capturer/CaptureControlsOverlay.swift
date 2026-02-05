//
//  CaptureControlsOverlay.swift
//  MSGImagePicker
//
//  UI controls overlay for the camera capture view.
//

import SwiftUI

/// Overlay containing all camera capture controls.
/// Used in portrait-locked camera view only. Each control rotates around its center with device orientation.
struct CaptureControlsOverlay: View {

    @ObservedObject var viewModel: CameraCaptureViewModel
    @ObservedObject var orientationManager: DeviceOrientationManager

    private var iconRotation: Angle { orientationManager.iconRotationAngle }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            Spacer()

            if viewModel.showZoomIndicator {
                zoomIndicator
                    .transition(.opacity)
            }

            Spacer()

            bottomControls
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showZoomIndicator)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isRecording)
        .animation(.easeInOut(duration: 0.3), value: iconRotation)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            closeButton

            Spacer()

            if viewModel.isFlashAvailable {
                flashButton
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
    
    private var closeButton: some View {
        Button(action: { viewModel.cancel() }) {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.black.opacity(0.5)))
        }
        .rotationEffect(iconRotation)
    }

    private var flashButton: some View {
        Button(action: { viewModel.cycleFlashMode() }) {
            Image(systemName: viewModel.flashMode.iconName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(viewModel.flashMode == .off ? .white : .yellow)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.black.opacity(0.5)))
        }
        .rotationEffect(iconRotation)
    }
    
    // MARK: - Zoom Indicator
    
    private var zoomIndicator: some View {
        Text(String(format: "%.1fx", viewModel.zoomFactor))
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.black.opacity(0.6)))
            .rotationEffect(iconRotation)
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Recording timer (only when recording)
            if viewModel.isRecording {
                recordingTimer
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            // Mode selector
            if viewModel.showModeSelector && !viewModel.isRecording {
                modeSelector
                    .transition(.opacity)
            }
            
            // Main controls row
            mainControlsRow
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }

    // MARK: - Recording Timer
    
    private var recordingTimer: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
            Text(viewModel.formattedRecordingTime)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
            if let maxDuration = viewModel.formattedMaxDuration {
                Text("/ \(maxDuration)")
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.black.opacity(0.6)))
        .rotationEffect(iconRotation)
    }
    
    // MARK: - Mode Selector
    
    private var modeSelector: some View {
        HStack(spacing: 24) {
            ForEach(CaptureMode.allCases, id: \.self) { mode in
                Button(action: { viewModel.captureMode = mode }) {
                    Text(mode.rawValue)
                        .font(.system(size: 14, weight: viewModel.captureMode == mode ? .bold : .medium))
                        .foregroundColor(viewModel.captureMode == mode ? .yellow : .white)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Main Controls Row
    
    private var mainControlsRow: some View {
        HStack {
            // Switch camera button
            switchCameraButton
            
            Spacer()
            
            // Shutter button
            shutterButton
            
            Spacer()
            
            // Placeholder for symmetry
            Color.clear
                .frame(width: 50, height: 50)
        }
    }
    
    // MARK: - Switch Camera Button
    
    private var switchCameraButton: some View {
        Button(action: { viewModel.switchCamera() }) {
            Image(systemName: "arrow.triangle.2.circlepath.camera")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(Circle().fill(Color.black.opacity(0.5)))
        }
        .disabled(viewModel.isRecording)
        .opacity(viewModel.isRecording ? 0.4 : 1.0)
        .rotationEffect(iconRotation)
    }

    // MARK: - Shutter Button

    private var shutterButton: some View {
        ShutterButton(
            captureMode: viewModel.captureMode,
            isRecording: viewModel.isRecording,
            isCapturing: viewModel.isCapturing,
            onTap: handleShutterTap,
            onLongPressStart: handleLongPressStart,
            onLongPressEnd: handleLongPressEnd
        )
        .rotationEffect(iconRotation)
    }
    
    // MARK: - Shutter Actions
    
    private func handleShutterTap() {
        switch viewModel.captureMode {
        case .photo:
            viewModel.capturePhoto()
        case .video:
            viewModel.toggleVideoRecording()
        }
    }
    
    private func handleLongPressStart() {
        // In photo mode, holding starts video recording
        if viewModel.captureMode == .photo && viewModel.config.allowsVideo {
            viewModel.startVideoRecording()
        }
    }
    
    private func handleLongPressEnd() {
        // Stop recording when released
        if viewModel.isRecording {
            viewModel.stopVideoRecording()
        }
    }
}

// MARK: - Shutter Button

/// The main capture button with support for tap and long press.
private struct ShutterButton: View {
    
    let captureMode: CaptureMode
    let isRecording: Bool
    let isCapturing: Bool
    let onTap: () -> Void
    let onLongPressStart: () -> Void
    let onLongPressEnd: () -> Void
    
    @State private var isPressed = false
    @State private var isLongPress = false
    @State private var longPressTask: Task<Void, Never>?
    
    /// Threshold for long press detection (in seconds)
    private let longPressThreshold: TimeInterval = 0.3
    
    private let outerSize: CGFloat = 80
    private let innerSize: CGFloat = 64
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Color.white, lineWidth: 4)
                .frame(width: outerSize, height: outerSize)
            
            // Inner circle/square
            innerShape
                .frame(width: innerShapeSize, height: innerShapeSize)
                .animation(.easeInOut(duration: 0.15), value: isRecording)
                .animation(.easeInOut(duration: 0.15), value: isPressed)
        }
        .opacity(isCapturing ? 0.6 : 1.0)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isPressed else { return }
                    isPressed = true
                    isLongPress = false
                    
                    // Start timer for long press detection
                    longPressTask = Task {
                        try? await Task.sleep(nanoseconds: UInt64(longPressThreshold * 1_000_000_000))
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            isLongPress = true
                            onLongPressStart()
                        }
                    }
                }
                .onEnded { _ in
                    guard isPressed else { return }
                    
                    // Cancel the long press timer
                    longPressTask?.cancel()
                    longPressTask = nil
                    
                    if isLongPress || isRecording {
                        // Was a long press or recording - stop recording
                        onLongPressEnd()
                    } else {
                        // Was a short tap
                        onTap()
                    }
                    
                    isPressed = false
                    isLongPress = false
                }
        )
        .disabled(isCapturing)
    }
    
    @ViewBuilder
    private var innerShape: some View {
        if isRecording {
            // Recording: red rounded square
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red)
        } else if captureMode == .video {
            // Video mode: red circle
            Circle()
                .fill(Color.red)
        } else {
            // Photo mode: white circle
            Circle()
                .fill(Color.white)
        }
    }
    
    private var innerShapeSize: CGFloat {
        if isRecording {
            return 32 // Smaller square when recording
        } else if isPressed {
            return innerSize - 8 // Slightly smaller when pressed
        } else {
            return innerSize
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CaptureControlsOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CaptureControlsOverlay(
                viewModel: CameraCaptureViewModel(),
                orientationManager: DeviceOrientationManager()
            )
        }
    }
}
#endif
