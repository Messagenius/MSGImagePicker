//
//  DeviceOrientationManager.swift
//  MSGImagePicker
//
//  Detects physical device orientation for rotating controls (interface stays portrait).
//

import SwiftUI
import CoreMotion

/// Detects physical device orientation and provides rotation angle for controls.
/// Use so each control can rotate around its center while the interface stays portrait.
final class DeviceOrientationManager: ObservableObject {

    /// Rotation angle for controls (apply with .rotationEffect).
    @Published private(set) var iconRotationAngle: Angle = .zero

    private let motionManager = CMMotionManager()
    private let updateInterval: TimeInterval = 0.15

    init() {
        startMonitoring()
    }

    deinit {
        motionManager.stopAccelerometerUpdates()
    }

    private func startMonitoring() {
        guard motionManager.isAccelerometerAvailable else { return }

        motionManager.accelerometerUpdateInterval = updateInterval
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let acceleration = data?.acceleration else { return }
            let newAngle = self.angle(from: acceleration)
            if newAngle != self.iconRotationAngle {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.iconRotationAngle = newAngle
                }
            }
        }
    }

    private func angle(from acceleration: CMAcceleration) -> Angle {
        let threshold: Double = 0.6
        if acceleration.x >= threshold { return .degrees(-90) }
        if acceleration.x <= -threshold { return .degrees(90) }
        if acceleration.y >= threshold { return .degrees(180) }
        if acceleration.y <= -threshold { return .degrees(0) }
        return iconRotationAngle
    }
}
