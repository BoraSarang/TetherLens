import Foundation

extension ByteCountFormatter {
    @MainActor static let network: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .decimal
        f.allowsNonnumericFormatting = false
        f.includesUnit = true
        return f
    }()
}
