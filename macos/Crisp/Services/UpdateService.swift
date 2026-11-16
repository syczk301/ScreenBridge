import AppKit

@MainActor
final class UpdateService: NSObject, ObservableObject {
    static let shared = UpdateService()
    let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    @Published var hasUpdate = false
    @Published var latestVersion: String? = nil
    override private init() { super.init(); AppUpdater.shared.start() }
    func installUpdate() { AppUpdater.shared.checkForUpdates() }
}
