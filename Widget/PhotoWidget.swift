import SwiftUI
import WidgetKit

struct PingEntry: TimelineEntry {
    let date: Date
    let message: String
}

struct PingProvider: TimelineProvider {
    func placeholder(in context: Context) -> PingEntry {
        PingEntry(date: .now, message: "…")
    }

    func getSnapshot(in context: Context, completion: @escaping (PingEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PingEntry>) -> Void) {
        completion(Timeline(entries: [readEntry()], policy: .never))
    }

    private func readEntry() -> PingEntry {
        guard let url = AppGroup.pingURL else {
            return PingEntry(date: .now, message: "App Group 없음")
        }
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? "기록 없음"
        return PingEntry(date: .now, message: text)
    }
}

struct PingWidgetView: View {
    let entry: PingEntry

    var body: some View {
        Text(entry.message)
            .font(.footnote)
            .containerBackground(.background, for: .widget)
    }
}

@main
struct PhotoWidgetBundle: WidgetBundle {
    var body: some Widget {
        PingWidget()
    }
}

struct PingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PingWidget", provider: PingProvider()) { entry in
            PingWidgetView(entry: entry)
        }
        .configurationDisplayName("App Group 테스트")
        .supportedFamilies([.systemSmall])
    }
}
