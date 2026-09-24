import Foundation
import SystemConfiguration
import Combine

/// 네트워크 인터페이스 속도·히스토리. 팝오버/플로팅이 같은 인스턴스를 관찰한다.
/// @Published 갱신은 메인 디스패치에서만 수행. (v0.38.1) 5필드 → 단일 스냅샷 발행.
final class NetworkMonitor: ObservableObject, @unchecked Sendable {
    static let shared = NetworkMonitor()

    private var timer: DispatchSourceTimer?
    private var previousBytes: (rx: Int64, tx: Int64) = (0, 0)
    private var lastPollDate = Date.distantPast

    /// 초 단위 속도 히스토리 (사용 기록 차트용, 최신 120샘플 링버퍼)
    struct SpeedSample: Equatable {
        let downloadBps: Double
        let uploadBps: Double
    }

    struct Snapshot: Equatable {
        var currentUploadSpeed: Double = 0
        var currentDownloadSpeed: Double = 0
        var totalUpload: Int64 = 0
        var totalDownload: Int64 = 0
        var activeInterfaceName: String?
        var speedHistory: [SpeedSample] = []
    }

    @Published private(set) var snapshot = Snapshot()

    var currentUploadSpeed: Double { snapshot.currentUploadSpeed }
    var currentDownloadSpeed: Double { snapshot.currentDownloadSpeed }
    var totalUpload: Int64 { snapshot.totalUpload }
    var totalDownload: Int64 { snapshot.totalDownload }
    var activeInterfaceName: String? { snapshot.activeInterfaceName }
    var speedHistory: [SpeedSample] { snapshot.speedHistory }

    private let speedHistoryLimit = 120

    func start() {
        stop() // 중복 start로 타이머 누수 방지 (v0.38.0 멱등)
        previousBytes = (0, 0)
        lastPollDate = Date.distantPast
        let queue = DispatchQueue(label: "com.tetherlens.network-monitor", qos: .utility)
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now(), repeating: 1.0, leeway: .milliseconds(100))
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
            var next = self.snapshot
            if prev.rx > 0 {
                next.currentDownloadSpeed = rxSpeed
                next.currentUploadSpeed = txSpeed
                next.speedHistory.append(SpeedSample(downloadBps: rxSpeed, uploadBps: txSpeed))
                if next.speedHistory.count > self.speedHistoryLimit {
                    next.speedHistory.removeFirst(next.speedHistory.count - self.speedHistoryLimit)
                }
            }
            next.totalDownload = current.rx
            next.totalUpload = current.tx
            next.activeInterfaceName = interface
            self.snapshot = next // 단일 objectWillChange (v0.38.1)
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

            if let sa = addr.ifa_addr, sa.pointee.sa_family == UInt8(AF_LINK) {
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
            guard let sa = addr.ifa_addr else {
                guard let next = addr.ifa_next else { break }
                ptr = next
                continue
            }
            if String(cString: addr.ifa_name) == name,
               sa.pointee.sa_family == UInt8(AF_LINK) {
                let sdl = sa.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) { $0.pointee }
                let mac = withUnsafeBytes(of: sdl.sdl_data) { raw -> [UInt8] in
                    guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return [] }
                    let offset = Int(sdl.sdl_nlen)
                    guard offset + 6 <= raw.count else { return [] }
                    return (0..<6).map { base[offset + $0] }
                }
                guard mac.count == 6 else { continue }
                return mac.map { String(format: "%02x", $0) }.joined(separator: ":")
            }
            guard let next = addr.ifa_next else { break }
            ptr = next
        }
        return nil
    }
}
