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

    private var uploads: [Double] { history.map { $0.uploadBps / 8 } }
    private var downloads: [Double] { history.map { $0.downloadBps / 8 } }
    private var peak: Double { max(uploads.max() ?? 0, downloads.max() ?? 0, 1) * 1.15 }

    var body: some View {
        if history.count >= 2 {
            VStack(alignment: .leading, spacing: 2) {
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
}
