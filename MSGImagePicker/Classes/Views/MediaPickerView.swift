//
//  MediaPickerView.swift
//  MSGImagePicker
//
//  Main view composing the media grid and action bar.
//

import SwiftUI
import Photos

/// Main view for the media picker, containing the grid and action bar.
struct MediaPickerView: View {
    @EnvironmentObject private var viewModel: MediaPickerViewModel
    
    let config: MSGImagePickerConfig
    let onCancel: () -> Void
    let onSend: ([PickedMedia]) -> Void
    
    @State private var showEditView: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Content area
            contentView
            
            // Action bar (only when items are selected)
            if !viewModel.selectedItems.isEmpty {
                ActionBarView(
                    showsCaptions: config.showsCaptions,
                    onEdit: { showEditView = true },
                    onSend: handleSend
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.selectedItems.isEmpty)
        .navigationTitle("Photos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
            
            ToolbarItem(placement: .primaryAction) {
                if !viewModel.selectedItems.isEmpty {
                    Text("\(viewModel.selectedItems.count)/\(config.maxSelection)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize()
                }
            }
        }
        .fullScreenCover(isPresented: $showEditView) {
            MediaEditView(
                media: viewModel.buildPickedMedia(),
                config: config,
                onDismiss: { showEditView = false },
                onSend: { editedMedia in
                    showEditView = false
                    onSend(editedMedia)
                }
            )
        }
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var contentView: some View {
        switch viewModel.authorizationStatus {
        case .authorized, .limited:
            if viewModel.isLoading {
                loadingView
            } else if viewModel.items.isEmpty {
                emptyView
            } else {
                MediaGridView()
            }
        case .denied, .restricted:
            permissionDeniedView
        case .notDetermined:
            requestingPermissionView
        @unknown default:
            emptyView
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading photos...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No photos or videos")
                .font(.headline)
            Text("Your photo library is empty.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Photo Access Required")
                .font(.headline)
            Text("Please allow access to your photo library in Settings.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var requestingPermissionView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Requesting access...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func handleSend() {
        let pickedMedia = viewModel.buildPickedMedia()
        onSend(pickedMedia)
    }
}

// MARK: - Preview

#if DEBUG
struct MediaPickerView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            MediaPickerView(
                config: MSGImagePickerConfig(),
                onCancel: {},
                onSend: { _ in }
            )
            .environmentObject(MediaPickerViewModel(config: MSGImagePickerConfig()))
        }
    }
}
#endif
