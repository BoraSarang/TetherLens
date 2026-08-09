import SwiftUI

// MARK: - TetherLens Design System (v0.23.0)
//
// 전역 UI 토큰. 하드코딩 값(폰트 크기/색상/간격/모서리/폭)을 여기로 모은다.
// - 폰트: semantic(동적 타입 대응) + 고정 스케일(밀집 UI용)
// - 색상: 시스템 색 래핑 (다크 모드 자동 대응), 의미론적 이름 사용

enum TLPalette {
    // 시맨틱 색상 (업로드/다운로드/상태)
    static let upload   = Color.orange                    // 업로드/핫스팟/경고
    static let download = Color.blue                      // 다운로드
    static let success  = Color.green                     // 복사 성공/핑 회복
    static let danger   = Color.red                       // 핑 임계/종료
    static let accent   = Color.accentColor               // 강조/링크

    // 텍스트/구분
    static let textPrimary   = Color.primary
    static let textSecondary = Color.secondary
    static let copyHint      = Color.secondary.opacity(0.4) // 복사 아이콘 단서
    static let separator     = Color(nsColor: .separatorColor)
    static let textBackground = Color(nsColor: .textBackgroundColor) // 요약 행 배경
    static let windowBackground = Color(nsColor: .windowBackgroundColor) // 확인 다이얼로그 배경
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
    static let inset: CGFloat = 16    // 팝오버 인셋
}

enum TLRound {
    static let small:  CGFloat = 6
    static let medium: CGFloat = 10
}

enum TLSize {
    // 시트/표준 폭 (현행 값 유지 — 값 변경은 회귀 위험으로 이번 버전에서 보류)
    static let popoverWidth:   CGFloat = 280
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
    static let sidebarWidth:      CGFloat = 88   // UsageReport 사이드바
    static let rowColNarrow:      CGFloat = 44   // 세션 수/짧은 값
    static let rowColTime:        CGFloat = 64   // 시간/기간 컬럼
    static let rowColWide:        CGFloat = 72   // 날짜/라벨 컬럼
    static let pickerWidth:       CGFloat = 200  // 프로필 피커
}
