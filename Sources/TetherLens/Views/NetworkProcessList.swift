import SwiftUI

/// 네트워크(process별) 사용량 리스트 — **팝오버 · 플로팅 창 공용 단일 진실원처**
///
/// ## 왜 공용 컴포넌트인가
///
/// v0.39 에서 팝오버의 프로세스 섹션을 "대시보드로 통합한다"는 명목으로 걷어냈다.
/// 그 판단이 틀렸던 이유는 **핵심 사용 시나리오를 놓쳤기 때문**이다.
///
/// > 대역폭이 왜 이렇게 나오지? → 지금 누가 쓰고 있지?
///
/// 이 질문은 팝오버를 열어 **즉시** 답해야 한다. 대시보드(⌘5)나 플로팅 창을 여는 건
/// 다른 행동을 요구하니 답이 늦고, 무엇보다 팝오버를 볼 수 없는 순간(메뉴바만 노출된 상태)
/// 에는 답을 얻을 방법이 아예 없었다.
///
/// 두 곳에 같은 코드를 따로 두면 배율 같은 표시 규칙이 또 어긋난다
/// (실제로 그랬다 — 대시보드는 구간 길이로 나눠 표시하고 플로팅은 나누지 않았다).
/// 그래서 표시 규칙을 여기 한곳에 모은다.
///
/// ## 배율 주의
///
/// `AppTraffic.bytesIn/bytesOut` 은 `nettop -l <n> -s 1` 이 관측한 **구간 전체 합계**다.
/// 실측 확인: `-l 5` 은 정확히 5초치(1초 델타 5블록)를 반환한다.
///
/// 이 값을 초당 포맷터에 그대로 넣으면 **구간 길이만큼 과대 표시**된다
/// (기본 10초 설정이면 10배). 반드시 실제 관측 구간으로 나눠야 한다.
struct NetworkProcessList: View {
    let apps: [TrafficMonitor.AppTraffic]
    /// `TrafficMonitor.windowSeconds` — 마지막 nettop 이 실제 관측한 구간
    let windowSeconds: Double
    /// 표시 개수
    var limit: Int = 3
    /// 시스템 프로세스 포함 여부
    var showSystem: Bool = false
    /// "더보기" 버튼 — nil 이면 숨긴다
    var onShowMore: (() -> Void)?
    /// 네트워크 측정 요청 — nettop 이 꺼져 있을 때 "프로세스 보기" 를 제공
    var onMeasure: (() -> Void)?
    /// 측정 중인지 (버튼 비활성 + 진행 표시)
    var isMeasuring: Bool = false
    /// 마지막 측정 시각 — 오래되면 "다시 측정" 을 안내한다
    var measuredAt: Date?

    private var visible: [TrafficMonitor.AppTraffic] {
        let base = showSystem ? apps : apps.filter { !SystemProcesses.set.contains($0.processName) }
        return Array(base.sorted { ($0.bytesIn + $0.bytesOut) > ($1.bytesIn + $1.bytesOut) }.prefix(limit))
    }

    /// 점유율 분모 — 표시 중인 행끼리만 비교한다 (숨긴 프로세스가 분모에 섞이면 안 된다)
    private var shareTotal: Double {
        Double(visible.reduce(Int64(0)) { $0 + $1.bytesIn + $1.bytesOut })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TLSpace.xs) {
            header

            if isMeasuring {
                measuringRow
            } else if visible.isEmpty {
                // 아무 프로세스도 트래픽이 없다 — 빈 상태가 정답이다.
                // 예전엔 여기서 22 MB/s 인 프로세스가 떠 있었다(첫 블록 누적값 버그).
                emptyRow
            } else {
                ForEach(visible) { app in
                    row(app)
                }
            }

            if let onMeasure, !isMeasuring {
                measureButton
            }

            if let onShowMore {
                Button(Localized.showMore, action: onShowMore)
                    .buttonStyle(.plain)
                    .font(TLFont.caption)
                    .foregroundColor(TLPalette.download)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    // MARK: - 상태 행

    /// nettop 을 켜지 않으면 평상시 프로세스 트래픽이 없다 — 이유를 밝히고 재게 한다
    private var emptyRow: some View {
        HStack(spacing: 6) {
            Text(Localized.noProcessTraffic)
                .font(TLFont.caption2)
                .foregroundColor(TLPalette.textSecondary)
            Spacer(minLength: 0)
            if onMeasure != nil {
                Button(Localized.measureNow, action: { onMeasure?() })
                    .buttonStyle(.plain)
                    .font(TLFont.caption)
                    .foregroundColor(TLPalette.download)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 18)
    }

    private var measureButton: some View {
        Button {
            onMeasure?()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "arrow.clockwise").font(TLFont.badge)
                Text(Localized.measureNow).font(TLFont.caption)
            }
            .foregroundColor(TLPalette.textSecondary)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var measuringRow: some View {
        HStack(spacing: 6) {
            ProgressView().controlSize(.mini)
            Text(Localized.measuringProcessList)
                .font(TLFont.caption2)
                .foregroundColor(TLPalette.textSecondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 18)
    }

    // MARK: - 헤더 (컬럼 라벨)

    private var header: some View {
        HStack(spacing: 4) {
            Text(Localized.process)
                .font(TLFont.smallBold)
                .foregroundColor(TLPalette.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(Localized.upload)
                .font(TLFont.smallBold)
                .foregroundColor(TLPalette.upload)
                .lineLimit(1)
                .frame(width: TLSize.trafficUploadCol, alignment: .trailing)
            Text(Localized.download)
                .font(TLFont.smallBold)
                .foregroundColor(TLPalette.download)
                .lineLimit(1)
                .frame(width: TLSize.trafficDownloadCol, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 행

    private func row(_ app: TrafficMonitor.AppTraffic) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                icon(app.processName)
                Text(app.processName)
                    .font(TLFont.medium)
                    .foregroundColor(TLPalette.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                // 구간 합계 → 초당률. 배율을 빼먹으면 구간 길이만큼 부풀어 보인다.
                Text(ByteRateFormat.windowRateString(app.bytesIn, windowSeconds: windowSeconds))
                    .font(TLFont.mediumMono)
                    .foregroundColor(TLPalette.upload)
                    .monospacedDigit()
                    .lineLimit(1)
                    .frame(width: TLSize.trafficUploadCol, alignment: .trailing)
                Text(ByteRateFormat.windowRateString(app.bytesOut, windowSeconds: windowSeconds))
                    .font(TLFont.mediumMono)
                    .foregroundColor(TLPalette.download)
                    .monospacedDigit()
                    .lineLimit(1)
                    .frame(width: TLSize.trafficDownloadCol, alignment: .trailing)
            }
            TLShareBar(ratio: TLShare.ratio(Double(app.bytesIn + app.bytesOut), of: shareTotal), color: TLPalette.download)
        }
        .padding(.vertical, 1)
        .contentShape(Rectangle())
    }

    private func icon(_ name: String) -> some View {
        Group {
            if let nsImage = AppIconResolver.icon(forProcess: name) {
                Image(nsImage: nsImage).resizable().scaledToFit()
            } else {
                Image(systemName: "app").foregroundColor(TLPalette.textSecondary)
            }
        }
        .frame(width: 14, height: 14)
    }
}
