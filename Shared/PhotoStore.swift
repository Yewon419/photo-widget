import CoreGraphics
import Foundation

enum CropAspect: String, Codable, CodingKeyRepresentable, CaseIterable, Identifiable {
    case square
    case wide

    var id: String { rawValue }

    /// width / height
    var ratio: CGFloat {
        switch self {
        case .square: 1
        case .wide: 2.14
        }
    }

    var title: String {
        switch self {
        case .square: "정사각"
        case .wide: "가로"
        }
    }

    var usage: String {
        switch self {
        case .square: "홈 소형·대형, 잠금화면 원형 위젯에 쓰여요"
        case .wide: "홈 중형, 잠금화면 가로형 위젯에 쓰여요"
        }
    }

    var outputPixelSize: CGSize {
        switch self {
        case .square: CGSize(width: 1200, height: 1200)
        case .wide: CGSize(width: 1284, height: 600)
        }
    }
}

struct PhotoItem: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    /// Normalized (0...1) crop rect in source image coordinates, per aspect.
    var crops: [CropAspect: CGRect]
    var revision: Int
}

enum PhotoStoreError: LocalizedError {
    case containerUnavailable

    var errorDescription: String? {
        "App Group 컨테이너를 열 수 없어요 (\(AppGroup.identifier))"
    }
}

enum PhotoStore {
    static func rootURL() throws -> URL {
        guard let container = AppGroup.containerURL else {
            throw PhotoStoreError.containerUnavailable
        }
        return container.appendingPathComponent("Photos", isDirectory: true)
    }

    static func indexURL() throws -> URL {
        try rootURL().appendingPathComponent("index.json")
    }

    static func directoryURL(for id: UUID) throws -> URL {
        try rootURL().appendingPathComponent(id.uuidString, isDirectory: true)
    }

    static func sourceURL(for id: UUID) throws -> URL {
        try directoryURL(for: id).appendingPathComponent("source.jpg")
    }

    static func thumbnailURL(for id: UUID) throws -> URL {
        try directoryURL(for: id).appendingPathComponent("thumb.jpg")
    }

    static func cropURL(for id: UUID, aspect: CropAspect) throws -> URL {
        try directoryURL(for: id).appendingPathComponent("crop-\(aspect.rawValue).jpg")
    }

    static func loadIndex() throws -> [PhotoItem] {
        let url = try indexURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([PhotoItem].self, from: Data(contentsOf: url))
    }

    static func saveIndex(_ items: [PhotoItem]) throws {
        try FileManager.default.createDirectory(at: rootURL(), withIntermediateDirectories: true)
        try JSONEncoder().encode(items).write(to: indexURL(), options: .atomic)
    }

    static func createDirectory(for id: UUID) throws {
        try FileManager.default.createDirectory(at: directoryURL(for: id), withIntermediateDirectories: true)
    }

    static func removeFiles(for id: UUID) throws {
        try FileManager.default.removeItem(at: directoryURL(for: id))
    }
}
