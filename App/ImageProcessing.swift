import ImageIO
import UIKit

enum ImageProcessingError: LocalizedError {
    case decodeFailed
    case cropFailed
    case encodeFailed

    var errorDescription: String? {
        switch self {
        case .decodeFailed: "이미지를 읽지 못했어요"
        case .cropFailed: "이미지를 자르지 못했어요"
        case .encodeFailed: "이미지를 저장하지 못했어요"
        }
    }
}

enum ImageProcessing {
    /// Decodes at most `maxPixel` on the long edge with EXIF orientation applied.
    static func downsample(_ data: Data, maxPixel: Int) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            throw ImageProcessingError.decodeFailed
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ImageProcessingError.decodeFailed
        }
        return image
    }

    static func load(_ url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw ImageProcessingError.decodeFailed
        }
        return image
    }

    static func jpegData(_ image: CGImage) throws -> Data {
        guard let data = UIImage(cgImage: image).jpegData(compressionQuality: 0.9) else {
            throw ImageProcessingError.encodeFailed
        }
        return data
    }

    /// Renders the normalized `crop` of `image` into a JPEG of exactly `size` pixels.
    static func render(_ image: CGImage, crop: CGRect, size: CGSize) throws -> Data {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let pixelRect = CGRect(
            x: crop.minX * width,
            y: crop.minY * height,
            width: crop.width * width,
            height: crop.height * height
        ).integral.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard let cropped = image.cropping(to: pixelRect) else {
            throw ImageProcessingError.cropFailed
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.jpegData(withCompressionQuality: 0.85) { _ in
            UIImage(cgImage: cropped).draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Largest centered normalized rect with the given width/height ratio.
    static func centerCrop(imageSize: CGSize, ratio: CGFloat) -> CGRect {
        let imageRatio = imageSize.width / imageSize.height
        if imageRatio > ratio {
            let width = ratio / imageRatio
            return CGRect(x: (1 - width) / 2, y: 0, width: width, height: 1)
        }
        let height = imageRatio / ratio
        return CGRect(x: 0, y: (1 - height) / 2, width: 1, height: height)
    }
}
