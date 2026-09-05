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

    /// 초 단위 속도 히스토리 (사용 기록 차트용, 최신 120샘플 링버퍼)
    struct SpeedSample {
        let downloadBps: Double
        let uploadBps: Double
    }
    private(set) var speedHistory: [SpeedSample] = []
    private let speedHistoryLimit = 120

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
                speedHistory.append(SpeedSample(downloadBps: rxSpeed, uploadBps: txSpeed))
                if speedHistory.count > speedHistoryLimit {
                    speedHistory.removeFirst(speedHistory.count - speedHistoryLimit)
                }
            }
            totalDownload = current.rx
            totalUpload = current.tx
            activeInterfaceName = interface
        }
    }

    private func readInterfaceBytes() -> (bytes: (rx: Int64, tx: Int64)?, interface: String?) {        var interfaceName: String?
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

    /// 활성 인터페이스의 MAC 주소 ("bc:d0:74:22:a1:9f" 형식, 없으면 nil)
    func macAddress(forInterface name: String) -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let start = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr = start
        while true {
            let addr = ptr.pointee
            if String(cString: addr.ifa_name) == name,
               addr.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                let sdl = addr.ifa_addr.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) { $0.pointee }
                let mac = withUnsafeBytes(of: sdl.sdl_data) { raw -> [UInt8] in
                    let base = raw.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    let offset = Int(sdl.sdl_nlen)
                    return (0..<6).map { base[offset + $0] }
                }
                return mac.map { String(format: "%02x", $0) }.joined(separator: ":")
            }
            guard let next = addr.ifa_next else { break }
            ptr = next
        }
        return nil
    }
}
