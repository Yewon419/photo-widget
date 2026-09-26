import PhotosUI
import SwiftUI

struct LibraryView: View {
    @State private var library = PhotoLibrary()
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isImporting = false
    @State private var pendingDelete: PhotoItem?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        NavigationStack {
            Group {
                if library.items.isEmpty && !isImporting {
                    emptyState
                } else {
                    grid
                }
            }
            .navigationTitle("포토위젯")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isImporting {
                        ProgressView()
                    } else {
                        PhotosPicker(selection: $pickerItems, matching: .images) {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("사진 추가")
                    }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                CropEditorView(library: library, photoID: id)
            }
            .onChange(of: pickerItems) { _, picked in
                importPicked(picked)
            }
            .task {
                library.load()
            }
            .confirmationDialog(
                "이 사진을 삭제할까요?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingDelete
            ) { item in
                Button("삭제", role: .destructive) {
                    library.delete(item.id)
                }
            } message: { _ in
                Text("이 사진을 쓰던 위젯은 빈 상태로 바뀌어요.")
            }
            .alert(
                "문제가 생겼어요",
                isPresented: Binding(
                    get: { library.errorMessage != nil },
                    set: { if !$0 { library.errorMessage = nil } }
                )
            ) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(library.errorMessage ?? "")
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("사진 없음", systemImage: "photo.on.rectangle")
        } description: {
            Text("사진을 추가하면 홈 화면 위젯에서 골라 띄울 수 있어요.")
        } actions: {
            PhotosPicker(selection: $pickerItems, matching: .images) {
                Text("사진 추가")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(library.items) { item in
                    NavigationLink(value: item.id) {
                        PhotoThumbnail(item: item)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            pendingDelete = item
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .contentMargins(.vertical, 8, for: .scrollContent)
    }

    private func importPicked(_ picked: [PhotosPickerItem]) {
        guard !picked.isEmpty else { return }
        pickerItems = []
        isImporting = true
        Task {
            for item in picked {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        library.errorMessage = "사진 데이터를 불러오지 못했어요."
                        continue
                    }
                    await library.add(data)
                } catch {
                    library.errorMessage = "사진을 불러오지 못했어요: \(error.localizedDescription)"
                }
            }
            isImporting = false
        }
    }
}

private struct PhotoThumbnail: View {
    let item: PhotoItem
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Color(uiColor: .secondarySystemBackground)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if failed {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }
            }
            .clipped()
            .contentShape(Rectangle())
            .task(id: item.revision) {
                do {
                    let url = try PhotoStore.thumbnailURL(for: item.id)
                    image = UIImage(contentsOfFile: url.path)
                    failed = image == nil
                } catch {
                    failed = true
                }
            }
    }
}
