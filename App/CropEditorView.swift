import SwiftUI

struct CropEditorView: View {
    let library: PhotoLibrary
    let photoID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var aspect: CropAspect = .square
    @State private var source: UIImage?
    @State private var loadFailed = false
    @State private var confirmDelete = false

    var body: some View {
        Group {
            if let item = library.item(photoID) {
                editor(for: item)
            } else {
                ContentUnavailableView("사진이 없어요", systemImage: "photo")
            }
        }
        .navigationTitle("위치 조정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("삭제")
            }
        }
        .confirmationDialog("이 사진을 삭제할까요?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                library.delete(photoID)
                dismiss()
            }
        } message: {
            Text("이 사진을 쓰던 위젯은 빈 상태로 바뀌어요.")
        }
        .task {
            do {
                let url = try PhotoStore.sourceURL(for: photoID)
                source = UIImage(contentsOfFile: url.path)
                loadFailed = source == nil
            } catch {
                loadFailed = true
            }
        }
    }

    private func editor(for item: PhotoItem) -> some View {
        VStack(spacing: 16) {
            Picker("비율", selection: $aspect) {
                ForEach(CropAspect.allCases) { aspect in
                    Text(aspect.title).tag(aspect)
                }
            }
            .pickerStyle(.segmented)

            if let source {
                CropCanvas(
                    image: source,
                    crop: Binding(
                        get: { item.crops[aspect] ?? CGRect(x: 0, y: 0, width: 1, height: 1) },
                        set: { library.updateCrop($0, aspect: aspect, for: photoID) }
                    )
                )
                .aspectRatio(aspect.ratio, contentMode: .fit)
            } else if loadFailed {
                ContentUnavailableView("원본을 읽지 못했어요", systemImage: "exclamationmark.triangle")
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            }

            VStack(spacing: 4) {
                Text(aspect.usage)
                Text("드래그로 위치를, 두 손가락으로 크기를 맞춰요")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

private struct LiveTransform {
    var translation: CGSize = .zero
    var magnification: CGFloat = 1
}

private struct CropCanvas: View {
    let image: UIImage
    @Binding var crop: CGRect

    @GestureState private var live = LiveTransform()

    var body: some View {
        GeometryReader { geo in
            let committed = CropGeometry(imageSize: image.size, viewport: geo.size, crop: crop)
            let shown = committed.applying(translation: live.translation, magnification: live.magnification)
            Image(uiImage: image)
                .resizable()
                .frame(width: shown.displaySize.width, height: shown.displaySize.height)
                .offset(shown.offset)
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .simultaneously(with: MagnifyGesture())
                        .updating($live) { value, state, _ in
                            state = LiveTransform(
                                translation: value.first?.translation ?? .zero,
                                magnification: value.second?.magnification ?? 1
                            )
                        }
                        .onEnded { value in
                            crop = committed.applying(
                                translation: value.first?.translation ?? .zero,
                                magnification: value.second?.magnification ?? 1
                            ).crop
                        }
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.separator, lineWidth: 1)
        }
        .accessibilityLabel("사진 위치 조정 영역")
    }
}
