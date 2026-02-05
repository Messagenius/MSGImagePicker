//
//  PortraitLockedHostingController.swift
//  MSGImagePicker
//
//  UIHostingController that locks orientation to portrait (like Mijick Camera).
//

import SwiftUI
import UIKit

/// A hosting controller that forces portrait orientation.
/// Use this when presenting camera UI so the interface does not rotate to landscape.
public final class PortraitLockedHostingController<Content: View>: UIHostingController<Content> {

    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .portrait
    }

    public override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        .portrait
    }

    public override var shouldAutorotate: Bool {
        false
    }
}
