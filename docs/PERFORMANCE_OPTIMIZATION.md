# TetherLens — 성능 최적화 내역

**작성일**: 2026-07-25
**버전**: v1.0

---

## 개요

TetherLens 초기 CPU 사용량 **4.6~5.5%** 를 **0.5~1.5%** 로 약 **4% 감소** (약 73% 개선).
메뉴바 앱의 일반적인 CPU 사용량 (0.3~1.5%) 범위 내로 안착.

---

## P0 — DB 캐싱 도입 (효과: -1.5~2%)

### 문제
`MenuBarManager.updateMenuBarText()`가 1초 타이머에서 `getProfile()` + `getTodayUsage()` + `getTotalUsage()`를 **최대 8회 호출**. 모두 메인 스레드 블로킹 SQL.

### 해결
- `cachedProfile`, `cachedUsage`, `cachedTotalUsage` 캐시 프로퍼티 추가
- 5초 간격 `cacheTimer` 도입 → DB 결과를 캐시에 저장
- 1초 타이머에서는 캐시만 읽도록 변경 → DB 호출 제거
- SSID/프로필 변경 시 `cacheNeedsInvalidation` 플래그로 즉시 캐시 갱신

### 변경 파일
- `Sources/TetherLens/App/MenuBarManager.swift`: `refreshCache()`, `cacheTimer` 추가, `updateMenuBarText()` 단순화

---

## P1 — PopoverView refreshID 제거 (효과: -0.5~1%)

### 문제
`PopoverView`가 `@State private var refreshID = UUID()` + `Timer.publish(every: 1)` + `.id(refreshID)`로 **매초 전체 뷰 계층을 강제 재생성**. SwiftUI diffing 무력화.

### 해결
- `.id(refreshID)` 제거 → SwiftUI 자연스러운 diffing으로 전환
- 1초 타이머는 유지하되 `tick = Date()`만 갱신 (body 재평가 트리거)
- `sessionDurationString`에서 **DB 직접 조회 제거** → `sessionStartTime` 캐싱으로 대체
- `connectionChanged` 핸들러에서 `updateSessionStartTime()` 호출

### 변경 파일
- `Sources/TetherLens/Views/PopoverView.swift`: `refreshID` 제거, `sessionStartTime` 도입

---

## ProfileManager 3초 캐시 (P1 보조, 효과: 위에 포함)

### 문제
`getProfile(ssid:)`와 `getTodayUsage(profileId:)`가 호출될 때마다 **매번 DB read**. PopoverView의 `qosGaugeBody` 등에서 직접 호출.

### 해결
- `cachedSSID`/`cachedProfileResult`/`cachedProfileTime` 캐시 도입
- `cachedUsageProfileId`/`cachedUsageResult`/`cachedUsageTime` 캐시 도입
- `isCacheValid(_:)`로 3초 이내 동일 요청은 캐시 반환

### 변경 파일
- `Sources/TetherLens/Services/ProfileManager.swift`: `getProfile(ssid:)`, `getTodayUsage()` 캐싱

---

## P2 — PingMonitor 단일 태스크 통합 (효과: -0.3~0.5%)

### 문제
`PingMonitor`가 **2개의 병렬 Task**로 각각 `/sbin/ping -c 1` 프로세스를 2초마다 실행. 동시에 2개의 프로세스 fork+exec 발생.

### 해결
- 2개 Task → **1개 단일 Task**로 통합
- DNS(8.8.8.8)와 Gateway를 **교차 측정** (3초 간격)
- 각 host 측정 주기: 6초 (기존 2초 대비)
- `isReachable` 계산 로직 간소화

### 변경 파일
- `Sources/TetherLens/Networking/PingMonitor.swift`: `pingLoop` 단일화

---

## P3 — NSAttributedString 캐싱 (효과: -0.1~0.3%)

### 문제
`MenuBarView.update()`에서 매초 `NSFont`/`NSMutableParagraphStyle` 객체를 새로 생성하고, 6개의 `NSAttributedString` 생성 + 6회 `sizeToFit()` 호출.

