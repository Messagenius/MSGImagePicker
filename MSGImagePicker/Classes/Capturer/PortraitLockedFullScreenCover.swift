//
//  PortraitLockedFullScreenCover.swift
//  MSGImagePicker
//
//  Presents SwiftUI content in a portrait-locked full-screen modal (like Mijick Camera).
//

import SwiftUI
import UIKit

/// Presents content in a full-screen modal that is locked to portrait orientation.
/// Use instead of `.fullScreenCover` when the content must not rotate (e.g. camera).
public struct PortraitLockedFullScreenCover<Content: View>: UIViewControllerRepresentable {

    @Binding var isPresented: Bool
    let content: (@escaping DismissAction) -> Content

    public typealias DismissAction = () -> Void

    public init(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping (@escaping DismissAction) -> Content
    ) {
        _isPresented = isPresented
        self.content = content
    }

    public func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        return vc
    }

    public func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        let coordinator = context.coordinator
        coordinator.binding = $isPresented

        if isPresented, !coordinator.hasPresented {
            coordinator.hasPresented = true
            DispatchQueue.main.async {
                coordinator.present(from: uiViewController, content: content)
            }
        } else if !isPresented {
            coordinator.hasPresented = false
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public final class Coordinator {
        var binding: Binding<Bool>?
        var presentedVC: UIViewController?
        var hasPresented = false

        func present(from presenter: UIViewController, content: (@escaping DismissAction) -> Content) {
            let dismissAction: DismissAction = { [weak self] in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.presentedVC?.dismiss(animated: true) {
                        self.presentedVC = nil
                        self.hasPresented = false
                        self.binding?.wrappedValue = false
                    }
                }
            }

            let contentView = content(dismissAction)
            let hosting = PortraitLockedHostingController(rootView: contentView)
            hosting.view.backgroundColor = .black
            hosting.modalPresentationStyle = .fullScreen

            presentedVC = hosting
            hasPresented = true
            presenter.present(hosting, animated: true)
        }
    }
}
