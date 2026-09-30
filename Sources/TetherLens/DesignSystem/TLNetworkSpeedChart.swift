import SwiftUI
import Charts

/// 메뉴바 팝오버/플로팅 공용 업·다운 오버레이 차트.
/// 다운로드 Area + 업로드 Line, 공유 Y축, series 구분 필수 (병합 방지).
struct TLNetworkSpeedChart: View {
    let history: [NetworkMonitor.SpeedSample]
    /// NetworkMonitor 단위: bit/s
    var uploadBitRate: Double = 0
    var downloadBitRate: Double = 0
    var height: CGFloat = 88
    /// 범례 행(색 점 + 라벨 + 값) 표시 여부 — 기본 `false`.
    ///
    /// 호출부가 바로 위에 히어로 행(큰 숫자 + 색 점 + 라벨)을 두면 차트 안에서
    /// 같은 라벨과 같은 값을 또 반복하게 된다. 플로팅 창·팝오버·대시보드 ① 카드가
    /// 모두 이 구조라 기본을 꺼 둔다. 히어로 없이 차트만 단독으로 쓸 때만 `true`.
    var showsLegend: Bool = false

    private var uploads: [Double] { history.map { $0.uploadBps / 8 } }
    private var downloads: [Double] { history.map { $0.downloadBps / 8 } }
    private var peak: Double { max(uploads.max() ?? 0, downloads.max() ?? 0, 1) * 1.15 }

    var body: some View {
        if history.count >= 2 {
            VStack(alignment: .leading, spacing: 2) {
                if showsLegend {
                    legendRow
                }
                Chart {
                    ForEach(Array(downloads.enumerated()), id: \.offset) { idx, v in
                        AreaMark(
                            x: .value("t", idx),
                            y: .value("v", v),
                            series: .value("방향", "다운")
                        )
                        .foregroundStyle(TLPalette.download.opacity(0.30))
                        .interpolationMethod(.catmullRom)
                    }
                    ForEach(Array(uploads.enumerated()), id: \.offset) { idx, v in
                        LineMark(
                            x: .value("t", idx),
                            y: .value("v", v),
                            series: .value("방향", "업")
                        )
                        .foregroundStyle(TLPalette.upload)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: 0...peak)
                .frame(height: height)
            }
        } else {
            Text(Localized.measuring)
                .font(TLFont.caption)
                .foregroundColor(TLPalette.textSecondary)
                .frame(maxWidth: .infinity, minHeight: height, alignment: .center)
        }
    }

    /// 차트 위 범례 — 히어로 행이 없을 때만 쓴다 (호출부가 이미 보여주면 중복)
    private var legendRow: some View {
        HStack(spacing: TLSpace.md) {
            HStack(spacing: 4) {
                Circle().fill(TLPalette.upload).frame(width: 6, height: 6)
                Text(Localized.uploadShort)
                    .font(TLFont.caption)
                    .foregroundColor(TLPalette.textSecondary)
                Text(Self.formatBitRate(uploadBitRate))
                    .font(TLFont.caption.monospacedDigit())
                    .foregroundColor(TLPalette.upload)
            }
            Spacer()
            HStack(spacing: 4) {
                Text(Self.formatBitRate(downloadBitRate))
                    .font(TLFont.caption.monospacedDigit())
                    .foregroundColor(TLPalette.download)
                Text(Localized.downloadShort)
                    .font(TLFont.caption)
                    .foregroundColor(TLPalette.textSecondary)
                Circle().fill(TLPalette.download).frame(width: 6, height: 6)
            }
        }
    }

    static func formatBitRate(_ bitsPerSecond: Double) -> String {
        let bytes = Int64(bitsPerSecond / 8)
        return ByteRateFormat.string(bytes)
    }
}

/// 네트워크 업/다운 속도 문자열 (B/s 기준).
enum ByteRateFormat {
    static func string(_ bytesPerSecond: Int64) -> String {
        let bps = Double(bytesPerSecond)
        if bps >= 1_000_000_000 {
            return String(format: "%.1f GB/s", bps / 1_000_000_000)
        } else if bps >= 1_000_000 {
            return String(format: "%.1f MB/s", bps / 1_000_000)
        } else if bps >= 1_000 {
            return String(format: "%.1f KB/s", bps / 1_000)
        } else {
            return String(format: "%.0f B/s", bps)
        }
    }

    /// **구간 합계 → 초당률** 변환값 (B/s).
    ///
    /// `TrafficMonitor.AppTraffic.bytesIn/bytesOut` 은 `nettop -l <n>` 이 관측한
    /// **구간 전체 합계**다. 이 값을 `string(_:)` 에 그대로 넣으면 구간 길이만큼
    /// 과대 표시된다(기본 10초 설정이면 10배).
    ///
    /// 구간 길이는 설정값이 아니라 `TrafficMonitor.windowSeconds`(실제 경과 시간)를 써야 한다 —
    /// 워치독이 nettop 을 일찍 끊었을 때 배율이 어긋나지 않는다.
    static func windowRate(_ windowBytes: Int64, windowSeconds: Double) -> Double {
        guard windowBytes > 0, windowSeconds > 0 else { return 0 }
        return Double(windowBytes) / windowSeconds
    }

    /// 구간 합계를 초당률 문자열로 (예: 19.1 MB → 10초 구간이면 "1.9 MB/s")
    static func windowRateString(_ windowBytes: Int64, windowSeconds: Double) -> String {
        string(Int64(windowRate(windowBytes, windowSeconds: windowSeconds).rounded()))
    }
}
