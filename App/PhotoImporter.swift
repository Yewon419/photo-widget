import CoreGraphics
import Foundation

/// File work for photos. Runs off the main actor.
enum PhotoImporter {
    static let sourceMaxPixel = 2048
    static let thumbnailSize = CGSize(width: 360, height: 360)

    static func makeItem(from data: Data) throws -> PhotoItem {
        let image = try ImageProcessing.downsample(data, maxPixel: sourceMaxPixel)
        let id = UUID()
        try PhotoStore.createDirectory(for: id)
        do {
            try ImageProcessing.jpegData(image).write(to: PhotoStore.sourceURL(for: id), options: .atomic)
            let size = CGSize(width: image.width, height: image.height)
            var crops: [CropAspect: CGRect] = [:]
            for aspect in CropAspect.allCases {
                let rect = ImageProcessing.centerCrop(imageSize: size, ratio: aspect.ratio)
                crops[aspect] = rect
                try writeRenders(image, crop: rect, aspect: aspect, id: id)
            }
            return PhotoItem(id: id, createdAt: .now, crops: crops, revision: 0)
        } catch {
            try? PhotoStore.removeFiles(for: id)
            throw error
        }
    }

    static func renderCrop(_ rect: CGRect, aspect: CropAspect, for id: UUID) throws {
        let image = try ImageProcessing.load(PhotoStore.sourceURL(for: id))
        try writeRenders(image, crop: rect, aspect: aspect, id: id)
    }

    private static func writeRenders(_ image: CGImage, crop: CGRect, aspect: CropAspect, id: UUID) throws {
        try ImageProcessing.render(image, crop: crop, size: aspect.outputPixelSize)
            .write(to: PhotoStore.cropURL(for: id, aspect: aspect), options: .atomic)
        if aspect == .square {
            try ImageProcessing.render(image, crop: crop, size: thumbnailSize)
                .write(to: PhotoStore.thumbnailURL(for: id), options: .atomic)
        }
    }
}
