//
//  MSGImagePickerSelectionMode.swift
//  MSGImagePicker
//
//  Internal picker view for modifying media selection from MediaEditView.
//

import SwiftUI
import Photos

/// Internal media picker for modifying selection from the edit view.
/// Shows a different action bar with preview strip and "Next" button.
struct MSGImagePickerSelectionMode: View {
    
    let config: MSGImagePickerConfig
    let existingSelection: [PickedMedia]
    let onCancel: () -> Void
    let onApply: ([PickedMedia]) -> Void
    
    @StateObject private var viewModel: MediaPickerViewModel
    
    init(
        config: MSGImagePickerConfig,
        existingSelection: [PickedMedia],
        onCancel: @escaping () -> Void,
        onApply: @escaping ([PickedMedia]) -> Void
    ) {
        self.config = config
        self.existingSelection = existingSelection
        self.onCancel = onCancel
        self.onApply = onApply
        self._viewModel = StateObject(wrappedValue: MediaPickerViewModel(config: config))
    }
    
    var body: some View {
        NavigationStack {
            MediaPickerSelectionModeView(
                config: config,
                existingSelection: existingSelection,
                onCancel: onCancel,
                onApply: onApply
            )
            .environmentObject(viewModel)
        }
        .onAppear {
            // Pre-select existing media
            preselectExistingMedia()
        }
    }
    
    private func preselectExistingMedia() {
        // This will be called after viewModel loads items
        // We need to select items that match the existing selection
        // Only consider library media (captured media can't be pre-selected from library)
        let existingIds = Set(existingSelection.compactMap { $0.asset?.localIdentifier })
        
        Task { @MainActor in
            // Wait for items to load
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            
            for item in viewModel.items {
                if existingIds.contains(item.asset.localIdentifier) && !viewModel.isSelected(item) {
                    viewModel.toggleSelection(item)
                }
            }
        }
    }
}

// MARK: - Selection Mode View

/// The main view content for selection mode.
struct MediaPickerSelectionModeView: View {
    @EnvironmentObject private var viewModel: MediaPickerViewModel
    
    let config: MSGImagePickerConfig
    let existingSelection: [PickedMedia]
    let onCancel: () -> Void
    let onApply: ([PickedMedia]) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Content area
            contentView
            
            // Selection action bar (always visible in this mode)
            SelectionModeActionBar(
                viewModel: viewModel,
                existingSelection: existingSelection,
                onApply: handleApply
            )
        }
        .navigationTitle("Photos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
            
            ToolbarItem(placement: .primaryAction) {
                Text("\(viewModel.selectedItems.count)/\(config.maxSelection)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize()
            }
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
    
    private func handleApply() {
        let pickedMedia = viewModel.buildPickedMedia()
        onApply(pickedMedia)
    }
}

// MARK: - Preview

#if DEBUG
struct MSGImagePickerSelectionMode_Previews: PreviewProvider {
    static var previews: some View {
        MSGImagePickerSelectionMode(
            config: MSGImagePickerConfig(),
            existingSelection: [],
            onCancel: {},
            onApply: { _ in }
        )
    }
}
#endif
