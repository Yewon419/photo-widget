import Foundation

enum AppGroup {
    static let identifier = "group.com.windgarden.photowidget"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
