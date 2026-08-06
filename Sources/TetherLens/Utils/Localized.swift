import Foundation

enum Localized {
  private static var isKorean: Bool {
    Locale.current.language.languageCode?.identifier == "ko"
  }

  // MARK: - General
  static var close: String { value(kr: "닫기", en: "Close") }
  static var cancel: String { value(kr: "취소", en: "Cancel") }
  static var save: String { value(kr: "저장", en: "Save") }
  static var delete: String { value(kr: "삭제", en: "Delete") }
  static var edit: String { value(kr: "편집", en: "Edit") }
  static var apply: String { value(kr: "적용", en: "Apply") }
  static var confirm: String { value(kr: "확인", en: "Confirm") }
  static var settings: String { value(kr: "설정", en: "Settings") }
  static var statistics: String { value(kr: "통계", en: "Statistics") }
  static var more: String { value(kr: "더보기", en: "More") }
  static var quit: String { value(kr: "종료", en: "Quit") }
  static var copied: String { value(kr: "복사되었습니다.", en: "Copied.") }

  // MARK: - Popover Summary/Detail
  static var summaryView: String { value(kr: "요약 보기", en: "Summary") }
  static var detailView: String { value(kr: "상세 보기", en: "Detail") }

  // MARK: - Connection
  static var noConnection: String { value(kr: "연결 없음", en: "No Connection") }
  static var iOSHotspot: String { value(kr: "iOS 핫스팟", en: "iOS Hotspot") }
  static var androidHotspot: String { value(kr: "Android 핫스팟", en: "Android Hotspot") }
  static var hotspot: String { value(kr: "핫스팟", en: "Hotspot") }
  static var wifi: String { value(kr: "Wi-Fi", en: "Wi-Fi") }
  static var ethernet: String { value(kr: "Ethernet", en: "Ethernet") }
  static var unknown: String { value(kr: "알 수 없음", en: "Unknown") }
  static var measuring: String { value(kr: "측정 중...", en: "Measuring...") }

  // MARK: - Section Headers
  static var connectionInfo: String { value(kr: "연결 정보", en: "Connection Info") }
  static var addressInfo: String { value(kr: "연결 주소", en: "Address Info") }
  static var qosGauge: String { value(kr: "QoS 방지 게이지", en: "QoS Gauge") }
  static var profile: String { value(kr: "프로필", en: "Profile") }
  static var appTraffic: String { value(kr: "프로세스별 트래픽", en: "App Traffic") }

  // MARK: - Connection Detail Labels
  static var type: String { value(kr: "유형", en: "Type") }
  static var session: String { value(kr: "세션", en: "Session") }
  static var network: String { value(kr: "네트워크", en: "Network") }
  static var standard: String { value(kr: "규격", en: "Standard") }
  static var channel: String { value(kr: "채널", en: "Channel") }
  static var speed: String { value(kr: "속도", en: "Speed") }
  static var gateway: String { value(kr: "게이트웨이", en: "Gateway") }
  static var localIP: String { value(kr: "로컬 IP", en: "Local IP") }
  static var externalIP: String { value(kr: "외부 IP", en: "External IP") }
  static var ping: String { value(kr: "지연 시간 (Ping)", en: "Latency (Ping)") }
  static var dns: String { value(kr: "DNS", en: "DNS") }
  static var bssid: String { value(kr: "BSSID", en: "BSSID") }

  // MARK: - Speed
  static var upload: String { value(kr: "▲ 업로드", en: "▲ Upload") }
  static var download: String { value(kr: "▼ 다운로드", en: "▼ Download") }
  static var total: String { value(kr: "합계", en: "Total") }
  static var dailyAverage: String { value(kr: "일 평균", en: "Daily Avg") }
  static var totalUsage: String { value(kr: "총 사용량", en: "Total Usage") }

  // MARK: - Pin / Notifications
  static var unpin: String { value(kr: "고정 해제", en: "Unpin") }
  static var pinPopover: String { value(kr: "팝오버 고정", en: "Pin Popover") }
  static var notificationHistory: String { value(kr: "알림 기록", en: "Notification History") }

