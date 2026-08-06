# PLAN_v0.21.0_macos

> v0.20 배포 후 잔여 버그 수정 + 2차 반복 분석 계획
> 상태: 완료 (2026-08-06)

## 개요

v0.20.0 배포(commit `20eef7e`) 이후 사용자 요청으로 정밀 분석 → 1차 수정 → 2차 반복 분석 → 추가 수정 → 수동 테스트 문서화를 수행했다.

## 1차 분석·수정 (1차 탐색 에이전트 3종 병렬)

| 항목 | 수정 |
|------|------|
| PingMonitor | @MainActor 전환, `?? .infinity`(오프라인 감지), ResumeGate(이중 resume 가드+5s watchdog), @Sendable 오류 |
| ProfileEditorView | 할당량 파싱 실패 시 조용한 nil 해제 → quotaError 표시 |
| ProfileManager.recordUsage | 전역 lastCumulative* → 프로필별 cumulativeCounters (사용량 유실 방지) |
| MenuBarManager | Timer → scheduleTimer(.common), isMonitoring/debugPanelMonitor, handleSettingsChanged, 종료 시 stopMonitoring |
| 할당량 알림 | 하드코딩 한국어 → Localized, todayGB→totalGB 기준 |
| TrafficMonitor | .common 타이머, stop() 큐 통일, try! → do-catch |
| AppBlockManager | @MainActor + 메인 async 알림 |
| IPResolver | isRefreshing 가드 + timeout 10s |
| getIPForSession | 오버랩 조건 + desc 정렬 |
| mergeStaleIPLogs | GROUP BY + MIN/MAX 병합 |
| DataStore | v8 인덱스/session_id FK/DB 손상 복구 |

## 2차 분석·수정 (2차 탐색 에이전트 3종 병렬)

2차에서 **1차 수정의 회귀 3건 + 치명 버그 1건** 포함 신규 발견 → 수정:

| 심각도 | 항목 | 수정 |
|--------|------|------|
| High | addIPLog + v8 유니크 인덱스 충돌 → 크래시 | v8 유니크 인덱스 제거 (addIPLog는 1800s 경과 시 새 행 + mergeStaleIPLogs가 병합하는 기존 설계 유지) |
| High | v8 마이그레이션 실패 시 DB 전체 삭제 → 데이터 유실 | 손상 DB는 `.corrupt-{ts}` 백업 후 재생성 |
| High | SavingModeController `\\n` 리터럴 → hosts 차단 무효 | `\n` 개행으로 수정 |
| High | 온보딩 데드 코드 (Settings 씬 onAppear 절대 호출 안 됨) | AppDelegate가 첫 실행 시 온보딩 NSWindow 표시 + 위치 권한 요청 시점 이동 |
| Medium | handleSettingsChanged guard 역전 (`!isMonitoring`) | `guard isMonitoring`으로, TrafficMonitor 재시작 + updateMenuBarText 추가 |
| Medium | TrafficMonitor.stop() 마지막 300초 유실 (1차 회귀) | stop()에서 saveAccumulated() 호출 후 클리어 복원 |
| Medium | nettop 타임아웃 없음 → 큐 스레드 블로킹 | 15s watchdog terminate + launch try-catch |
| Medium | SSID 전환 시 마지막 사용량 미기록 | updateMenuBarText SSID 변경 블록에서 이전 프로필/세션으로 recordUsage flush |
| Medium | handleResignActive 미등록 | init observer 등록 |
| Medium | 할당량 의미론 이원화(오늘 vs 누적) | 잔여/게이지/알림/절약모드 전부 누적(totalGB) 기준 통일 |
| Medium | showTotalColumn/menuBarMode 기본값 모순 | showTotalColumn 기본 true |
| Medium | LocationManager 연속 위치 갱신 (배터리) | 첫 위치 획득 후 stop + 5분 타이머/저전력 반영 |
| Medium | PopoverView 미리보기 시스템 프로세스 노출 | SystemProcesses 필터 적용 |
| Low | PingMonitor watchdog 미취소/gatewayTask 미저장 | gatewayTask 프로퍼티 + stop 취소, interval 클램프, classifyLatency nil 폴백 |
| Low | HeatmapGridView legend 색상 불일치, "분/회" 하드코딩 | legend를 colorForMinutes 기반으로, Localized.string |
| Low | MenuBarView NSColor.white → 라이트 모드 가독성 | NSColor.labelColor |
| Low | DateFormatter 하드코딩 "HH:mm" | setLocalizedDateFormatFromTemplate |
| Low | exportData CSV 이스케이프 부재 | csvEscape + 프로필명 따옴표/콤마 대응 |
| Low | ProfileEditorView 빈 이름 저장 허용 | nameError + Localized.nameRequired |
| Low | MenuBarView col3 폭 한국어 기준 → 영어 클리핑 | 로케일별 최대 폭 문자열 사용 |

## 미수정 (문서화/보류)

- DebugPanel 하드코딩 문자열, QoSGauge 임계값 3중 중복, AppTrafficView 상태 비유지, SettingsView 폴링 저장 onDisappear, UsageReportView 불필요 appTraffic 로드, HeatmapGridView 키보드 접근성 — Low 우선순위로 후속 버전에서 진행

## 산출물

- `docs/tests/v0.21.0_macos.md` — 수동 테스트 방법/기대반응 (T-01~T-50)
- 테스트 검증: `swift build` 성공 (각 수정 단계마다 검증)

## 롤백 계획

- `git revert` + `swift build` + 배포 재빌드
- hosts 오염 시: `sudo sed -i '' '/# TetherLens SavingMode/,/# TetherLens SavingMode/d' /etc/hosts`
- 손상 DB: `.corrupt-*` 백업 파일에서 복구 시도 후 삭제
