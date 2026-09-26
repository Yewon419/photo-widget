import AppIntents
import ImageIO
import SwiftUI
import WidgetKit

enum PhotoEntryState {
    case placeholder
    case notSelected
    case deleted
    case unreadable
    case photo(URL)
}

struct PhotoEntry: TimelineEntry {
    let date: Date
    let state: PhotoEntryState
    let maxPixel: Int
    /// Set when the widget cycles through more than one photo.
    let advanceKey: String?
}

private struct Slides {
    let urls: [URL]
    let key: String
    let interval: TimeInterval
    let offset: Int

    func slot(at date: Date) -> Int {
        Int((date.timeIntervalSince1970 / interval).rounded(.down))
    }

    func url(at date: Date) -> URL {
        let count = urls.count
        return urls[((slot(at: date) + offset) % count + count) % count]
    }
}

private enum Resolved {
    case fixed(PhotoEntryState)
    case slides(Slides)
}

struct PhotoProvider: AppIntentTimelineProvider {
    /// Entries per timeline; each one is a rendered snapshot, so keep it bounded.
    private static let maxEntries = 48

    func placeholder(in context: Context) -> PhotoEntry {
        PhotoEntry(date: .now, state: .placeholder, maxPixel: 1, advanceKey: nil)
    }

    func snapshot(for configuration: SelectPhotoIntent, in context: Context) async -> PhotoEntry {
        var ids = configuration.photos?.map(\.id) ?? []
        if ids.isEmpty, context.isPreview, let first = try? PhotoStore.loadIndex().first {
            ids = [first.id]
        }
        let now = Date.now
        switch Self.resolve(ids: ids, interval: configuration.interval, family: context.family) {
        case .fixed(let state):
            return PhotoEntry(date: now, state: state, maxPixel: Self.maxPixel(context), advanceKey: nil)
        case .slides(let slides):
            return PhotoEntry(date: now, state: .photo(slides.url(at: now)), maxPixel: Self.maxPixel(context), advanceKey: slides.key)
        }
    }

    func timeline(for configuration: SelectPhotoIntent, in context: Context) async -> Timeline<PhotoEntry> {
        let ids = configuration.photos?.map(\.id) ?? []
        let now = Date.now
        let maxPixel = Self.maxPixel(context)
        switch Self.resolve(ids: ids, interval: configuration.interval, family: context.family) {
        case .fixed(let state):
            return Timeline(entries: [PhotoEntry(date: now, state: state, maxPixel: maxPixel, advanceKey: nil)], policy: .never)
        case .slides(let slides):
            let firstSlot = slides.slot(at: now)
            let boundaries = (1..<Self.maxEntries).map { Date(timeIntervalSince1970: Double(firstSlot + $0) * slides.interval) }
            let entries = ([now] + boundaries).map {
                PhotoEntry(date: $0, state: .photo(slides.url(at: $0)), maxPixel: maxPixel, advanceKey: slides.key)
            }
            return Timeline(entries: entries, policy: .atEnd)
        }
    }

    private static func resolve(ids: [UUID], interval: SlideInterval, family: WidgetFamily) -> Resolved {
        guard !ids.isEmpty else { return .fixed(.notSelected) }
        let existing: [UUID]
        let urls: [URL]
        do {
            let known = Set(try PhotoStore.loadIndex().map(\.id))
            let aspect = aspect(for: family)
            existing = ids.filter { known.contains($0) }
            urls = try existing
                .map { try PhotoStore.cropURL(for: $0, aspect: aspect) }
                .filter { FileManager.default.fileExists(atPath: $0.path) }
        } catch {
            return .fixed(.unreadable)
        }
        guard let first = urls.first else { return .fixed(.deleted) }
        guard urls.count > 1 else { return .fixed(.photo(first)) }
        let key = SlideState.key(for: existing)
        return .slides(Slides(urls: urls, key: key, interval: interval.seconds, offset: SlideState.offset(for: key)))
    }

    private static func aspect(for family: WidgetFamily) -> CropAspect {
        switch family {
        case .systemMedium, .accessoryRectangular: .wide
        default: .square
        }
    }

    private static func maxPixel(_ context: Context) -> Int {
        max(Int(max(context.displaySize.width, context.displaySize.height) * 3), 1)
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
        case .photo(let url):
            ZStack {
                shaped(PhotoImage(url: url, maxPixel: entry.maxPixel))
                    .id(url)
                    .transition(.push(from: .trailing))
            }
            .overlay {
                if let key = entry.advanceKey {
                    TapZones(key: key)
                }
            }
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
    private func shaped(_ image: PhotoImage) -> some View {
        let fill = Color.clear.overlay { image }
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

/// Left half goes back, right half goes forward.
private struct TapZones: View {
    let key: String

    var body: some View {
        HStack(spacing: 0) {
            Button(intent: AdvancePhotoIntent(key: key, step: -1)) {
                Color.clear.contentShape(Rectangle())
            }
            .accessibilityLabel("이전 사진")
            Button(intent: AdvancePhotoIntent(key: key, step: 1)) {
                Color.clear.contentShape(Rectangle())
            }
            .accessibilityLabel("다음 사진")
        }
        .buttonStyle(.plain)
    }
}

/// Decodes at widget size (full-size bitmaps push the extension past its memory limit)
/// and keeps photos in color on the iOS 18 tinted home screen.
private struct PhotoImage: View {
    let url: URL
    let maxPixel: Int

    var body: some View {
        if let image = Self.downsample(url, maxPixel: maxPixel) {
            if #available(iOS 18.0, *) {
                Image(uiImage: image)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .scaledToFill()
            } else {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        } else {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
                .accessibilityLabel("사진을 읽지 못했어요")
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
        .description("고른 사진을 띄워요. 여러 장을 고르면 간격마다 넘어가고, 좌우를 눌러 넘길 수도 있어요.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}
