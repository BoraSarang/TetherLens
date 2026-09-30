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