  // MARK: - Profile
  static var profileManagement: String { value(kr: "프로필 관리", en: "Profile Management") }
  static var noProfiles: String { value(kr: "등록된 프로필이 없습니다", en: "No registered profiles") }
  static var connected: String { value(kr: "접속 중", en: "Connected") }
  static var quota: String { value(kr: "할당량", en: "Quota") }
  static var lastConnected: String { value(kr: "마지막 접속:", en: "Last connected:") }
  static var manageProfiles: String { value(kr: "프로필 관리...", en: "Manage Profiles...") }
  static var noQuota: String { value(kr: "할당량 없음 — 프로필 편집에서 설정하세요", en: "No quota — set in profile editor") }
  static var setQuota: String { value(kr: "할당량 설정", en: "Set Quota") }
  static var resetData: String { value(kr: "데이터 초기화", en: "Reset Data") }
  static var profileDeleteConfirm: String { value(kr: "통계 정보 등 모든 데이터가 삭제됩니다.", en: "All data including statistics will be deleted.") }
  static var profileResetConfirm: String { value(kr: "이 프로필의 모든 사용량 데이터가 삭제됩니다.\n프로필 자체는 유지됩니다.", en: "All usage data for this profile will be deleted.\nThe profile itself will be kept.") }

  // MARK: - Profile Editor
  static var profileEdit: String { value(kr: "프로필 편집", en: "Edit Profile") }
  static var nameLabel: String { value(kr: "이름:", en: "Name:") }
  static var ssidLabel: String { value(kr: "SSID:", en: "SSID:") }
  static var quotaLabel: String { value(kr: "할당량:", en: "Quota:") }
  static var quotaEnabled: String { value(kr: "사용", en: "Enabled") }
  static var quotaGB: String { value(kr: "GB:", en: "GB:") }
  static var quotaPlaceholder: String { value(kr: "예: 3.0", en: "e.g. 3.0") }
  static var quotaInvalid: String { value(kr: "할당량을 숫자로 입력하세요 (예: 3.0)", en: "Enter a valid quota number (e.g. 3.0)") }
  static var nameRequired: String { value(kr: "이름을 입력하세요", en: "Please enter a name") }
  static var namePlaceholder: String { value(kr: "이름", en: "Name") }

  // MARK: - DNS Preset
  static var dnsPresetPicker: String { value(kr: "DNS 프리셋 선택", en: "Select DNS Preset") }
  static var dnsApplying: String { value(kr: "적용 중...", en: "Applying...") }
  static var dnsApplied: String { value(kr: "적용됨", en: "Applied") }
  static var dnsChangeTitle: String { value(kr: "DNS 변경", en: "Change DNS") }
  static var dnsChangeMessage: String { value(kr: "%@(으)로 변경하시겠습니까?\n\n변경을 위해 관리자 비밀번호가 필요합니다.", en: "Change to %@?\n\nAdministrator password is required.") }
  static func dnsChangeMessage(_ name: String) -> String {
    String(format: dnsChangeMessage, name)
  }

  // MARK: - Location Warning
  static var locationServiceOff: String { value(kr: "시스템 설정 > 개인정보 보호 및 보안 >\n위치 서비스를 켜주세요", en: "System Settings > Privacy & Security >\nEnable Location Services") }
  static var locationAppDenied: String { value(kr: "시스템 설정 > 개인정보 보호 및 보안 >\n위치 서비스 > TetherLens를 허용해주세요", en: "System Settings > Privacy & Security >\nLocation Services > Allow TetherLens") }
  static var locationNeeded: String { value(kr: "TetherLens가 Wi-Fi 정보를 읽기 위해\n위치 접근 권한이 필요합니다", en: "TetherLens needs location access\nto read Wi-Fi information") }
  static var locationProvisioning: String { value(kr: "Wi-Fi 정보(SSID)를 읽을 수 없습니다.\nApple Developer 프로비저닝이 필요합니다", en: "Cannot read Wi-Fi (SSID) information.\nApple Developer provisioning required") }
  static var openSettings: String { value(kr: "설정 열기", en: "Open Settings") }
  static var requestPermission: String { value(kr: "권한 요청", en: "Request Permission") }

