import SwiftUI
import UIKit
import CoreImage

extension UIImage {
    /// Average color of the image, used to tint the pet detail hero.
    var averageColor: Color? {
        guard let input = CIImage(image: self) else { return nil }
        let extent = input.extent
        let vector = CIVector(x: extent.origin.x, y: extent.origin.y,
                              z: extent.size.width, w: extent.size.height)
        guard let filter = CIFilter(name: "CIAreaAverage",
                                    parameters: [kCIInputImageKey: input,
                                                 kCIInputExtentKey: vector]),
              let output = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(output, toBitmap: &bitmap, rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8, colorSpace: nil)

        return Color(red: Double(bitmap[0]) / 255,
                     green: Double(bitmap[1]) / 255,
                     blue: Double(bitmap[2]) / 255)
    }
}
