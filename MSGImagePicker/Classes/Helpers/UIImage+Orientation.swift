//
//  UIImage+Orientation.swift
//  MSGImagePicker
//
//  Normalizes UIImage orientation so that cgImage coordinates match display/logical size.
//  Used when cropping to avoid wrong crop rect for captured images with EXIF orientation.
//

import UIKit

extension UIImage {

    /// Returns a copy of the image with orientation applied to pixels (orientation .up).
    /// Use before cropping so that cgImage dimensions match image.size and display coordinates.
    func fixedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        guard let cgImage = cgImage else { return self }

        var transform = CGAffineTransform.identity

        switch imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: size.height)
            transform = transform.rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.rotated(by: .pi / 2)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: size.height)
            transform = transform.rotated(by: -.pi / 2)
        case .up, .upMirrored:
            break
        @unknown default:
            break
        }

        switch imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .up, .down, .left, .right:
            break
        @unknown default:
            break
        }

        guard let colorSpace = cgImage.colorSpace,
              let ctx = CGContext(
                  data: nil,
                  width: Int(size.width),
                  height: Int(size.height),
                  bitsPerComponent: cgImage.bitsPerComponent,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue
              ) else { return self }

        ctx.concatenate(transform)

        switch imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.height, height: size.width))
        default:
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        }

        guard let outputCGImage = ctx.makeImage() else { return self }
        return UIImage(cgImage: outputCGImage, scale: scale, orientation: .up)
    }
}
