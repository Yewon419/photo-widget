import Foundation
import Observation
import WidgetKit

@MainActor
@Observable
final class PhotoLibrary {
    private(set) var items: [PhotoItem] = []
    var errorMessage: String?
    /// Serializes crop re-renders so an older render never lands after a newer one.
    private var writeChain: Task<Void, Never>?

    func item(_ id: UUID) -> PhotoItem? {
        items.first { $0.id == id }
    }

    func load() {
        do {
            items = try PhotoStore.loadIndex()
        } catch {
            errorMessage = "사진 목록을 읽지 못했어요: \(error.localizedDescription)"
        }
    }

    func add(_ data: Data) async {
        do {
            let item = try await Task.detached(priority: .userInitiated) {
                try PhotoImporter.makeItem(from: data)
            }.value
            items.insert(item, at: 0)
            try PhotoStore.saveIndex(items)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            errorMessage = "사진을 추가하지 못했어요: \(error.localizedDescription)"
        }
    }

    func updateCrop(_ rect: CGRect, aspect: CropAspect, for id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].crops[aspect] = rect
        let previous = writeChain
        writeChain = Task {
            await previous?.value
            do {
                try await Task.detached(priority: .userInitiated) {
                    try PhotoImporter.renderCrop(rect, aspect: aspect, for: id)
                }.value
                if let index = items.firstIndex(where: { $0.id == id }) {
                    items[index].revision += 1
                }
                try PhotoStore.saveIndex(items)
                WidgetCenter.shared.reloadAllTimelines()
            } catch {
                errorMessage = "위치를 저장하지 못했어요: \(error.localizedDescription)"
            }
        }
    }

    func delete(_ id: UUID) {
        items.removeAll { $0.id == id }
        do {
            try PhotoStore.saveIndex(items)
            try PhotoStore.removeFiles(for: id)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            errorMessage = "사진을 삭제하지 못했어요: \(error.localizedDescription)"
        }
    }
}