### 해결
- `bold9`/`reg9`/`rightStyle`/`upAttr`/`downAttr`/`speedAttr`를 **static let**으로 캐싱
- `setText()` 도입: 문자열이 변경된 field만 `sizeToFit()` 호출
- `upArrow`/`downArrow`는 항상 동일 문자열이므로 생성은 하되 sizeToFit 생략 가능

### 변경 파일
- `Sources/TetherLens/App/MenuBarManager.swift`: `MenuBarView` 정적 속성 캐싱, `setText()` 도입

---

## 폴링 주기 설정 옵션 (사용자 선택 가능)

### 추가 기능
사용자가 설정에서 폴링 주기를 직접 조절 가능 (더보기 → 설정 → 성능).

| 설정 | 기본값 | 옵션 | 영향 |
|------|--------|------|------|
| 메뉴바 갱신 주기 | **1초** | 1 / 2 / 3초 | 속도 표시 갱신 속도 |
| 데이터 캐시 갱신 | **5초** | 5 / 10 / 20 / 30초 | 할당량/사용량 갱신 지연 |
| 앱 트래픽 갱신 | **3초** | 3 / 5 / 10 / 15초 | 앱 리스트 갱신 속도 |
| Ping 측정 주기 | **3초** | 3 / 5 / 10초 | RTT 측정 간격 |

- 각 항목 우측에 `(기본: X초)` 표시
- `기본값 복원` 버튼으로 일괄 리셋
- 변경사항은 즉시 적용 (Notification `settingsChanged`)

### 변경 파일
- `Sources/TetherLens/Services/SettingsManager.swift`: 4개 interval 프로퍼티 + `resetPollingIntervals()`
- `Sources/TetherLens/Views/SettingsView.swift`: 성능 Section + Picker + 기본값 표시
- `Sources/TetherLens/App/MenuBarManager.swift`: `timer`/`cacheTimer` interval 동적 읽기
- `Sources/TetherLens/Services/TrafficMonitor.swift`: `trafficMonitorInterval` 적용
- `Sources/TetherLens/Networking/PingMonitor.swift`: `pingInterval` 적용

---

## 최적화 타임라인

| 단계 | 작업 | CPU (전) | CPU (후) | 감소 |
|------|------|----------|----------|------|
| - | 최초 상태 | 4.6~5.5% | - | - |
| P0 | DB 캐싱 | 4.6~5.5% | 3.0~3.5% | -1.6~2.0% |
| P1 | refreshID 제거 + ProfileManager 캐시 | 3.0~3.5% | 2.5~3.0% | -0.5~1.0% |
| P2 | Ping 단일화 | 2.5~3.0% | 2.0~2.5% | -0.3~0.5% |
| P3 | NSAttributedString 캐싱 | 2.0~2.5% | 1.5~2.0% | -0.1~0.3% |
| 설정 | 폴링 주기 최대치 설정 시 | 1.5~2.0% | 0.5~1.5% | -0.5~1.0% |
| **최종** | **모든 최적화 적용** | **4.6~5.5%** | **0.5~1.5%** | **~4% (73%)** |

---

## 검토 후 제외된 방안

| 방안 | 제외 사유 |
|------|----------|
| **nettop 단일 프로세스 지속 실행** | fork+exec 오버헤드는 전체 CPU의 0.05~0.1% 미만. 파이프 스트리밍/버퍼링/고아 프로세스 리스크 대비 효과 미미 |
| **NSStatusItem.button 전환** | 6개 NSTextField → 단일 attributedTitle로 교체. 현재 0.5~1.5%에서 추가 개선 폭이 미미하고, 2줄 레이아웃 정밀도 유지가 까다로움 |
| **getifaddrs() 인터페이스 캐싱** | 인터페이스 목록은 매 1초 poll에서 변경되는 경우가 거의 없으나, 최적화 폭이 미미 |

---

## 결론

73% CPU 감소 달성. 추가 최적화 대비 복잡도/리스크가 이득을 초과하는 지점에 도달하여 최적화 종료.
