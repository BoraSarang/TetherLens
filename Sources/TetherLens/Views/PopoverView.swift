import SwiftUI

struct PopoverView: View {
    let networkMonitor: NetworkMonitor
    let hotspotDetector: HotspotDetector
    let pingMonitor: PingMonitor

    var body: some View {
        VStack(spacing: 12) {
            headerView
            Divider()
            connectionDetailView
            Divider()
            qosGaugeView
            Divider()
            speedView
            Divider()
            bottomButtons
        }
        .padding(16)
        .frame(width: 280)
    }

    private var headerView: some View {
        HStack {
            Image(systemName: connectionIcon)
                .font(.title2)
            Text(connectionName)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            statusDot
        }
    }

    private var connectionIcon: String {
        guard let conn = hotspotDetector.currentConnection else { return "wifi" }
        switch conn.type {
        case .iOSPersonalHotspot, .androidHotspot:
            return "personalhotspot"
        case .ethernet:
            return "cable.connector"
        case .normalWiFi:
            return "wifi"
        case .unknown:
            return "questionmark.circle"
        }
    }

    private var connectionName: String {
        guard let conn = hotspotDetector.currentConnection else { return "연결 없음" }
        switch conn.type {
        case .iOSPersonalHotspot(let ssid):
            return ssid ?? "iOS 핫스팟"
        case .androidHotspot(let ssid):
            return ssid ?? "Android 핫스팟"
        case .normalWiFi(let ssid, _):
            return ssid ?? "Wi-Fi"
        case .ethernet:
            return "Ethernet"
        case .unknown:
            return "알 수 없음"
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(pingMonitor.isReachable ? Color.green : Color.red)
            .frame(width: 10, height: 10)
    }

    private var connectionDetailView: some View {
        VStack(alignment: .leading, spacing: 6) {
            detailRow(label: "유형", value: connectionTypeString)
            if let gw = hotspotDetector.currentConnection?.gatewayIP {
                detailRow(label: "게이트웨이", value: gw)
            }
            if let ip = hotspotDetector.currentConnection?.localIP {
                detailRow(label: "로컬 IP", value: ip)
            }
            detailRow(label: "Ping", value: pingString)
        }
        .font(.caption)
    }

    private var connectionTypeString: String {
        guard let conn = hotspotDetector.currentConnection else { return "-" }
        switch conn.type {
        case .iOSPersonalHotspot:
            return "iOS 핫스팟"
        case .androidHotspot:
            return "Android 핫스팟"
        case .normalWiFi:
            return "Wi-Fi"
        case .ethernet:
            return "Ethernet"
        case .unknown:
            return "알 수 없음"
        }
    }

    private var pingString: String {
        if let dns = pingMonitor.dnsRTT {
            let ms = Int(dns * 1000)
            return "\(ms)ms (8.8.8.8)"
        }
        return "측정 중..."
    }

    private var qosGaugeView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("QoS 방지 게이지")
                .font(.caption)
                .foregroundColor(.secondary)
            QoSGauge(used: 2.7, total: 3.0)
        }
    }

    private var speedView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("▲ 업로드")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(formatSpeed(networkMonitor.currentUploadSpeed))
                    .font(.system(.title3, design: .monospaced))
                    .foregroundColor(.orange)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("▼ 다운로드")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(formatSpeed(networkMonitor.currentDownloadSpeed))
                    .font(.system(.title3, design: .monospaced))
                    .foregroundColor(.blue)
            }
        }
    }

    private var bottomButtons: some View {
        HStack(spacing: 12) {
            Button("설정") { openSettings() }
                .buttonStyle(.bordered)
                .controlSize(.small)
            Button("통계") { openStatistics() }
                .buttonStyle(.bordered)
                .controlSize(.small)
            Button("절약 모드") { openSavingMode() }
                .buttonStyle(.bordered)
                .controlSize(.small)
            Spacer()
            Button("종료") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.red)
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .foregroundColor(.primary)
            Spacer()
        }
    }

    private func formatSpeed(_ bps: Double) -> String {
        if bps >= 1_000_000_000 {
            return String(format: "%.1f Gbps", bps / 1_000_000_000)
        } else if bps >= 1_000_000 {
            return String(format: "%.1f Mbps", bps / 1_000_000)
        } else if bps >= 1_000 {
            return String(format: "%.1f Kbps", bps / 1_000)
        } else {
            return String(format: "%.0f bps", bps)
        }
    }

    private func openSettings() {
        if #available(macOS 14.0, *) {
            NSApplication.shared.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }

    private func openStatistics() {
    }

    private func openSavingMode() {
    }
}