  // MARK: - App Traffic
  static var process: String { value(kr: "프로세스", en: "Process") }
  static var showMore: String { value(kr: "더보기...", en: "Show More...") }
  static var totalSum: String { value(kr: "총 합계", en: "Grand Total") }
  static var userSum: String { value(kr: "사용자 합계", en: "User Total") }
  static var systemSum: String { value(kr: "시스템 합계", en: "System Total") }
  static var sortBy: String { value(kr: "정렬", en: "Sort") }
  static var userProcesses: String { value(kr: "사용자 프로세스 (상위 10)", en: "User Processes (Top 10)") }
  static var systemProcesses: String { value(kr: "시스템 프로세스 (상위 10)", en: "System Processes (Top 10)") }
  static var sortTotal: String { value(kr: "전체 순", en: "By Total") }
  static var sortUpload: String { value(kr: "업로드 순", en: "By Upload") }
  static var sortDownload: String { value(kr: "다운로드 순", en: "By Download") }
  static var noTrafficData: String { value(kr: "트래픽 데이터가 없습니다", en: "No traffic data") }

  // MARK: - Bottom Buttons
  static var usageReport: String { value(kr: "사용량 리포트", en: "Usage Report") }
  static var appTrafficButton: String { value(kr: "프로세스별 트래픽", en: "App Traffic") }
  static var notificationList: String { value(kr: "알림 기록", en: "Notifications") }
    static var dnsPresetApply: String { value(kr: "DNS 프리셋", en: "DNS Preset") }
static var savingMode: String { value(kr: "절약 모드", en: "Saving Mode") }
    static var savingModeOn: String { value(kr: "절약 모드 켜짐", en: "Saving Mode On") }
    static var savingModeOff: String { value(kr: "절약 모드 꺼짐", en: "Saving Mode Off") }
    static var lowPowerMode: String { value(kr: "저전력 모드", en: "Low Power Mode") }
    static var lowPowerModeOn: String { value(kr: "절전 모드 켜짐", en: "Low Power Mode On") }
    static var lowPowerModeOff: String { value(kr: "절전 모드 꺼짐", en: "Low Power Mode Off") }
  static var checkUpdates: String { value(kr: "업데이트 확인", en: "Check for Updates") }
  static var about: String { value(kr: "정보", en: "About") }
  static var debugPanel: String { value(kr: "🐛 디버그 패널", en: "🐛 Debug Panel") }

  // MARK: - Settings
  static var showTotalInMenuBar: String { value(kr: "메뉴바에 총 사용량 표시", en: "Show Total in Menu Bar") }
  static var menuBarDisplayMode: String { value(kr: "메뉴바 표시 항목", en: "Menu Bar Display") }
  static var menuBarModeSpeedOnly: String { value(kr: "속도만", en: "Speed Only") }
  static var menuBarModeSpeedTotal: String { value(kr: "속도 + 사용량", en: "Speed + Usage") }
  static var menuBarModeSpeedSSID: String { value(kr: "속도 + SSID", en: "Speed + SSID") }
  static var showSSIDInMenuBar: String { value(kr: "메뉴바에 SSID 표시", en: "Show SSID in Menu Bar") }
  static var autoSwitchProfile: String { value(kr: "새 네트워크에 프로필 자동 등록", en: "Auto-Register Profile on New Network") }
  static var launchAtLogin: String { value(kr: "로그인 시 자동 실행", en: "Launch at Login") }
  static var menuBar: String { value(kr: "메뉴바", en: "Menu Bar") }
  static var fontSize: String { value(kr: "폰트 크기", en: "Font Size") }
  static var defaultParen: String { value(kr: "(기본: %dpt)", en: "(Default: %dpt)") }
  static func defaultParen(_ val: Int) -> String { String(format: defaultParen, val) }
  static var showAppTrafficLabel: String { value(kr: "프로세스별 트래픽 표시", en: "Show App Traffic") }
  static var show: String { value(kr: "표시", en: "Show") }
  static var hide: String { value(kr: "숨김", en: "Hide") }
  static var notifications: String { value(kr: "알림", en: "Notifications") }
  static var notificationAuthorized: String { value(kr: "✅ 허용됨", en: "✅ Allowed") }
  static var authorizeNotifications: String { value(kr: "알림 허용", en: "Allow Notifications") }
  static var permissions: String { value(kr: "권한", en: "Permissions") }
  static var locationPermission: String { value(kr: "위치", en: "Location") }
  static var denied: String { value(kr: "거부됨", en: "Denied") }
  static var notDetermined: String { value(kr: "미설정", en: "Not Determined") }
  static var quotaAlert: String { value(kr: "할당량 알림", en: "Quota Alert") }
  static var defaultDisabled: String { value(kr: "(기본: 사용 안 함)", en: "(Default: Disabled)") }
  static var latencyAlert: String { value(kr: "지연 시간 알림", en: "Latency Alert") }
  static var defaultShown: String { value(kr: "(기본: 표시)", en: "(Default: Shown)") }
  static var performance: String { value(kr: "성능", en: "Performance") }
  static var resetDefaults: String { value(kr: "기본값 복원", en: "Reset to Defaults") }
  static var menuBarRefresh: String { value(kr: "메뉴바 갱신 주기", en: "Menu Bar Refresh") }
  static var cacheRefresh: String { value(kr: "데이터 캐시 갱신", en: "Data Cache Refresh") }
  static var trafficRefresh: String { value(kr: "프로세스 트래픽 갱신", en: "App Traffic Refresh") }
  static var pingIntervalLabel: String { value(kr: "Ping 측정 주기", en: "Ping Interval") }
  static func intervalSec(_ val: Int) -> String { value(kr: "\(val)초", en: "\(val)s") }

