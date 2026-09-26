import ImageIO
import SwiftUI
import WidgetKit

enum PhotoEntryState {
    case placeholder
    case notSelected
    case deleted
    case unreadable
    case photo(UIImage)
}

struct PhotoEntry: TimelineEntry {
    let date: Date
    let state: PhotoEntryState
}

struct PhotoProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PhotoEntry {
        PhotoEntry(date: .now, state: .placeholder)
    }

    func snapshot(for configuration: SelectPhotoIntent, in context: Context) async -> PhotoEntry {
        if configuration.photo == nil, context.isPreview, let first = try? PhotoStore.loadIndex().first {
            return PhotoEntry(date: .now, state: Self.state(for: first.id, in: context))
        }
        return PhotoEntry(date: .now, state: Self.state(for: configuration.photo?.id, in: context))
    }

    func timeline(for configuration: SelectPhotoIntent, in context: Context) async -> Timeline<PhotoEntry> {
        let entry = PhotoEntry(date: .now, state: Self.state(for: configuration.photo?.id, in: context))
        return Timeline(entries: [entry], policy: .never)
    }

    private static func state(for id: UUID?, in context: Context) -> PhotoEntryState {
        guard let id else { return .notSelected }
        let index: [PhotoItem]
        let url: URL
        do {
            index = try PhotoStore.loadIndex()
            url = try PhotoStore.cropURL(for: id, aspect: aspect(for: context.family))
        } catch {
            return .unreadable
        }
        guard index.contains(where: { $0.id == id }), FileManager.default.fileExists(atPath: url.path) else {
            return .deleted
        }
        // Decode at widget size: full-size bitmaps push the extension past its memory limit.
        let maxPixel = Int(max(context.displaySize.width, context.displaySize.height) * 3)
        guard let image = downsample(url, maxPixel: max(maxPixel, 1)) else { return .unreadable }
        return .photo(image)
    }

    private static func aspect(for family: WidgetFamily) -> CropAspect {
        switch family {
        case .systemMedium, .accessoryRectangular: .wide
        default: .square
        }
    }

    private static func downsample(_ url: URL, maxPixel: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }
}

struct PhotoWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PhotoEntry

    private var isAccessory: Bool {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline: true
        default: false
        }
    }

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if isAccessory {
                    AccessoryWidgetBackground()
                } else {
                    Color(uiColor: .secondarySystemBackground)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch entry.state {
        case .photo(let image):
            photo(image)
        case .placeholder:
            Color.clear
        case .notSelected:
            message("길게 눌러 사진을 골라요", symbol: "photo.badge.plus")
        case .deleted:
            message("사진이 삭제됐어요", symbol: "photo.badge.exclamationmark")
        case .unreadable:
            message("사진을 읽지 못했어요", symbol: "exclamationmark.triangle")
        }
    }

    @ViewBuilder
    private func photo(_ image: UIImage) -> some View {
        let fill = Color.clear.overlay {
            Image(uiImage: image)
                .resizable()
                .fullColorWhenAccented()
                .scaledToFill()
        }
        switch family {
        case .accessoryCircular:
            fill.clipShape(Circle())
        case .accessoryRectangular:
            fill.clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        default:
            fill.clipped()
        }
    }

    @ViewBuilder
    private func message(_ text: String, symbol: String) -> some View {
        if isAccessory {
            Image(systemName: symbol)
                .font(.title3)
                .accessibilityLabel(text)
        } else {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.title2)
                Text(text)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.secondary)
            .padding(12)
        }
    }
}

private extension Image {
    /// Keeps photos in color on the iOS 18 tinted home screen instead of a flat tint.
    func fullColorWhenAccented() -> Image {
        if #available(iOS 18.0, *) {
            return widgetAccentedRenderingMode(.fullColor)
        }
        return self
    }
}

@main
struct PhotoWidgetBundle: WidgetBundle {
    var body: some Widget {
        PhotoWidget()
    }
}

struct PhotoWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "PhotoWidget", intent: SelectPhotoIntent.self, provider: PhotoProvider()) { entry in
            PhotoWidgetView(entry: entry)
        }
        .configurationDisplayName("사진")
        .description("고른 사진을 띄워요. 길게 눌러 '위젯 편집'에서 사진을 바꿔요.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}
