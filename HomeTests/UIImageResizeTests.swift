import Testing
import CoreGraphics
import SwiftUI
@testable import Casita

@Suite("PlatformImage resize") @MainActor struct UIImageResizeTests {

    private func makeImage(width: Int, height: Int) throws -> PlatformImage {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let cgImage = try #require(context.makeImage())
        #if os(macOS)
        return PlatformImage(cgImage: cgImage, size: CGSize(width: width, height: height))
        #else
        return PlatformImage(cgImage: cgImage)
        #endif
    }

    @Test("image already within maxDimension is returned unchanged")
    func smallImageUnchanged() throws {
        let image = try makeImage(width: 200, height: 150)
        let resized = image.resized(maxDimension: 512)
        #expect(resized.size.width == 200)
        #expect(resized.size.height == 150)
        #expect(resized === image)
    }

    @Test("large image is scaled so longest side equals maxDimension")
    func largeImageScaledDown() throws {
        let resized = try makeImage(width: 1000, height: 800).resized(maxDimension: 512)
        #expect(max(resized.size.width, resized.size.height) == 512)
    }

    @Test("aspect ratio is preserved after resize")
    func aspectRatioPreserved() throws {
        let resized = try makeImage(width: 1000, height: 500).resized(maxDimension: 512)
        #expect(abs(resized.size.width / resized.size.height - 2.0) < 0.01)
    }

    @Test("portrait image is scaled on its height")
    func portraitScaledOnHeight() throws {
        let resized = try makeImage(width: 500, height: 1000).resized(maxDimension: 512)
        #expect(resized.size.height == 512)
        #expect(resized.size.width == 256)
    }

    #if os(macOS)
    @Test("resized NSImage encodes to a JPEG that decodes at the resized pixel size")
    func jpegRoundTrip() throws {
        let data = try #require(try makeImage(width: 1000, height: 500)
            .resized(maxDimension: 512).jpegData(compressionQuality: 0.8))
        let decoded = try #require(PlatformImage(data: data))
        #expect(decoded.size == CGSize(width: 512, height: 256))
    }
    #endif
}