  // MARK: - About
  static var version: String { value(kr: "버전 %@ (%@)", en: "Version %@ (%@)") }
  static func version(_ ver: String, _ build: String) -> String {
    String(format: version, ver, build)
  }
  static var appDescription: String { value(kr: "macOS 핫스팟/테더링 데이터 사용량 모니터", en: "macOS Hotspot & Tethering Data Monitor") }
  static var createdBy: String { value(kr: "제작", en: "Created by") }

  // MARK: - Saving Mode
  static var savingModeTitle: String { value(kr: "절약 모드", en: "Saving Mode") }
  static var enableSavingMode: String { value(kr: "절약 모드 활성화", en: "Enable Saving Mode") }
  static var savingModeDescription: String { value(kr: "QoS 색상 기준이 더 엄격해집니다", en: "QoS color thresholds become stricter") }
  static var autoActivate: String { value(kr: "자동 활성화", en: "Auto Activate") }
  static var autoActivateDescription: String { value(kr: "할당량 80% 도달 시 자동으로 켜집니다", en: "Auto-enables when quota reaches 80%") }
  static var systemControl: String { value(kr: "시스템 제어", en: "System Control") }
  static var stopSoftwareUpdates: String { value(kr: "소프트웨어 업데이트 중지", en: "Stop Software Updates") }
  static var stopTimeMachine: String { value(kr: "Time Machine 백업 중지", en: "Stop Time Machine Backups") }
  static var blockUpdateServers: String { value(kr: "업데이트 서버 차단 중", en: "Blocking Update Servers") }
  static var deactivateSavingMode: String { value(kr: "절약 모드 해제", en: "Deactivate Saving Mode") }
  static var controlDescription: String { value(kr: "관리자 비밀번호로 다음 항목을 제어합니다", en: "Controls the following with admin password:") }
  static var controlItem1: String { value(kr: "• 소프트웨어 업데이트 중지", en: "• Stop software updates") }
  static var controlItem2: String { value(kr: "• Time Machine 백업 중지", en: "• Stop Time Machine backups") }
  static var controlItem3: String { value(kr: "• 업데이트/설치 서버 차단", en: "• Block update/install servers") }
  static var applying: String { value(kr: "적용 중...", en: "Applying...") }
  static var deactivating: String { value(kr: "해제 중...", en: "Deactivating...") }
  static var activateSavingMode: String { value(kr: "절약 모드 적용", en: "Activate Saving Mode") }

  // MARK: - Usage Report
  static var usageReportTitle: String { value(kr: "사용량 리포트", en: "Usage Report") }
  static var export: String { value(kr: "내보내기", en: "Export") }
  static var exportCSV: String { value(kr: "CSV 내보내기", en: "Export CSV") }
  static var exportJSON: String { value(kr: "JSON 내보내기", en: "Export JSON") }
  static var exportDone: String { value(kr: "내보내기 완료", en: "Export complete") }
  static var exportFailed: String { value(kr: "내보내기 실패", en: "Export failed") }
  static var allProfiles: String { value(kr: "전체 프로필", en: "All Profiles") }
  static var noUsageData: String { value(kr: "사용량 데이터가 없습니다", en: "No usage data") }
  static var noSessionData: String { value(kr: "세션 데이터가 없습니다", en: "No session data") }
  static var day: String { value(kr: "1일", en: "1 Day") }
  static var week: String { value(kr: "7일", en: "7 Days") }
  static var month: String { value(kr: "30일", en: "30 Days") }
  static var halfYear: String { value(kr: "6개월", en: "6 Months") }
  static var year: String { value(kr: "1년", en: "1 Year") }
  static var chart: String { value(kr: "그래프", en: "Chart") }
  static var detail: String { value(kr: "상세", en: "Detail") }
  static var sessionTab: String { value(kr: "세션", en: "Session") }
  static var appTrafficTab: String { value(kr: "프로세스별 트래픽", en: "App Traffic") }
  static var date: String { value(kr: "날짜", en: "Date") }
  static var monthLabel: String { value(kr: "월", en: "Month") }
  static var startTime: String { value(kr: "시작 시간", en: "Start Time") }
  static var status: String { value(kr: "상태", en: "Status") }
  static var inProgress: String { value(kr: "진행 중", en: "In Progress") }
  static var time: String { value(kr: "시간", en: "Time") }
  static var sessionCount: String { value(kr: "세션", en: "Sessions") }
  static var uploadShort: String { value(kr: "▲ 업로드", en: "▲ Up") }
  static var downloadShort: String { value(kr: "▼ 다운로드", en: "▼ Dn") }

