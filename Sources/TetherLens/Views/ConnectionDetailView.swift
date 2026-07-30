import SwiftUI

struct ConnectionDetailView: View {
    let detail: NetworkDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                detailRow(Localized.type, connectionTypeString)
                detailRow("OS", osString)
                detailRow("SSID", detail.wifi?.ssid ?? "-")
                detailRow(Localized.bssid, detail.wifi?.bssid ?? "-")
                if let linkSpeed = detail.wifi?.linkSpeed {
                    detailRow(Localized.connectionSpeed, String(format: "%.0f Mbps", linkSpeed))
                }
                if let channel = detail.wifi?.channel {
                    let width = detail.wifi?.channelWidth ?? 0
                    detailRow(Localized.channel, Localized.channelLabel(channel, width))
                }
                detailRow(Localized.localIP, detail.localIP ?? "-")
                detailRow(Localized.externalIP, externalIPString)
                detailRow(Localized.dns, detail.dnsServers.first ?? "-")
            }
        }
        .font(.caption)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 64, alignment: .trailing)
            Text(value)
                .foregroundColor(.primary)
                .textSelection(.enabled)
            Spacer()
        }
    }

    private var connectionTypeString: String {
        switch detail.type {
        case .normalWiFi: return "Wi-Fi"
        case .ethernet: return "Ethernet"
        case .iOSPersonalHotspot: return Localized.hotspotWifi("iOS")
        case .androidHotspot: return Localized.hotspotWifi("Android")
        case .unknown: return Localized.unknown
        }
    }

    private var osString: String {
        switch detail.type {
        case .iOSPersonalHotspot: return "iOS"
        case .androidHotspot: return "Android"
        default: return "-"
        }
    }

    private var externalIPString: String {
        if let ip = detail.externalIP {
            if let code = detail.countryCode {
                return "\(ip)  \(flag(from: code))"
            }
            return ip
        }
        return "-"
    }

    private func flag(from countryCode: String) -> String {
        let base: UInt32 = 127_397
        return countryCode
            .unicodeScalars
            .map { String(UnicodeScalar(base + $0.value)!) }
            .joined()
    }
}
