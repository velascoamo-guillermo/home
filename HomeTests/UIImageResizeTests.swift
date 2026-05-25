import Testing
import UIKit
@testable import Home

@Suite("UIImage+Resize") @MainActor struct UIImageResizeTests {

    private func makeImage(width: CGFloat, height: CGFloat) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: width, height: height)).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(origin: .zero, size: CGSize(width: width, height: height)))
        }
    }

    @Test("image already within maxDimension is returned unchanged")
    func smallImageUnchanged() {
        let image = makeImage(width: 200, height: 150)
        let resized = image.resized(maxDimension: 512)
        #expect(resized.size.width == 200)
        #expect(resized.size.height == 150)
    }

    @Test("large image is scaled so longest side equals maxDimension")
    func largeImageScaledDown() {
        let image = makeImage(width: 1000, height: 800)
        let resized = image.resized(maxDimension: 512)
        #expect(max(resized.size.width, resized.size.height) == 512)
    }

    @Test("aspect ratio is preserved after resize")
    func aspectRatioPreserved() {
        let image = makeImage(width: 1000, height: 500)
        let resized = image.resized(maxDimension: 512)
        let ratio = resized.size.width / resized.size.height
        #expect(abs(ratio - 2.0) < 0.01)
    }
}