  // MARK: - Onboarding
  static var welcomeTitle: String { value(kr: "TetherLens에 오신 것을 환영합니다", en: "Welcome to TetherLens") }
  static var welcomeDescription: String { value(kr: "Wi-Fi 핫스팟 및 테더링 연결을 모니터링하고 데이터 사용량을 추적합니다.", en: "Monitor Wi-Fi hotspot and tethering connections, and track data usage.") }
  static var locationPermissionTitle: String { value(kr: "위치 권한", en: "Location Permission") }
  static var locationPermissionDescription: String { value(kr: "Wi-Fi 네트워크 이름(SSID)을 읽고 핫스팟 유형을 식별하는 데 필요합니다.", en: "Required to read Wi-Fi network names (SSID) and identify hotspot types.") }
  static var notificationPermissionTitle: String { value(kr: "알림 권한", en: "Notification Permission") }
  static var notificationPermissionDescription: String { value(kr: "할당량 초과 및 연결 상태 변경 시 알림을 받습니다.", en: "Receive alerts for quota exceeded and connection changes.") }
  static var getStarted: String { value(kr: "시작하기", en: "Get Started") }
  static var skip: String { value(kr: "건너뛰기", en: "Skip") }

  // MARK: - Heatmap
  static var heatmapTitle: String { value(kr: "시간대별 사용량", en: "Hourly Usage") }
  static var dailyHotspotTime: String { value(kr: "일별 WiFi 사용 현황", en: "Daily WiFi Usage") }
  static var peak: String { value(kr: "피크", en: "Peak") }
  static var mapView: String { value(kr: "지도", en: "Map") }
  static var gridView: String { value(kr: "히트맵", en: "Heatmap") }

  // MARK: - Session Timeline
  static var timelineTitle: String { value(kr: "세션 타임라인", en: "Session Timeline") }
  static var dataUsed: String { value(kr: "사용량", en: "Data Used") }

  // MARK: - Time Relative
  static var justNow: String { value(kr: "방금 전", en: "Just now") }
  static func minutesAgo(_ n: Int) -> String {
    value(kr: "\(n)분 전", en: "\(n) min ago")
  }
  static func hoursAgo(_ n: Int) -> String {
    value(kr: "\(n)시간 전", en: "\(n) hr ago")
  }
  static func daysAgo(_ n: Int) -> String {
    value(kr: "\(n)일 전", en: "\(n) day ago")
  }

  // MARK: - QoS Gauge
  static func usagePercent(_ used: String, _ total: String, _ pct: Int) -> String {
    value(kr: "\(used) / \(total) (\(pct)% 사용됨)", en: "\(used) / \(total) (\(pct)% used)")
  }
  static func remaining(_ val: String) -> String {
    value(kr: "\(val) 남음", en: "\(val) remaining")
  }

  // MARK: - Connection Detail
  static var connectionSpeed: String { value(kr: "연결 속도", en: "Link Speed") }
  static func channelLabel(_ ch: Int, _ mhz: Int) -> String {
    "\(ch) GHz, \(mhz) MHz"
  }
  static func hotspotWifi(_ type: String) -> String {
    value(kr: "Wi-Fi (\(type))", en: "Wi-Fi (\(type))")
  }

