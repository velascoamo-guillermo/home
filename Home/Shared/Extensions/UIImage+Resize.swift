import CoreGraphics
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Size whose longest side is `maxDimension`, or nil when `size` already fits.
private nonisolated func fittedSize(_ size: CGSize, maxDimension: CGFloat) -> CGSize? {
    let longest = max(size.width, size.height)
    guard longest > maxDimension else { return nil }
    let scale = maxDimension / longest
    let newWidth = (size.width * scale).rounded()
    let newHeight = (size.height * scale).rounded()
    if size.width >= size.height {
        return CGSize(width: newWidth, height: (newWidth / size.width * size.height).rounded())
    }
    return CGSize(width: (newHeight / size.height * size.width).rounded(), height: newHeight)
}

#if os(macOS)
extension NSImage {
    // nonisolated: draws into a private bitmap context; no shared AppKit state is touched.
    nonisolated func resized(maxDimension: CGFloat) -> NSImage {
        guard let newSize = fittedSize(size, maxDimension: maxDimension),
              let source = cgImage(forProposedRect: nil, context: nil, hints: nil),
              let context = CGContext(
                data: nil, width: Int(newSize.width), height: Int(newSize.height),
                bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return self }
        context.interpolationQuality = .high
        context.draw(source, in: CGRect(origin: .zero, size: newSize))
        guard let output = context.makeImage() else { return self }
        return NSImage(cgImage: output, size: newSize)
    }
}
#else
extension UIImage {
    // nonisolated: UIGraphicsImageRenderer and UIImage drawing are thread-safe since iOS 10
    nonisolated func resized(maxDimension: CGFloat) -> UIImage {
        guard let newSize = fittedSize(size, maxDimension: maxDimension) else { return self }
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
#endif
