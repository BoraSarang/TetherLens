import Testing
import Foundation
@testable import TetherLens

/// v0.38.3 앱별 트래픽 파서 — `nettop -P -J bytes_in,bytes_out -x -d -l N -s 1` 출력 파싱
///
/// 실제 형식(로컬 실측): `time` 헤더가 블록마다 반복되고, 데이터 줄은
/// `HH:MM:SS.ffffff  process.pid  bytes_in  bytes_out` 이다.
/// `-d` 델타 모드라 첫 블록은 기준점(모두 0)이고 이후 블록이 1초 구간별 델타다.
///
/// 기존 구현은 마지막 블록만 반환해 그 이전 구간을 통째로 버렸다.
@Suite struct TrafficParseTests {

    /// 다중 블록 합산 — 기준점 블록(0) + 실측 블록
    @Test func 다중블록_전체합산() {
        let output = """
        time    process           bytes_in  bytes_out
        18:52:06.986492 launchd.1       0    0
        18:52:06.986503 Safari.56896     0    0
        time    process           bytes_in  bytes_out
        18:52:07.992374 launchd.1      10   20
        18:52:07.992503 Safari.56896  3000  4000
        """
        let rows = TrafficMonitor.parse(output)
        let launchd = rows.first { $0.name == "launchd" }
        #expect(launchd?.bytesIn == 20)      // bytes_out 합
        #expect(launchd?.bytesOut == 10)     // bytes_in  합
        let safari = rows.first { $0.name == "Safari" }
        #expect(safari?.bytesIn == 4000)
        #expect(safari?.bytesOut == 3000)
    }

    /// 업로드/다운로드 슬롯 대응이 유지되어야 한다 (UI는 bytesIn을 업로드 색상으로 표시)
    @Test func 업다운슬롯대응_유지() {
        let output = """
        time    process           bytes_in  bytes_out
        18:52:06.986502 adb.3139    6294493696  898618687
        """
        let rows = TrafficMonitor.parse(output)
        #expect(rows.count == 1)
        #expect(rows.first?.name == "adb")
        #expect(rows.first?.bytesIn == 898_618_687)   // nettop bytes_out → 업로드 슬롯
        #expect(rows.first?.bytesOut == 6_294_493_696) // nettop bytes_in  → 다운로드 슬롯
    }

    /// 헤더 줄만 있으면 빈 결과
    @Test func 헤더줄만_빈결과() {
        let output = """
        time    process           bytes_in  bytes_out
        time    process           bytes_in  bytes_out
        """
        #expect(TrafficMonitor.parse(output).isEmpty)
    }

    /// 프로세스명에 점이 있어도 마지막 성분(PID)만 제거한다 (실측 com.apple.WebKi.56856 형태)
    @Test func 점포함_프로세스명_PID만제거() {
        let output = """
        time    process           bytes_in  bytes_out
        18:52:06.986503 com.apple.WebKi.56856   6781   8622
        """
        #expect(TrafficMonitor.parse(output).first?.name == "com.apple.WebKi")
    }

    /// 공백이 포함된 프로세스명도 유지된다 (실측 "OpenCode Helper.56898" 형태)
    @Test func 공백포함_프로세스명_유지() {
        let output = """
        time    process           bytes_in  bytes_out
        18:52:06.986504 OpenCode Helper.56898   18238442   7280
        """
        #expect(TrafficMonitor.parse(output).first?.name == "OpenCode Helper")
    }

    /// 컬럼 수가 부족한 줄은 건너뛴다 (크래시 없음)
    @Test func 열부족줄_건너뛰기() {
        let output = """
        time    process           bytes_in  bytes_out
        18:52:07.992374 broken
        18:52:08.992374 good.1      1        2
        """
        let rows = TrafficMonitor.parse(output)
        #expect(rows.count == 1)
        #expect(rows.first?.name == "good")
    }

