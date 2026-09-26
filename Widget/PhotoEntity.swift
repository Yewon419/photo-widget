import AppIntents
import Foundation

struct PhotoEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "사진"
    static let defaultQuery = PhotoQuery()

    let id: UUID
    let createdAt: Date

    init(item: PhotoItem) {
        id = item.id
        createdAt = item.createdAt
    }

    var displayRepresentation: DisplayRepresentation {
        let thumbnail = (try? PhotoStore.thumbnailURL(for: id)).map { DisplayRepresentation.Image(url: $0) }
        return DisplayRepresentation(
            title: "\(createdAt.formatted(date: .abbreviated, time: .shortened)) 추가",
            image: thumbnail
        )
    }
}

struct PhotoQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [PhotoEntity] {
        try PhotoStore.loadIndex()
            .filter { identifiers.contains($0.id) }
            .map(PhotoEntity.init(item:))
    }

    func suggestedEntities() async throws -> [PhotoEntity] {
        try PhotoStore.loadIndex().map(PhotoEntity.init(item:))
    }
}

enum SlideInterval: String, AppEnum {
    case fiveMinutes
    case fifteenMinutes
    case hour
    case day

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "넘김 간격"
    static let caseDisplayRepresentations: [SlideInterval: DisplayRepresentation] = [
        .fiveMinutes: "5분",
        .fifteenMinutes: "15분",
        .hour: "1시간",
        .day: "하루",
    ]

    var seconds: TimeInterval {
        switch self {
        case .fiveMinutes: 5 * 60
        case .fifteenMinutes: 15 * 60
        case .hour: 60 * 60
        case .day: 24 * 60 * 60
        }
    }
}

struct SelectPhotoIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "사진 선택"
    static let description = IntentDescription("위젯에 띄울 사진을 골라요. 여러 장을 고르면 간격마다 넘어가요.")

    @Parameter(title: "사진")
    var photos: [PhotoEntity]?

    @Parameter(title: "넘김 간격", default: .fifteenMinutes)
    var interval: SlideInterval

    init() {}
}

/// Tap-to-advance position per photo list, shared between timeline and button intent.
enum SlideState {
    private static let defaultsKey = "slideOffsets"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.identifier)
    }

    static func key(for ids: [UUID]) -> String {
        ids.map(\.uuidString).joined(separator: ",")
    }

    static func offset(for key: String) -> Int {
        (defaults?.dictionary(forKey: defaultsKey) as? [String: Int])?[key] ?? 0
    }

    static func advance(_ key: String, by step: Int) {
        guard let defaults else { return }
        var offsets = defaults.dictionary(forKey: defaultsKey) as? [String: Int] ?? [:]
        offsets[key, default: 0] += step
        defaults.set(offsets, forKey: defaultsKey)
    }
}

struct AdvancePhotoIntent: AppIntent {
    static let title: LocalizedStringResource = "사진 넘기기"
    static let isDiscoverable = false

    @Parameter(title: "사진 목록")
    var key: String

    @Parameter(title: "방향")
    var step: Int

    init() {}

    init(key: String, step: Int) {
        self.key = key
        self.step = step
    }

    func perform() async throws -> some IntentResult {
        SlideState.advance(key, by: step)
        return .result()
    }
}
