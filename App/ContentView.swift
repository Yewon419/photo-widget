import SwiftUI
import WidgetKit

// Phase 1 smoke test: app writes to the App Group, widget reads it back.
struct ContentView: View {
    @State private var status = "아직 기록 안 함"

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(status)
                        .textSelection(.enabled)
                }
                Section {
                    Button("App Group에 기록") { writePing() }
                }
            }
            .navigationTitle("포토위젯")
        }
    }

    private func writePing() {
        guard let url = AppGroup.pingURL else {
            status = "App Group 컨테이너 없음 (권한 누락)"
            return
        }
        let stamp = Date().formatted(date: .abbreviated, time: .standard)
        do {
            try "OK \(stamp)".write(to: url, atomically: true, encoding: .utf8)
            status = "기록함: \(stamp)"
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            status = "쓰기 실패: \(error.localizedDescription)"
        }
    }
}
