//
//  CropView.swift
//  MSGImagePicker
//
//  View for cropping images with adjustable crop rect, zoom, and pan.
//

import SwiftUI

/// Result of a crop operation.
struct CropResult {
    let croppedImage: UIImage
    let normalizedCropRect: CGRect
}

/// A view for cropping images with interactive crop rectangle and zoom/pan support.
@available(iOS 16.0, *)
struct CropView: View {
    
    // MARK: - Properties
    
    let image: UIImage
    let onCancel: () -> Void
    let onDone: (CropResult) -> Void
    
    // MARK: - State
    
    /// The crop rectangle in view coordinates
    @State private var cropRect: CGRect = .zero
    
    /// Image transform for zoom and pan
    @State private var imageScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    
    /// Gesture state
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    
    /// Container size
    @State private var containerSize: CGSize = .zero
    
    /// Image display rect (the rect where the image is displayed at scale 1.0)
    @State private var imageDisplayRect: CGRect = .zero
    
    // MARK: - Constants
    
    private let minCropSize: CGFloat = 50
    private let horizontalPadding: CGFloat = 20
    private let topPadding: CGFloat = 20
    private let bottomPadding: CGFloat = 16
    private let actionBarHeight: CGFloat = 50
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            let safeArea = geometry.safeAreaInsets
            
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                // Main content
                VStack(spacing: 0) {
                    // Crop area with safe area consideration
                    cropArea(in: geometry.size, safeArea: safeArea)
                    
                    // Action bar
                    actionBar
                        .padding(.bottom, safeArea.bottom > 0 ? 0 : 8)
                }
            }
            .onAppear {
                containerSize = geometry.size
                initializeCropRect(for: geometry.size, safeArea: safeArea)
            }
        }
    }
    
    // MARK: - Crop Area
    
    private func cropArea(in size: CGSize, safeArea: EdgeInsets) -> some View {
        // Reserve space for action bar and safe areas
        let cropAreaHeight = size.height - actionBarHeight - (safeArea.bottom > 0 ? 0 : 8)
        
        // Working area insets for the crop overlay (uniform margins)
        let workingInsets = EdgeInsets(
            top: topPadding,
            leading: horizontalPadding,
            bottom: bottomPadding,
            trailing: horizontalPadding
        )
        
        return GeometryReader { geometry in
            ZStack {
                // Image layer
                imageLayer(in: CGSize(width: size.width, height: cropAreaHeight), safeArea: safeArea)
                
                // Crop overlay
                CropOverlayView(
                    cropRect: $cropRect,
                    containerSize: CGSize(width: size.width, height: cropAreaHeight),
                    minCropSize: minCropSize,
                    imageDisplayRect: imageDisplayRect,
                    workingAreaInsets: workingInsets
                )
            }
        }
        .frame(height: cropAreaHeight)
        .clipped()
    }
    
    // MARK: - Image Layer
    
    private func imageLayer(in size: CGSize, safeArea: EdgeInsets) -> some View {
        let imageSize = image.size
        let aspectRatio = imageSize.width / imageSize.height
        
        // Calculate available area with uniform padding from all sides
        let availableWidth = size.width - horizontalPadding * 2
        let availableHeight = size.height - topPadding - bottomPadding
        
        // Calculate fitted size
        let fittedSize: CGSize
        if aspectRatio > availableWidth / availableHeight {
            fittedSize = CGSize(
                width: availableWidth,
                height: availableWidth / aspectRatio
            )
        } else {
            fittedSize = CGSize(
                width: availableHeight * aspectRatio,
                height: availableHeight
            )
        }
        
        // Center vertically in the available area
        let verticalCenter = topPadding + availableHeight / 2
        
        // Calculate image rect
        let imageRect = CGRect(
            x: (size.width - fittedSize.width) / 2,
            y: verticalCenter - fittedSize.height / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
        
        return Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: fittedSize.width * imageScale, height: fittedSize.height * imageScale)
            .offset(imageOffset)
            .position(x: size.width / 2, y: verticalCenter)
            .gesture(dragGesture(imageRect: imageRect))
            .gesture(magnificationGesture(imageRect: imageRect))
            .onAppear {
                imageDisplayRect = imageRect
            }
            .onChange(of: imageScale) { _, _ in
                updateImageDisplayRect(baseRect: imageRect)
            }
            .onChange(of: imageOffset) { _, _ in
                updateImageDisplayRect(baseRect: imageRect)
            }
    }
    
    private func updateImageDisplayRect(baseRect: CGRect) {
        let scaledWidth = baseRect.width * imageScale
        let scaledHeight = baseRect.height * imageScale
        let centerX = baseRect.midX + imageOffset.width
        let centerY = baseRect.midY + imageOffset.height
        
        imageDisplayRect = CGRect(
            x: centerX - scaledWidth / 2,
            y: centerY - scaledHeight / 2,
            width: scaledWidth,
            height: scaledHeight
        )
    }
    
    // MARK: - Gestures
    
    private func dragGesture(imageRect: CGRect) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let newOffset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
                imageOffset = constrainOffset(newOffset, imageRect: imageRect)
            }
            .onEnded { _ in
                lastOffset = imageOffset
                snapImageToCropRect(imageRect: imageRect)
            }
    }
    
    private func magnificationGesture(imageRect: CGRect) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                imageScale = min(max(newScale, minScale), maxScale)
            }
            .onEnded { _ in
                lastScale = imageScale
                snapImageToCropRect(imageRect: imageRect)
            }
    }
    
    private func constrainOffset(_ offset: CGSize, imageRect: CGRect) -> CGSize {
        let scaledWidth = imageRect.width * imageScale
        let scaledHeight = imageRect.height * imageScale
        
        // Calculate bounds based on crop rect
        let maxOffsetX = max(0, (scaledWidth - cropRect.width) / 2)
        let maxOffsetY = max(0, (scaledHeight - cropRect.height) / 2)
        
        return CGSize(
            width: min(max(offset.width, -maxOffsetX), maxOffsetX),
            height: min(max(offset.height, -maxOffsetY), maxOffsetY)
        )
    }
    
    private func snapImageToCropRect(imageRect: CGRect) {
        withAnimation(.spring(duration: 0.3)) {
            imageOffset = constrainOffset(imageOffset, imageRect: imageRect)
        }
    }
    
    // MARK: - Action Bar
    
    private var actionBar: some View {
        HStack {
            // Cancel button
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.system(size: 17))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            
            Spacer()
            
            // Done button
            Button(action: performCrop) {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
        }
        .frame(height: actionBarHeight)
        .background(Color.white.opacity(0.15))
    }
    
    // MARK: - Initialization
    
    private func initializeCropRect(for size: CGSize, safeArea: EdgeInsets) {
        let cropAreaHeight = size.height - actionBarHeight - (safeArea.bottom > 0 ? 0 : 8)
        let imageSize = image.size
        let aspectRatio = imageSize.width / imageSize.height
        
        // Calculate available area with uniform padding
        let availableWidth = size.width - horizontalPadding * 2
        let availableHeight = cropAreaHeight - topPadding - bottomPadding
        
        let fittedSize: CGSize
        if aspectRatio > availableWidth / availableHeight {
            fittedSize = CGSize(
                width: availableWidth,
                height: availableWidth / aspectRatio
            )
        } else {
            fittedSize = CGSize(
                width: availableHeight * aspectRatio,
                height: availableHeight
            )
        }
        
        // Center vertically in the available area
        let verticalCenter = topPadding + availableHeight / 2
        
        // Initial crop rect matches the image bounds
        cropRect = CGRect(
            x: (size.width - fittedSize.width) / 2,
            y: verticalCenter - fittedSize.height / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
        
        imageDisplayRect = cropRect
    }
    
    // MARK: - Crop Logic
    
    private func performCrop() {
        guard let cropResult = cropResult() else {
            onCancel()
            return
        }
        onDone(cropResult)
    }
    
    private func cropResult() -> CropResult? {
        let imageSize = image.size
        
        // Calculate the scale factor between display and actual image
        let displayToImageScaleX = imageSize.width / imageDisplayRect.width
        let displayToImageScaleY = imageSize.height / imageDisplayRect.height
        
        // Calculate crop rect in image coordinates
        let cropInImageX = (cropRect.minX - imageDisplayRect.minX) * displayToImageScaleX
        let cropInImageY = (cropRect.minY - imageDisplayRect.minY) * displayToImageScaleY
        let cropInImageWidth = cropRect.width * displayToImageScaleX
        let cropInImageHeight = cropRect.height * displayToImageScaleY
        
        let cropRectInImage = CGRect(
            x: max(0, cropInImageX),
            y: max(0, cropInImageY),
            width: min(cropInImageWidth, imageSize.width - max(0, cropInImageX)),
            height: min(cropInImageHeight, imageSize.height - max(0, cropInImageY))
        )
        
        // Perform crop
        guard let cgImage = image.cgImage?.cropping(to: cropRectInImage) else {
            return nil
        }
        let croppedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        
        let normalizedRect = CGRect(
            x: cropRectInImage.minX / imageSize.width,
            y: cropRectInImage.minY / imageSize.height,
            width: cropRectInImage.width / imageSize.width,
            height: cropRectInImage.height / imageSize.height
        )
        
        return CropResult(croppedImage: croppedImage, normalizedCropRect: normalizedRect)
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 16.0, *)
struct CropView_Previews: PreviewProvider {
    static var previews: some View {
        if let image = UIImage(systemName: "photo.fill") {
            CropView(
                image: image,
                onCancel: {},
                onDone: { _ in }
            )
        }
    }
}
#endif
