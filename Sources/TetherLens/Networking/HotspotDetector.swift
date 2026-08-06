import Foundation
import Network
import CoreWLAN
import CoreLocation

enum ConnectionType: Equatable {
    case normalWiFi(ssid: String?, bssid: String?)
    case ethernet
    case iOSPersonalHotspot(ssid: String?)
    case androidHotspot(ssid: String?)
    case unknown
}

struct ConnectionInfo {
    let type: ConnectionType
    let interfaceName: String?
    let localIP: String?
    let gatewayIP: String?
    let isExpensive: Bool
    let isConstrained: Bool
    let rssi: Int?
    let noise: Int?
    let linkSpeed: Double?
    let channel: Int?
    let channelWidth: Int?
    let channelBand: String?
    let phyMode: String?
    let dnsServers: [String]
}

class HotspotDetector: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.tetherlens.hotspot-detector", qos: .utility)

    private(set) var currentConnection: ConnectionInfo?
    var isNetworkAvailable: Bool { monitor.currentPath.status == .satisfied }

    private var hasStarted = false

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateConnection(path: path)
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        hasStarted = false
        monitor.cancel()
    }

    func refreshNow() {
        let path = monitor.currentPath
        updateConnection(path: path)
    }

    func refreshWifiInfo() -> (ssid: String?, bssid: String?, rssi: Int?, noise: Int?, linkSpeed: Double?, channel: Int?, channelWidth: Int?, channelBand: String?, phyMode: String?) {
        guard CLLocationManager.locationServicesEnabled() else {
            return (nil, nil, nil, nil, nil, nil, nil, nil, nil)
        }

        let client = CWWiFiClient.shared()
        guard let interface = client.interface() else {
            return (nil, nil, nil, nil, nil, nil, nil, nil, nil)
        }

        let ssid = interface.ssid()
        let bssid = interface.bssid()
        let rssi = interface.rssiValue()
        let noise = interface.noiseMeasurement()
        let linkSpeed = interface.transmitRate()

        var channelNumber: Int? = nil
        var channelWidth: Int? = nil
        var channelBand: String? = nil
        var phyMode: String? = nil

        if let cwChannel = interface.wlanChannel() {
            channelNumber = cwChannel.channelNumber
            let widthValues: [Int: Int] = [0: 20, 1: 40, 2: 80, 3: 160]
            channelWidth = widthValues[cwChannel.channelWidth.rawValue]
            let bandValues: [Int: String] = [1: "2.4GHz", 2: "5GHz", 3: "6GHz"]
            channelBand = bandValues[cwChannel.channelBand.rawValue]
        }

        switch interface.activePHYMode() {
        case .mode11a: phyMode = "802.11a"
        case .mode11b: phyMode = "802.11b"
        case .mode11g: phyMode = "802.11g"
        case .mode11n: phyMode = "802.11n"
        case .mode11ac: phyMode = "802.11ac"
        case .mode11ax: phyMode = "802.11ax"
        default: break
        }

        return (ssid, bssid, rssi, noise, linkSpeed, channelNumber, channelWidth, channelBand, phyMode)
    }

    private func makeInfo(type: ConnectionType, interfaceName: String?, localIP: String?, gatewayIP: String?, isExpensive: Bool, isConstrained: Bool) -> ConnectionInfo {
        ConnectionInfo(
            type: type,
            interfaceName: interfaceName,
            localIP: localIP,
            gatewayIP: gatewayIP,
            isExpensive: isExpensive,
            isConstrained: isConstrained,
            rssi: nil, noise: nil, linkSpeed: nil, channel: nil, channelWidth: nil,
            channelBand: nil, phyMode: nil,
            dnsServers: getDNSServers()
        )
    }

    private func makeWiFiInfo(type: ConnectionType, interfaceName: String?, localIP: String?, gatewayIP: String?, isExpensive: Bool, isConstrained: Bool, wifi: (ssid: String?, bssid: String?, rssi: Int?, noise: Int?, linkSpeed: Double?, channel: Int?, channelWidth: Int?, channelBand: String?, phyMode: String?)) -> ConnectionInfo {
        ConnectionInfo(
            type: type,
            interfaceName: interfaceName,
            localIP: localIP,
            gatewayIP: gatewayIP,
            isExpensive: isExpensive,
            isConstrained: isConstrained,
            rssi: wifi.rssi,
            noise: wifi.noise,
            linkSpeed: wifi.linkSpeed,
            channel: wifi.channel,
            channelWidth: wifi.channelWidth,
            channelBand: wifi.channelBand,
            phyMode: wifi.phyMode,
            dnsServers: getDNSServers()
        )
    }

    private func updateConnection(path: NWPath) {
        let isExpensive = path.isExpensive
        let isConstrained = path.isConstrained
        let usesWiFi = path.usesInterfaceType(.wifi)
        let usesEthernet = path.usesInterfaceType(.wiredEthernet)
        let interfaceName = availableInterfaces(from: path)

        let localIP = getLocalIP()
        let gatewayIP = getGatewayIP()

        if usesEthernet {
            currentConnection = makeInfo(
                type: .ethernet,
                interfaceName: interfaceName,
                localIP: localIP, gatewayIP: gatewayIP,
                isExpensive: isExpensive, isConstrained: isConstrained
            )
            return
        }

        if usesWiFi {
            let wifi = refreshWifiInfo()

            let detectedType: ConnectionType

            if isAndroidHotspotGateway(gatewayIP) {
                detectedType = .androidHotspot(ssid: wifi.ssid)
            } else if gatewayIP?.hasPrefix("172.20.10.") == true {
                detectedType = .iOSPersonalHotspot(ssid: wifi.ssid)
            } else if isAndroidSSID(wifi.ssid) {
                detectedType = .androidHotspot(ssid: wifi.ssid)
            } else if isExpensive {
                detectedType = .iOSPersonalHotspot(ssid: wifi.ssid)
            } else {
                detectedType = .normalWiFi(ssid: wifi.ssid, bssid: wifi.bssid)
            }

            currentConnection = makeWiFiInfo(
                type: detectedType,
                interfaceName: interfaceName,
                localIP: localIP, gatewayIP: gatewayIP,
                isExpensive: isExpensive, isConstrained: isConstrained,
                wifi: wifi
            )
            return
        }

        currentConnection = makeInfo(
            type: .unknown,
            interfaceName: interfaceName,
            localIP: localIP, gatewayIP: gatewayIP,
            isExpensive: isExpensive, isConstrained: isConstrained
        )
    }

    private func availableInterfaces(from path: NWPath) -> String? {
        for interface in path.availableInterfaces {
            if interface.type == .wifi || interface.type == .wiredEthernet {
                return interface.name
            }
        }
        return nil
    }

    private func getLocalIP() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let start = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr = start
        while true {
            let addr = ptr.pointee
            let name = String(cString: addr.ifa_name)
            let family = addr.ifa_addr.pointee.sa_family

            if family == UInt8(AF_INET),
               name == "en0" || name == "en1" || name == "ap1" {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(
                    addr.ifa_addr,
                    socklen_t(addr.ifa_addr.pointee.sa_len),
                    &hostname, socklen_t(hostname.count),
                    nil, 0,
                    NI_NUMERICHOST
                )
                let decoded = String(decoding: Data(bytes: hostname, count: hostname.count), as: UTF8.self)
                return decoded.trimmingCharacters(in: .controlCharacters)
            }

            guard let next = addr.ifa_next else { break }
            ptr = next
        }
        return nil
    }

    private func getGatewayIP() -> String? {
        let paths = ["/sbin/route", "/usr/sbin/route"]
        guard let routePath = paths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return nil
        }

        let task = Process()
        task.launchPath = routePath
        task.arguments = ["-n", "get", "default"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            for line in output.components(separatedBy: "\n") {
                if line.contains("gateway:") {
                    return line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces)
                }
            }
        } catch {}

        return nil
    }

    private func hotspotTypeByBSSID(_ bssid: String?) -> ConnectionType {
        guard let bssid = bssid?.uppercased() else { return .androidHotspot(ssid: nil) }
        let appleOUIs: Set<String> = [
            "00:17:F2", "00:1E:52", "00:1F:F3", "00:21:E9", "00:22:41",
            "00:23:32", "00:23:6E", "00:25:00", "00:25:BC", "00:26:08",
            "00:26:B0", "00:27:0A", "30:10:B3", "60:03:08", "68:5B:35",
            "88:66:5A", "8C:85:90", "A4:D1:D2", "B0:65:BD", "B8:F7:61",
            "C8:89:F3", "D0:A6:37", "D4:61:9D", "F0:18:98", "F4:F5:E5"
        ]
        let oui = String(bssid.prefix(8))
        return appleOUIs.contains(oui) ? .iOSPersonalHotspot(ssid: nil) : .androidHotspot(ssid: nil)
    }

    func isAndroidHotspotGateway(_ ip: String?) -> Bool {
        guard let ip = ip else { return false }
        let prefixes = [
            "192.168.43.",  // Samsung
            "192.168.42.",  // LG 등
            "192.168.44.",  // 기타
            "192.168.49.",  // Xiaomi / Pixel
            "192.168.80.",  // 기타
            "192.168.81.",  // Android 14+ 일부
            "192.168.111."  // Pixel 일부
        ]
        return prefixes.contains { ip.hasPrefix($0) }
    }

    func isAndroidSSID(_ ssid: String?) -> Bool {
        guard let ssid = ssid?.lowercased() else { return false }
        let keywords = ["galaxy", "android", "sm-", "samsung", "oneplus", "xiaomi",
                        "redmi", "huawei", "pixel", "motog", "asus", "tplink", "tp-link",
                        "okstart", "oppo", "vivo", "realme", "infinix", "tecno"]
        return keywords.contains { ssid.contains($0) }
    }

    private func getDNSServers() -> [String] {
        guard let content = try? String(contentsOfFile: "/etc/resolv.conf") else { return [] }
        return content.components(separatedBy: .newlines)
            .filter { $0.hasPrefix("nameserver") }
            .compactMap { $0.components(separatedBy: .whitespaces).last }
            .filter { !$0.isEmpty }
    }
}

extension ConnectionInfo {
    var ssid: String? {
        switch type {
        case .normalWiFi(let ssid, _): return ssid
        case .iOSPersonalHotspot(let ssid): return ssid
        case .androidHotspot(let ssid): return ssid
        case .ethernet, .unknown: return nil
        }
    }
}
