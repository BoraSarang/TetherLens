import Foundation

struct WiFiDetail {
    let ssid: String?
    let bssid: String?
    let rssi: Int?
    let noise: Int?
    let channel: Int?
    let channelWidth: Int?
    let linkSpeed: Double?
    let securityType: String?
}

struct NetworkDetail {
    let type: ConnectionType
    let interfaceName: String?
    let localIP: String?
    let gatewayIP: String?
    let externalIP: String?
    let countryCode: String?
    let dnsServers: [String]
    let wifi: WiFiDetail?
}
