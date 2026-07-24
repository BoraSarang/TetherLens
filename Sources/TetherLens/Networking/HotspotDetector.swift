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

    func refreshWifiInfo() -> (ssid: String?, bssid: String?) {
        guard CLLocationManager.locationServicesEnabled() else {
            return (nil, nil)
        }

        let client = CWWiFiClient.shared()
        guard let interface = client.interface() else {
            return (nil, nil)
        }

        let ssid = interface.ssid()
        let bssid = interface.bssid()
        return (ssid, bssid)
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
            currentConnection = ConnectionInfo(
                type: .ethernet,
                interfaceName: interfaceName,
                localIP: localIP,
                gatewayIP: gatewayIP,
                isExpensive: isExpensive,
                isConstrained: isConstrained
            )
            return
        }

        if usesWiFi {
            let (ssid, bssid) = refreshWifiInfo()

            if isExpensive {
                if let gw = gatewayIP, gw.hasPrefix("192.168.43.") {
                    currentConnection = ConnectionInfo(
                        type: .androidHotspot(ssid: ssid),
                        interfaceName: interfaceName,
                        localIP: localIP,
                        gatewayIP: gatewayIP,
                        isExpensive: isExpensive,
                        isConstrained: isConstrained
                    )
                    return
                }

                if let gw = gatewayIP, gw.hasPrefix("172.20.10.") {
                    currentConnection = ConnectionInfo(
                        type: .iOSPersonalHotspot(ssid: ssid),
                        interfaceName: interfaceName,
                        localIP: localIP,
                        gatewayIP: gatewayIP,
                        isExpensive: isExpensive,
                        isConstrained: isConstrained
                    )
                    return
                }

                currentConnection = ConnectionInfo(
                    type: .iOSPersonalHotspot(ssid: ssid),
                    interfaceName: interfaceName,
                    localIP: localIP,
                    gatewayIP: gatewayIP,
                    isExpensive: isExpensive,
                    isConstrained: isConstrained
                )
                return
            }

            currentConnection = ConnectionInfo(
                type: .normalWiFi(ssid: ssid, bssid: bssid),
                interfaceName: interfaceName,
                localIP: localIP,
                gatewayIP: gatewayIP,
                isExpensive: isExpensive,
                isConstrained: isConstrained
            )
            return
        }

        currentConnection = ConnectionInfo(
            type: .unknown,
            interfaceName: interfaceName,
            localIP: localIP,
            gatewayIP: gatewayIP,
            isExpensive: isExpensive,
            isConstrained: isConstrained
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


