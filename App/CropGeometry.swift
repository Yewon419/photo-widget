import CoreGraphics

/// Image placement inside a crop viewport. `offset` is the image center relative to the
/// viewport center; the image always covers the viewport.
struct CropGeometry {
    static let maxZoom: CGFloat = 8

    let imageSize: CGSize
    let viewport: CGSize
    let scale: CGFloat
    let offset: CGSize

    init(imageSize: CGSize, viewport: CGSize, crop: CGRect) {
        let scale = viewport.width / (crop.width * imageSize.width)
        let displayWidth = imageSize.width * scale
        let displayHeight = imageSize.height * scale
        self.init(
            imageSize: imageSize,
            viewport: viewport,
            scale: scale,
            offset: CGSize(
                width: displayWidth / 2 - crop.minX * displayWidth - viewport.width / 2,
                height: displayHeight / 2 - crop.minY * displayHeight - viewport.height / 2
            )
        )
    }

    private init(imageSize: CGSize, viewport: CGSize, scale: CGFloat, offset: CGSize) {
        self.imageSize = imageSize
        self.viewport = viewport
        let minScale = max(viewport.width / imageSize.width, viewport.height / imageSize.height)
        let clampedScale = min(max(scale, minScale), minScale * Self.maxZoom)
        let maxX = (imageSize.width * clampedScale - viewport.width) / 2
        let maxY = (imageSize.height * clampedScale - viewport.height) / 2
        self.scale = clampedScale
        self.offset = CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY)
        )
    }

    var displaySize: CGSize {
        CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    var crop: CGRect {
        let size = displaySize
        return CGRect(
            x: (size.width / 2 - viewport.width / 2 - offset.width) / size.width,
            y: (size.height / 2 - viewport.height / 2 - offset.height) / size.height,
            width: viewport.width / size.width,
            height: viewport.height / size.height
        )
    }

    /// Zoom keeps the viewport center anchored; translation is applied after.
    func applying(translation: CGSize, magnification: CGFloat) -> CropGeometry {
        let target = CropGeometry(imageSize: imageSize, viewport: viewport, scale: scale * magnification, offset: offset)
        let factor = target.scale / scale
        return CropGeometry(
            imageSize: imageSize,
            viewport: viewport,
            scale: target.scale,
            offset: CGSize(
                width: offset.width * factor + translation.width,
                height: offset.height * factor + translation.height
            )
        )
    }
}