    /// 빈 출력이면 빈 결과 (크래시 없음)
    @Test func 빈출력_빈결과() {
        #expect(TrafficMonitor.parse("").isEmpty)
    }
}

/// 구간 합계 → 초당률 환산 (v0.39 T-2ds)
///
/// `AppTraffic.bytesIn/bytesOut` 은 `nettop -l <n>` 이 관측한 **구간 전체 합계**다.
/// 이 값을 초당 포맷터에 그대로 넣으면 구간 길이만큼 과대 표시된다
/// (기본 10초 설정이면 10배). 플로팅 창과 앱 트래픽 창이 이 잘못을 공유하고 있었다.
@Suite struct WindowRateTests {

    // MARK: - 배율

    @Test func 구간합계를_구간길이로_나누면_초당률이된다() {
        // 10초 동안 20 MB 를 보냈다면 초당 2 MB
        #expect(ByteRateFormat.windowRate(20_000_000, windowSeconds: 10) == 2_000_000)
        #expect(ByteRateFormat.windowRate(1_000_000, windowSeconds: 10) == 100_000)
    }

    @Test func 구간길이가_배율을_결정한다() {
        let bytes: Int64 = 20_000_000
        #expect(ByteRateFormat.windowRate(bytes, windowSeconds: 2) == 10_000_000)
        #expect(ByteRateFormat.windowRate(bytes, windowSeconds: 5) == 4_000_000)
        #expect(abs(ByteRateFormat.windowRate(bytes, windowSeconds: 30) - 666_666.666) < 1)
    }

    /// 회귀: 예전 표시처럼 구간 합계를 "/s" 로 붙이면 구간 길이만큼 부풀었다
    @Test func 구간을_나누지_않으면_기본설정에서_10배_과대다() {
        let bytes: Int64 = 20_000_000
        #expect(ByteRateFormat.string(bytes) == "20.0 MB/s")
        #expect(ByteRateFormat.windowRateString(bytes, windowSeconds: 10) == "2.0 MB/s")
    }

    // MARK: - 경계

    @Test func 값이_없으면_0이다() {
        #expect(ByteRateFormat.windowRate(0, windowSeconds: 10) == 0)
        #expect(ByteRateFormat.windowRate(-1, windowSeconds: 10) == 0)
    }

    /// 워치독이 nettop 을 일찍 끊으면 구간이 0 에 가까워진다 — 0 으로 나누면 무한대가 된다
    @Test func 구간길이가_0이면_나눗셈_폭발을_막는다() {
        #expect(ByteRateFormat.windowRate(1_000, windowSeconds: 0) == 0)
        #expect(ByteRateFormat.windowRate(1_000, windowSeconds: -5) == 0)
    }

    @Test func 실수_결과는_정수_바이트로_반올림된다() {
        // 1 바이트 / 3초 = 0.333 B/s → 0 B/s 로 표기되어야 "0.3 B/s" 가 되지 않는다
        #expect(ByteRateFormat.windowRateString(1, windowSeconds: 3) == "0 B/s")
        #expect(ByteRateFormat.windowRateString(10, windowSeconds: 3) == "3 B/s")
    }

    // MARK: - 문자열 포맷

    @Test func 초당률_문자열은_단위를_넘긴다() {
        #expect(ByteRateFormat.windowRateString(1_500, windowSeconds: 1) == "1.5 KB/s")
        #expect(ByteRateFormat.windowRateString(1_500_000_000, windowSeconds: 1) == "1.5 GB/s")
        #expect(ByteRateFormat.windowRateString(999, windowSeconds: 1) == "999 B/s")
    }

    /// 2초 옵션이 실제로 선택지에 있는지 — 기본값은 배터리 때문에 10초를 유지한다
    @Test func 트래픽_갱신_간격_옵션에_2초가_있다() {
        #expect(Localized.trafficIntervalOptions.map(\.1).contains(2))
        #expect(SettingsManager.defaultTrafficMonitorInterval == 10.0)
    }
}
