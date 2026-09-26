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

struct SelectPhotoIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "사진 선택"
    static let description = IntentDescription("위젯에 띄울 사진을 골라요.")

    @Parameter(title: "사진")
    var photo: PhotoEntity?

    init() {}
}