  // MARK: - App Traffic View
  static var trafficCollecting: String { value(kr: "트래픽 데이터를 수집 중입니다...", en: "Collecting traffic data...") }
  static var excludeSystem: String { value(kr: "시스템 프로세스 포함", en: "Include System Processes") }
  static var resetTraffic: String { value(kr: "초기화", en: "Reset") }
  static var block: String { value(kr: "차단", en: "Block") }
  static var blockingOn: String { value(kr: "차단 중", en: "Blocking") }
  static var blockedAppNotificationTitle: String { value(kr: "앱 트래픽 차단 감지", en: "App Traffic Blocked") }
  static var blockedAppNotificationBody: String { value(kr: "%@가 데이터를 사용하려고 합니다. 차단 목록에 있습니다.", en: "%@ is trying to use data but is on the block list.") }

  // MARK: - Notification List
  static var notificationListTitle: String { value(kr: "알림 기록", en: "Notifications") }
  static var clearAll: String { value(kr: "전체 지우기", en: "Clear All") }
  static var noNotifications: String { value(kr: "알림이 없습니다", en: "No notifications") }

  // MARK: - Misc
  static func copiedValue(_ val: String) -> String {
    value(kr: "\(val)가 복사되었습니다.", en: "\(val) copied.")
  }

  // MARK: - Picker Options
  static let menuBarIntervalOptions: [(String, Double)] = [
    (value(kr: "1초", en: "1s"), 1),
    (value(kr: "2초", en: "2s"), 2),
    (value(kr: "3초", en: "3s"), 3),
  ]
  static let cacheIntervalOptions: [(String, Double)] = [
    (value(kr: "5초", en: "5s"), 5),
    (value(kr: "10초", en: "10s"), 10),
    (value(kr: "20초", en: "20s"), 20),
    (value(kr: "30초", en: "30s"), 30),
  ]
  static let trafficIntervalOptions: [(String, Double)] = [
    (value(kr: "3초", en: "3s"), 3),
    (value(kr: "5초", en: "5s"), 5),
    (value(kr: "10초", en: "10s"), 10),
    (value(kr: "15초", en: "15s"), 15),
  ]
  static let pingIntervalOptions: [(String, Double)] = [
    (value(kr: "3초", en: "3s"), 3),
    (value(kr: "5초", en: "5s"), 5),
    (value(kr: "10초", en: "10s"), 10),
  ]
  static let thresholdOptions: [(String, Double)] = [
    (value(kr: "사용 안 함", en: "Disabled"), 1.0),
    ("50%", 0.5),
    ("80%", 0.8),
    ("90%", 0.9),
    ("95%", 0.95),
  ]

  // MARK: - DNS Preset Descriptions
  static var dnsGoogleDesc: String { value(kr: "가장 빠른 글로벌 DNS", en: "Fastest global DNS") }
  static var dnsCloudflareDesc: String { value(kr: "개인정보 보호 중심, 1.1.1.1", en: "Privacy-focused, 1.1.1.1") }
  static var dnsOpenDNSDesc: String { value(kr: "유해 사이트 차단 기능", en: "Block harmful sites") }
  static var dnsQuad9Desc: String { value(kr: "악성 사이트 차단, 9.9.9.9", en: "Malware blocking, 9.9.9.9") }
  static var dnsCustomName: String { value(kr: "사용자 설정", en: "Custom") }
  static var dnsCustomDesc: String { value(kr: "직접 DNS 주소 입력", en: "Enter DNS addresses manually") }

  // MARK: - Saving Mode Controller
  static var savingModeActivated: String { value(kr: "절약 모드가 적용되었습니다", en: "Saving mode activated") }
  static var savingModeDeactivated: String { value(kr: "절약 모드가 해제되었습니다", en: "Saving mode deactivated") }
  static var permissionRequired: String { value(kr: "권한이 필요합니다", en: "Permission required") }

  // MARK: - Quota & Notification Alerts
  static func quotaReached(_ pct: Int, _ used: String, _ total: String) -> String {
    value(kr: "할당량 \(pct)% 도달 — \(used) / \(total)", en: "Quota \(pct)% reached — \(used) / \(total)")
  }
  static func quotaExceeded(_ used: String, _ total: String) -> String {
    value(kr: "할당량 초과 — \(used) / \(total)", en: "Quota exceeded — \(used) / \(total)")
  }
  static var dataQuotaExceeded: String { value(kr: "데이터 할당량 초과", en: "Data Quota Exceeded") }
  static func dataQuotaBody(_ used: String, _ total: String) -> String {
    value(kr: "\(used) / \(total)GB 사용", en: "\(used) / \(total)GB used")
  }
  static func quotaPercentBody(_ used: String, _ total: String, _ pct: Int) -> String {
    value(kr: "\(used) / \(total)GB 사용 (\(pct)%)", en: "\(used) / \(total)GB used (\(pct)%)")
  }
  static func quotaPercentTitle(_ pct: Int) -> String {
    value(kr: "데이터 할당량 \(pct)% 도달", en: "Data Quota \(pct)% Reached")
  }

