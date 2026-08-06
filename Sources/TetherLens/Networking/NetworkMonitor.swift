import Foundation
import SystemConfiguration

class NetworkMonitor: @unchecked Sendable {
    private var timer: DispatchSourceTimer?
    private var previousBytes: (rx: Int64, tx: Int64) = (0, 0)
    private var lastPollDate = Date.distantPast

    private(set) var currentUploadSpeed: Double = 0
    private(set) var currentDownloadSpeed: Double = 0
    private(set) var totalUpload: Int64 = 0
    private(set) var totalDownload: Int64 = 0
    private(set) var activeInterfaceName: String?

    func start() {
        previousBytes = (0, 0)
        lastPollDate = Date.distantPast
        let queue = DispatchQueue(label: "com.tetherlens.network-monitor", qos: .utility)
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now(), repeating: 1.0)
        timer?.setEventHandler { [weak self] in
            self?.pollInterface()
        }
        timer?.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func pollInterface() {
        let (current, interface) = readInterfaceBytes()
        guard let current else { return }

        let prev = previousBytes
        let now = Date()
        let elapsed = now.timeIntervalSince(lastPollDate)
        lastPollDate = now
        // 지연(타이머 밀림)을 반영한 실제 경과 시간으로 속도 계산
        let rxSpeed = elapsed > 0 ? max(Double(current.rx - prev.rx) * 8 / elapsed, 0) : 0
        let txSpeed = elapsed > 0 ? max(Double(current.tx - prev.tx) * 8 / elapsed, 0) : 0

        previousBytes = current

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if prev.rx > 0 {
                currentDownloadSpeed = rxSpeed
                currentUploadSpeed = txSpeed
            }
            totalDownload = current.rx
            totalUpload = current.tx
            activeInterfaceName = interface
        }
    }

    private func readInterfaceBytes() -> (bytes: (rx: Int64, tx: Int64)?, interface: String?) {
        var interfaceName: String?
        var totalRX: Int64 = 0
        var totalTX: Int64 = 0

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let start = ifaddr else {
            return (nil, nil)
        }

        defer { freeifaddrs(ifaddr) }

        var ptr = start
        while true {
            let addr = ptr.pointee
            let name = String(cString: addr.ifa_name)

            if addr.ifa_addr.pointee.sa_family == AF_LINK {
                if let data = addr.ifa_data?.assumingMemoryBound(to: if_data.self).pointee {
                    let isLoopback = (addr.ifa_flags & UInt32(IFF_LOOPBACK)) != 0
                    let isUp = (addr.ifa_flags & UInt32(IFF_UP)) != 0

                    if isUp && !isLoopback {
                        let rx = Int64(data.ifi_ibytes)
                        let tx = Int64(data.ifi_obytes)

                        if name == "en0" || name == "en1" || name == "en2" || name == "en3" || name == "en4" || name == "en5" {
                            totalRX += rx
                            totalTX += tx
                            if interfaceName == nil {
                                interfaceName = name
                            }
                        } else if name == "ap1" {
                            totalRX += rx
                            totalTX += tx
                        }
                    }
                }
            }

            guard let next = addr.ifa_next else { break }
            ptr = next
        }

        return ((totalRX, totalTX), interfaceName)
    }
}
