import SwiftUI

struct PopoverView: View {
    let networkMonitor: NetworkMonitor
    let hotspotDetector: HotspotDetector
    let pingMonitor: PingMonitor
    let ipResolver: IPResolver
    let locationManager: LocationManager

    @State private var refreshID = UUID()

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
        .id(refreshID)
        .padding(16)
        .frame(width: 280)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            refreshID = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("connectionChanged"))) { _ in
            hotspotDetector.refreshNow()
            refreshID = UUID()
        }
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

    private var ssidString: String? {
        guard let conn = hotspotDetector.currentConnection else { return nil }
        switch conn.type {
        case .normalWiFi(let ssid, _): return ssid
        case .iOSPersonalHotspot(let ssid): return ssid
        case .androidHotspot(let ssid): return ssid
        default: return nil
        }
    }

    private var bssidString: String? {
        guard let conn = hotspotDetector.currentConnection else { return nil }
        switch conn.type {
        case .normalWiFi(_, let bssid): return bssid
        default: return nil
        }
    }

    private var usesWiFi: Bool {
        guard let conn = hotspotDetector.currentConnection else { return false }
        switch conn.type {
        case .normalWiFi, .iOSPersonalHotspot, .androidHotspot: return true
        default: return false
        }
    }

    private var connectionDetailView: some View {
        VStack(alignment: .leading, spacing: 6) {
            detailRow(label: "유형", value: connectionTypeString)
            if let ssid = ssidString {
                let rssiSuffix: String = {
                    guard let r = hotspotDetector.currentConnection?.rssi else { return "" }
                    return " (\(r)dBm)"
                }()
                detailRow(label: "네트워크", value: "\(ssid)\(rssiSuffix)")
            } else if usesWiFi {
                let rssiSuffix: String = {
                    guard let r = hotspotDetector.currentConnection?.rssi else { return "" }
                    return " (\(r)dBm)"
                }()
                detailRow(label: "네트워크", value: "알 수 없음\(rssiSuffix)")
            }
            if let bssid = bssidString {
                detailRow(label: "BSSID", value: bssid)
            }
            if let phy = hotspotDetector.currentConnection?.phyMode {
                detailRow(label: "규격", value: phy)
            }
            if let ch = hotspotDetector.currentConnection?.channel,
               let band = hotspotDetector.currentConnection?.channelBand {
                let width = hotspotDetector.currentConnection?.channelWidth ?? 0
                detailRow(label: "채널", value: width > 0 ? "\(ch) (\(band), \(width)MHz)" : "\(ch) (\(band))")
            }
            if let speed = hotspotDetector.currentConnection?.linkSpeed {
                detailRow(label: "속도", value: String(format: "%.0f Mbps", speed))
            }
            if let gw = hotspotDetector.currentConnection?.gatewayIP {
                detailRow(label: "게이트웨이", value: gw)
            }
            if let ip = hotspotDetector.currentConnection?.localIP {
                detailRow(label: "로컬 IP", value: ip)
            }
            if let extIP = ipResolver.externalIP {
                let country = ipResolver.geoInfo?.countryCode.map { " (\(flag(from: $0)))" } ?? ""
                detailRow(label: "외부 IP", value: "\(extIP)\(country)")
            }
            detailRow(label: "Ping", value: pingString)
            if usesWiFi && ssidString == nil {
                locationWarningView
            }
        }
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

    private var locationWarningView: some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: "location.slash")
                .font(.caption2)
                .foregroundColor(.orange)
                .padding(.top, 2)
            if !LocationManager.systemLocationServicesEnabled {
                Text("시스템 설정 > 개인정보 보호 및 보안 >\n위치 서비스를 켜주세요")
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button("설정 열기") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.orange)
            } else if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                Text("시스템 설정 > 개인정보 보호 및 보안 >\n위치 서비스 > TetherLens를 허용해주세요")
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button("설정 열기") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.orange)
            } else if !locationManager.isAuthorized {
                Text("TetherLens가 Wi-Fi 정보를 읽기 위해\n위치 접근 권한이 필요합니다")
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button("권한 요청") {
                    locationManager.requestAuthorization()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.orange)
            } else {
                Text("Wi-Fi 정보(SSID)를 읽을 수 없습니다.\nApple Developer 프로비저닝이 필요합니다")
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button("설정 열기") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.orange)
            }
        }
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
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func formatSpeed(_ bps: Double) -> String {
        let Bps = bps / 8
        if Bps >= 1_000_000_000 {
            return String(format: "%.1f GB/s", Bps / 1_000_000_000)
        } else if Bps >= 1_000_000 {
            return String(format: "%.1f MB/s", Bps / 1_000_000)
        } else if Bps >= 1_000 {
            return String(format: "%.1f KB/s", Bps / 1_000)
        } else {
            return String(format: "%.0f B/s", Bps)
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

    private func flag(from countryCode: String) -> String {
        let base: UInt32 = 127_397
        return countryCode
            .unicodeScalars
            .map { String(UnicodeScalar(base + $0.value)!) }
            .joined()
    }
}