  // MARK: - Ping Monitor Notifications
  static var pingRecoveryTitle: String { value(kr: "🟢 인터넷 연결이 다시 원활해졌습니다", en: "🟢 Internet connection restored") }
  static var pingRecoveryBody: String { value(kr: "지연 시간이 정상 범위(100ms 이하)로 회복되었습니다. 모든 서비스를 정상적으로 이용하실 수 있습니다.", en: "Latency recovered to normal range (under 100ms). All services should work normally.") }
  static var pingCriticalTitle: String { value(kr: "🔴 인터넷 연결 상태 매우 위험", en: "🔴 Internet connection critical") }
  static func pingCriticalBody(_ ms: Int) -> String {
    value(kr: "데이터 QoS(속도 제한) 구역이거나 셀룰러 신호가 매우 약합니다. 메신저/텍스트 외의 서비스 이용이 어렵습니다. (\(ms)ms)\n💡 팁: 통신사 데이터 잔여량을 확인하거나 핫스팟을 재연결해 보세요.", en: "Data QoS or weak cellular signal. Messenger/text only. (\(ms)ms)\n💡 Tip: Check data balance or reconnect hotspot.")
  }
  static var pingUnstableTitle: String { value(kr: "🔴 핫스팟 기기와의 연결이 불안정합니다", en: "🔴 Hotspot connection unstable") }
  static func pingUnstableBody(_ ms: Int) -> String {
    value(kr: "스마트폰과의 거리가 멀거나 주변 Wi-Fi 간섭이 심합니다. (\(ms)ms)\n💡 팁: 스마트폰 가까이 이동하거나, 핫스팟 설정을 5GHz 대역으로 변경해 보세요.", en: "Distance or Wi-Fi interference. (\(ms)ms)\n💡 Tip: Move closer to phone or switch to 5GHz.")
  }
  static var pingWarningTitle: String { value(kr: "🟡 핫스팟 반응 속도가 느려졌습니다", en: "🟡 Hotspot response slowing") }
  static func pingWarningBody(_ ms: Int) -> String {
    value(kr: "데이터 속도 제한(QoS) 또는 신호 약화가 의심됩니다. 고화질 영상이나 실시간 게임 시 끊김이 발생할 수 있습니다. (\(ms)ms)\n💡 팁: 핫스팟 스마트폰을 창가 쪽으로 옮겨보세요.", en: "Possible QoS throttling or weak signal. HD video/gaming may lag. (\(ms)ms)\n💡 Tip: Move hotspot phone near a window.")
  }
  static var connectionRestored: String { value(kr: "네트워크 연결이 복구되었습니다", en: "Network connection restored") }
  static var connectionLost: String { value(kr: "네트워크 연결이 끊어졌습니다", en: "Network connection lost") }

  // MARK: - Heatmap labels
  static let dayLabels: [String] = [
    value(kr: "일", en: "Sun"),
    value(kr: "월", en: "Mon"),
    value(kr: "화", en: "Tue"),
    value(kr: "수", en: "Wed"),
    value(kr: "목", en: "Thu"),
    value(kr: "금", en: "Fri"),
    value(kr: "토", en: "Sat"),
  ]
  static let hourLabel: String = value(kr: "시", en: "")

  // MARK: - Helper
  // MARK: - IP History
  static var ipHistory: String { value(kr: "IP 변경 이력", en: "IP History") }
  static var noIPHistory: String { value(kr: "IP 변경 이력이 없습니다", en: "No IP history") }
  static func firstSeen(_ date: String) -> String { value(kr: "첫 발견: \(date)", en: "First seen: \(date)") }
  static func lastSeen(_ date: String) -> String { value(kr: "마지막: \(date)", en: "Last seen: \(date)") }

  static func value(kr: String, en: String) -> String {
    isKorean ? kr : en
  }
  static func string(_ ko: String, _ en: String) -> String {
    isKorean ? ko : en
  }
}
