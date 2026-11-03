import AppKit

/// Local fork: updates are built locally, never installed from the upstream feed.
@MainActor
final class UpdateService: NSObject, ObservableObject {
    static let shared = UpdateService()
    let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    @Published var hasUpdate = false
    @Published var latestVersion: String? = nil
    func installUpdate() {
        let alert = NSAlert()
        alert.messageText = "映桥"
        alert.informativeText = "此版本通过随附源码和 build-local.sh 本地更新。"
        alert.runModal()
    }
}
