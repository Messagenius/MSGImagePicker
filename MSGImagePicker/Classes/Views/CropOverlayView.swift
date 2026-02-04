//
//  CropOverlayView.swift
//  MSGImagePicker
//
//  Overlay view with crop rectangle, draggable corners, grid, and dimming.
//

import SwiftUI

/// Corner handle positions for the crop rectangle.
enum CropCorner: CaseIterable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

/// Edge handle positions for the crop rectangle.
enum CropEdge: CaseIterable {
    case top
    case bottom
    case left
    case right
}

/// Overlay view that displays the crop rectangle with draggable handles,
/// rule-of-thirds grid, and dimmed exterior.
@available(iOS 16.0, *)
struct CropOverlayView: View {
    
    // MARK: - Properties
    
    @Binding var cropRect: CGRect
    let containerSize: CGSize
    let minCropSize: CGFloat
    let imageDisplayRect: CGRect
    let workingAreaInsets: EdgeInsets
    
    // MARK: - State
    
    @State private var activeCorner: CropCorner?
    @State private var activeEdge: CropEdge?
    @State private var initialCropRect: CGRect = .zero
    
    // MARK: - Constants
    
    private let handleSize: CGFloat = 24
    private let handleHitArea: CGFloat = 44
    private let gridLineWidth: CGFloat = 1
    private let borderWidth: CGFloat = 1
    private let dimmingOpacity: CGFloat = 0.6
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Dimmed exterior
            dimmingLayer
            
            // Crop rectangle border
            cropBorder
            
            // Grid lines (rule of thirds)
            gridLines
            
            // Corner handles
            cornerHandles
        }
    }
    
    // MARK: - Dimming Layer
    
    private var dimmingLayer: some View {
        Path { path in
            // Outer rectangle (full container)
            path.addRect(CGRect(origin: .zero, size: containerSize))
            
            // Inner rectangle (crop area - will be cut out)
            path.addRect(cropRect)
        }
        .fill(Color.black.opacity(dimmingOpacity), style: FillStyle(eoFill: true))
        .allowsHitTesting(false)
    }
    
    // MARK: - Crop Border
    
    private var cropBorder: some View {
        Rectangle()
            .strokeBorder(Color.white, lineWidth: borderWidth)
            .frame(width: cropRect.width, height: cropRect.height)
            .position(x: cropRect.midX, y: cropRect.midY)
            .allowsHitTesting(false)
    }
    
    // MARK: - Grid Lines
    
    private var gridLines: some View {
        Path { path in
            // Vertical lines (rule of thirds)
            let thirdWidth = cropRect.width / 3
            for i in 1...2 {
                let x = cropRect.minX + thirdWidth * CGFloat(i)
                path.move(to: CGPoint(x: x, y: cropRect.minY))
                path.addLine(to: CGPoint(x: x, y: cropRect.maxY))
            }
            
            // Horizontal lines (rule of thirds)
            let thirdHeight = cropRect.height / 3
            for i in 1...2 {
                let y = cropRect.minY + thirdHeight * CGFloat(i)
                path.move(to: CGPoint(x: cropRect.minX, y: y))
                path.addLine(to: CGPoint(x: cropRect.maxX, y: y))
            }
        }
        .stroke(Color.white.opacity(0.5), lineWidth: gridLineWidth)
        .allowsHitTesting(false)
    }
    
    // MARK: - Corner Handles
    
    private var cornerHandles: some View {
        ZStack {
            ForEach(CropCorner.allCases, id: \.self) { corner in
                cornerHandle(for: corner)
            }
        }
    }
    
    private func cornerHandle(for corner: CropCorner) -> some View {
        let position = cornerPosition(for: corner)
        
        return CornerHandleShape(corner: corner)
            .stroke(Color.white, lineWidth: 3)
            .frame(width: handleSize, height: handleSize)
            .contentShape(Rectangle().size(CGSize(width: handleHitArea, height: handleHitArea)))
            .position(position)
            .gesture(cornerDragGesture(for: corner))
    }
    
    private func cornerPosition(for corner: CropCorner) -> CGPoint {
        switch corner {
        case .topLeft:
            return CGPoint(x: cropRect.minX, y: cropRect.minY)
        case .topRight:
            return CGPoint(x: cropRect.maxX, y: cropRect.minY)
        case .bottomLeft:
            return CGPoint(x: cropRect.minX, y: cropRect.maxY)
        case .bottomRight:
            return CGPoint(x: cropRect.maxX, y: cropRect.maxY)
        }
    }
    
    // MARK: - Corner Drag Gesture
    
    private func cornerDragGesture(for corner: CropCorner) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if activeCorner == nil {
                    activeCorner = corner
                    initialCropRect = cropRect
                }
                
                guard activeCorner == corner else { return }
                
                updateCropRect(for: corner, with: value.location)
            }
            .onEnded { _ in
                activeCorner = nil
            }
    }
    
    private func updateCropRect(for corner: CropCorner, with location: CGPoint) {
        var newRect = initialCropRect
        
        switch corner {
        case .topLeft:
            let newX = min(location.x, initialCropRect.maxX - minCropSize)
            let newY = min(location.y, initialCropRect.maxY - minCropSize)
            newRect = CGRect(
                x: newX,
                y: newY,
                width: initialCropRect.maxX - newX,
                height: initialCropRect.maxY - newY
            )
            
        case .topRight:
            let newWidth = max(location.x - initialCropRect.minX, minCropSize)
            let newY = min(location.y, initialCropRect.maxY - minCropSize)
            newRect = CGRect(
                x: initialCropRect.minX,
                y: newY,
                width: newWidth,
                height: initialCropRect.maxY - newY
            )
            
        case .bottomLeft:
            let newX = min(location.x, initialCropRect.maxX - minCropSize)
            let newHeight = max(location.y - initialCropRect.minY, minCropSize)
            newRect = CGRect(
                x: newX,
                y: initialCropRect.minY,
                width: initialCropRect.maxX - newX,
                height: newHeight
            )
            
        case .bottomRight:
            let newWidth = max(location.x - initialCropRect.minX, minCropSize)
            let newHeight = max(location.y - initialCropRect.minY, minCropSize)
            newRect = CGRect(
                x: initialCropRect.minX,
                y: initialCropRect.minY,
                width: newWidth,
                height: newHeight
            )
        }
        
        // Constrain to image bounds
        cropRect = constrainToImageBounds(newRect)
    }
    
    private func constrainToImageBounds(_ rect: CGRect) -> CGRect {
        var constrained = rect
        
        // Calculate working area bounds
        let workingAreaMinX = workingAreaInsets.leading
        let workingAreaMinY = workingAreaInsets.top
        let workingAreaMaxX = containerSize.width - workingAreaInsets.trailing
        let workingAreaMaxY = containerSize.height - workingAreaInsets.bottom
        
        // Use the intersection of image bounds and working area
        let minX = max(imageDisplayRect.minX, workingAreaMinX)
        let minY = max(imageDisplayRect.minY, workingAreaMinY)
        let maxX = min(imageDisplayRect.maxX, workingAreaMaxX)
        let maxY = min(imageDisplayRect.maxY, workingAreaMaxY)
        
        // Constrain to bounds
        constrained.origin.x = max(minX, constrained.origin.x)
        constrained.origin.y = max(minY, constrained.origin.y)
        
        if constrained.maxX > maxX {
            constrained.size.width = maxX - constrained.origin.x
        }
        if constrained.maxY > maxY {
            constrained.size.height = maxY - constrained.origin.y
        }
        
        // Ensure minimum size
        constrained.size.width = max(constrained.size.width, minCropSize)
        constrained.size.height = max(constrained.size.height, minCropSize)
        
        return constrained
    }
}

