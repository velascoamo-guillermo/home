import UIKit

extension UIImage {
    // nonisolated: UIGraphicsImageRenderer and UIImage drawing are thread-safe since iOS 10
    nonisolated func resized(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let newWidth = (size.width * scale).rounded()
        let newHeight = (size.height * scale).rounded()
        let newSize: CGSize
        if size.width >= size.height {
            let h = (newWidth / size.width * size.height).rounded()
            newSize = CGSize(width: newWidth, height: h)
        } else {
            let w = (newHeight / size.height * size.width).rounded()
            newSize = CGSize(width: w, height: newHeight)
        }
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
