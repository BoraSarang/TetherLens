import Foundation
import Sparkle

@MainActor
final class UpdaterManager: NSObject {
    static let shared = UpdaterManager()

    private let updaterController: SPUStandardUpdaterController

    private override init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
