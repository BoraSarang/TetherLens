import Testing
import Foundation
@testable import TetherLens

/// v0.35 속도 테스트 — Mbps 산출 순수 함수 (실망 호출은 수동 검증)
@Suite struct SpeedTestTests {

    @Test func mbps_10MB_8초는_10Mbps() {
        #expect(NetworkDiagnostics.megabitsPerSecond(bytes: 10_000_000, elapsed: 8) == 10.0)
    }

    @Test func mbps_1MB_1초는_8Mbps() {
        #expect(NetworkDiagnostics.megabitsPerSecond(bytes: 1_000_000, elapsed: 1) == 8.0)
    }

    @Test func mbps_0바이트는_nil() {
        #expect(NetworkDiagnostics.megabitsPerSecond(bytes: 0, elapsed: 5) == nil)
    }

    @Test func mbps_0초는_nil() {
        #expect(NetworkDiagnostics.megabitsPerSecond(bytes: 1000, elapsed: 0) == nil)
    }

    @Test func 속도측정_상수_정합() {
        #expect(NetworkDiagnostics.speedTestTimeout == 30)
        #expect(NetworkDiagnostics.speedTestDownBytes == 10_000_000)
        #expect(NetworkDiagnostics.speedTestUpBytes == 5_000_000)
    }
}

/// v0.38.3 프록시 진단 — `scutil --proxy` 파서
/// 실제 출력은 따옴표가 없는 `HTTPEnable : 1` 형식이다.
/// 이전 구현은 `line.contains("\"")` 로 걸러 모든 줄을 버려 프록시가 있어도 항상 '비활성'을 반환했다.
@Suite struct ProxyParseTests {

    /// macOS 14 실측 출력 (프록시 없음)
    @Test func 프록시없음_비활성으로파싱() {
        let raw = """
        <dictionary> {
          ExceptionsList : <array> {
            0 : *.local
            1 : 169.254/16
          }
          FTPPassive : 1
        }
        """
        let (enables, servers) = NetworkDiagnostics.parseProxyOutput(raw)
        #expect(enables.isEmpty)
        #expect(servers.isEmpty)   // 배열 인덱스·FTPPassive는 서버로 오인하지 않는다
    }

    /// 사내망 표준 출력 (HTTP 프록시 활성)
    @Test func HTTP프록시_활성으로파싱() {
        let raw = """
        <dictionary> {
          ExceptionsList : <array> {
            0 : *.local
          }
          FTPPassive : 1
          HTTPEnable : 1
          HTTPPort : 8080
          HTTPProxy : proxy.local
          HTTPSEnable : 1
          HTTPSPort : 8443
          HTTPSProxy : proxy.local
          SOCKSEnable : 0
        }
        """
        let (enables, servers) = NetworkDiagnostics.parseProxyOutput(raw)
        #expect(Set(enables) == ["HTTP", "HTTPS"])
        #expect(!enables.contains("SOCKS"))
        #expect(servers.contains("HTTPProxy=proxy.local"))
        #expect(servers.contains("HTTPPort=8080"))
    }

    /// Enable이 0이면 활성으로 잡지 않는다
    @Test func Enable0은_비활성으로판정() {
        let raw = """
        <dictionary> {
          SOCKSEnable : 0
          SOCKSProxy : 127.0.0.1
          SOCKSPort : 1080
        }
        """
        let (enables, servers) = NetworkDiagnostics.parseProxyOutput(raw)
        #expect(enables.isEmpty)
        #expect(servers.isEmpty)
    }

    /// PAC(PROXY autoconfig) 설정도 활성 프록시로 잡아야 한다
    @Test func PAC설정_활성으로파싱() {
        let raw = """
        <dictionary> {
          FTPPassive : 1
          HTTPEnable : 0
          ProxyAutoConfigEnable : 1
          ProxyAutoConfigURLString : http://wpad.example.com/wpad.dat
        }
        """
        let (enables, servers) = NetworkDiagnostics.parseProxyOutput(raw)
        #expect(enables == ["ProxyAutoConfig"])
        #expect(servers.isEmpty)
    }
}