// MARK: - Corner Handle Shape

/// Custom shape for corner handles (L-shaped)
struct CornerHandleShape: Shape {
    let corner: CropCorner
    private let lineLength: CGFloat = 12
    private let lineThickness: CGFloat = 3
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        switch corner {
        case .topLeft:
            // Vertical line going down
            path.move(to: CGPoint(x: rect.midX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.midY + lineLength))
            // Horizontal line going right
            path.move(to: CGPoint(x: rect.midX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX + lineLength, y: rect.midY))
            
        case .topRight:
            // Vertical line going down
            path.move(to: CGPoint(x: rect.midX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.midY + lineLength))
            // Horizontal line going left
            path.move(to: CGPoint(x: rect.midX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX - lineLength, y: rect.midY))
            
        case .bottomLeft:
            // Vertical line going up
            path.move(to: CGPoint(x: rect.midX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.midY - lineLength))
            // Horizontal line going right
            path.move(to: CGPoint(x: rect.midX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX + lineLength, y: rect.midY))
            
        case .bottomRight:
            // Vertical line going up
            path.move(to: CGPoint(x: rect.midX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.midY - lineLength))
            // Horizontal line going left
            path.move(to: CGPoint(x: rect.midX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX - lineLength, y: rect.midY))
        }
        
        return path
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 16.0, *)
struct CropOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray
            CropOverlayView(
                cropRect: .constant(CGRect(x: 50, y: 100, width: 200, height: 300)),
                containerSize: CGSize(width: 300, height: 500),
                minCropSize: 50,
                imageDisplayRect: CGRect(x: 50, y: 100, width: 200, height: 300),
                workingAreaInsets: EdgeInsets(top: 20, leading: 20, bottom: 16, trailing: 20)
            )
        }
    }
}
#endif
