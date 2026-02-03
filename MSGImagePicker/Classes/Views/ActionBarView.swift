//
//  ActionBarView.swift
//  MSGImagePicker
//
//  Bottom action bar with edit button, caption input, and send button.
//

import SwiftUI

/// Bottom action bar displayed when items are selected.
struct ActionBarView: View {
    @EnvironmentObject private var viewModel: MediaPickerViewModel
    
    let showsCaptions: Bool
    let onEdit: () -> Void
    let onSend: () -> Void
    
    @ScaledMetric private var buttonSize: CGFloat = 44
    @ScaledMetric private var horizontalPadding: CGFloat = 12
    @ScaledMetric private var verticalPadding: CGFloat = 8
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // Edit button
            editButton
            
            // Caption text field
            if showsCaptions {
                captionField
            }
            
            // Send button
            sendButton
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(.regularMaterial)
    }
    
    // MARK: - Subviews
    
    private var editButton: some View {
        Button(action: onEdit) {
            Image(systemName: "pencil")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: buttonSize, height: buttonSize)
                .background(Color.secondary.opacity(0.2))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
    
    private var captionField: some View {
        TextField("Add a caption...", text: $viewModel.caption, axis: .vertical)
            .textFieldStyle(.plain)
            .lineLimit(1...4)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .frame(minHeight: buttonSize)
            .background(
                RoundedRectangle(cornerRadius: buttonSize / 2)
                    .strokeBorder(.secondary.opacity(0.4))
            )
    }
    
    private var sendButton: some View {
        Button(action: onSend) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.white, .blue)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
struct ActionBarView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            ActionBarView(
                showsCaptions: true,
                onEdit: {},
                onSend: {}
            )
            .environmentObject(MediaPickerViewModel(config: MSGImagePickerConfig()))
        }
    }
}
#endif
