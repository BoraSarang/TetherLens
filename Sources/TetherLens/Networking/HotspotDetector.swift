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
}

class HotspotDetector: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.tetherlens.hotspot-detector", qos: .utility)

    private(set) var currentConnection: ConnectionInfo?

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateConnection(path: path)
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }

    func refreshNow() {
        let path = monitor.currentPath
        updateConnection(path: path)
    }

    func refreshWifiInfo() -> (ssid: String?, bssid: String?, rssi: Int?, noise: Int?, linkSpeed: Double?, channel: Int?, channelWidth: Int?) {
        guard CLLocationManager.locationServicesEnabled() else {
            return (nil, nil, nil, nil, nil, nil, nil)
        }

        let client = CWWiFiClient.shared()
        guard let interface = client.interface() else {
            return (nil, nil, nil, nil, nil, nil, nil)
        }

        let ssid = interface.ssid()
        let bssid = interface.bssid()
        let rssi = interface.rssiValue()
        let noise = interface.noiseMeasurement()
        let linkSpeed = interface.transmitRate()
        return (ssid, bssid, rssi, noise, linkSpeed, nil, nil)
    }

    private func makeInfo(type: ConnectionType, interfaceName: String?, localIP: String?, gatewayIP: String?, isExpensive: Bool, isConstrained: Bool) -> ConnectionInfo {
        ConnectionInfo(
            type: type,
            interfaceName: interfaceName,
            localIP: localIP,
            gatewayIP: gatewayIP,
            isExpensive: isExpensive,
            isConstrained: isConstrained,
            rssi: nil, noise: nil, linkSpeed: nil, channel: nil, channelWidth: nil
        )
    }

    private func makeWiFiInfo(type: ConnectionType, interfaceName: String?, localIP: String?, gatewayIP: String?, isExpensive: Bool, isConstrained: Bool, wifi: (ssid: String?, bssid: String?, rssi: Int?, noise: Int?, linkSpeed: Double?, channel: Int?, channelWidth: Int?)) -> ConnectionInfo {
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
            channelWidth: wifi.channelWidth
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

            if let gw = gatewayIP, gw.hasPrefix("192.168.43.") {
                detectedType = .androidHotspot(ssid: wifi.ssid)
            } else if let gw = gatewayIP, gw.hasPrefix("172.20.10.") {
                detectedType = .iOSPersonalHotspot(ssid: wifi.ssid)
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
        let task = Process()
        task.launchPath = "/usr/sbin/route"
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
}


