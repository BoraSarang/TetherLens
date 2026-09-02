import SwiftUI

// MARK: - TetherLens Design System (v0.29.0)
//
// 전역 UI 토큰. 하드코딩 값(폰트 크기/색상/간격/모서리/폭)을 여기로 모은다.
// - 폰트: semantic(동적 타입 대응) + 고정 스케일(밀집 UI용)
// - 색상: Display P3 브랜드 팔레트 (OKLCH 설계 → P3 렌더, sRGB 자동 폴백)
//         + on-color 토큰 (배경 위 텍스트/아이콘용)

enum TLPalette {
    // ── 브랜드 시맨틱 색상 (Display P3, OKLCH로 균형 설계) ──
    // L≈0.55 수준에서 C/H를 달리해 서로 "형제"처럼 보이게 함
    static let upload   = Color(.displayP3, red: 0.902, green: 0.514, blue: 0.227) // 업로드/핫스팟/경고 (oklch 0.65 0.15 55)
    static let download = Color(.displayP3, red: 0.184, green: 0.490, blue: 0.871) // 다운로드 (oklch 0.55 0.18 250)
    static let success  = Color(.displayP3, red: 0.149, green: 0.651, blue: 0.318) // 복사 성공/핑 회복 (oklch 0.62 0.17 145)
    static let danger   = Color(.displayP3, red: 0.937, green: 0.255, blue: 0.263) // 핑 임계/종료 (oklch 0.58 0.22 25)
    static let accent   = Color.accentColor                                        // 강조/링크 (시스템 액센트 존중)

    // ── on-color (배경 위에 올라가는 텍스트/아이콘 — 다크/라이트 무관 고정) ──
    static let onUpload   = Color.white
    static let onDownload = Color.white
    static let onSuccess  = Color.white
    static let onDanger   = Color.white

    // 텍스트/구분
    static let textPrimary   = Color.primary
    static let textSecondary = Color.secondary
    static let copyHint      = Color.secondary.opacity(0.4) // 복사 아이콘 단서
    static let separator     = Color(nsColor: .separatorColor)
    static let textBackground = Color(nsColor: .textBackgroundColor) // 요약 행 배경
    static let windowBackground = Color(nsColor: .windowBackgroundColor) // 확인 다이얼로그 배경
    static let rowHover      = Color.primary.opacity(0.06)  // 리스트 행 hover (Mac 컨벤션)

    // 물질 (material) — macOS 표면. macOS 26(Tahoe)은 .glassEffect로 자동 승격
    static let popoverSurface = Color(nsColor: .underPageBackgroundColor)
}

enum TLFont {
    // 고정 스케일 (밀집 테이블 UI — 동적 타입 대신 고정)
    static let badge       = Font.system(size: 8)                       // 알림 배지
    static let badgeMono   = Font.system(size: 8, design: .monospaced)  // 배지 숫자
    static let small       = Font.system(size: 9)                       // 헬퍼/복사 아이콘
    static let smallBold   = Font.system(size: 9, weight: .bold)        // 테이블 헤더
    static let medium      = Font.system(size: 10)                      // 테이블 본문
    static let mediumMono  = Font.system(size: 10, design: .monospaced) // 테이블 숫자
    static let detail      = Font.system(size: 11, weight: .bold)       // detailRow 라벨/값

    // semantic 스케일
    static let caption     = Font.caption
    static let caption2    = Font.caption2
    static let callout     = Font.callout
    static let subheadline = Font.subheadline
    static let body        = Font.body
    static let headline    = Font.headline                             // 시트 제목
    static let speed       = Font.system(.title3, design: .monospaced) // 속도 값
}

enum TLSpace {
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 6
    static let md:  CGFloat = 8
    static let lg:  CGFloat = 10
    static let xl:  CGFloat = 12
    static let xxl: CGFloat = 16
    static let xxxl: CGFloat = 20
    static let inset: CGFloat = 20    // 팝오버 인셋
}

enum TLRound {
    static let small:  CGFloat = 6
    static let medium: CGFloat = 10
}

enum TLSize {
    // Window scene 크기 (v0.29 — 시트 → 별도 윈도우 전환)
    static let settingsWindow:   (w: CGFloat, h: CGFloat) = (580, 480)  // 설정 (Settings scene, Cmd-,)
    static let reportWindow:     (w: CGFloat, h: CGFloat) = (720, 660)  // 사용량 리포트 (NavigationSplitView 사이드바 포함)
    static let trafficWindow:    (w: CGFloat, h: CGFloat) = (520, 560)  // 앱 트래픽
    static let notificationsWindow: (w: CGFloat, h: CGFloat) = (400, 440) // 알림 목록
    static let aboutWindow:      (w: CGFloat, h: CGFloat) = (380, 420)  // 정보

    // 시트/표준 폭 (현행 값 유지 — 값 변경은 회귀 위험으로 이번 버전에서 보류)
    static let popoverWidth:   CGFloat = 320
    static let sheetCompact:   CGFloat = 280   // 팝오버/프로필/DNS/IP히스토리/알림
    static let sheetSaving:    CGFloat = 300   // 절약 모드
    static let sheetStandard:  CGFloat = 320   // 설정
    static let sheetTraffic:   CGFloat = 400   // 프로세스별 트래픽 (v0.27 가로 확장)
    static let sheetWide:      CGFloat = 640   // 사용량 리포트
    static let aboutSheet:     CGFloat = 240   // 정보 시트

    // 테이블 컬럼
    static let detailLabelWidth:  CGFloat = 96   // detailRow 라벨
    static let trafficUploadCol:  CGFloat = 62
    static let trafficDownloadCol: CGFloat = 68
    static let trafficFloatingUploadCol: CGFloat = 76
    static let trafficFloatingDownloadCol: CGFloat = 82
    static let trafficFloatingProcessCol: CGFloat = 110
    static let rowColNarrow:      CGFloat = 44   // 세션 수/짧은 값
    static let rowColTime:        CGFloat = 64   // 시간/기간 컬럼
    static let rowColWide:        CGFloat = 72   // 날짜/라벨 컬럼
    static let pickerWidth:       CGFloat = 200  // 프로필 피커
}
