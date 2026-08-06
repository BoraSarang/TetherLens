import SwiftUI

struct QoSGauge: View {
    let used: Double
    let total: Double

    private var ratio: Double {
        guard total > 0 else { return 0 }
        return min(used / total, 1.0)
    }

    private var gaugeColor: Color {
        let greenBoundary = SavingModeManager.shared.greenThreshold
        let orangeBoundary = SavingModeManager.shared.orangeThreshold
        if ratio < greenBoundary {
            return .green
        } else if ratio < orangeBoundary {
            return .orange
        } else {
            return .red
        }
    }

    private var remaining: Double {
        max(total - used, 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(gaugeColor)
                        .frame(width: geometry.size.width * ratio, height: 12)
                }
            }
            .frame(height: 12)

            HStack {
                let pct = Int(ratio * 100)
                Text(Localized.usagePercent(formatGB(used), formatGB(total), pct))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(Localized.remaining(formatGB(remaining)))
                    .font(.caption2)
                    .foregroundColor(gaugeColor)
            }
        }
    }

    private func formatGB(_ value: Double) -> String {
        if value >= 1.0 {
            return String(format: "%.1fGB", value)
        } else {
            return String(format: "%.0fMB", value * 1000)
        }
    }
}
