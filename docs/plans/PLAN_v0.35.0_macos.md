# PLAN v0.35.0 — 속도 테스트 + 연결 유지 (macOS)

- **버전**: v0.35.0 (build 35)
- **플랫폼**: [macOS]
- **작성일**: 2026-09-09
- **상태**: 진행 중
- **출처**: `docs/COMPETITOR_ANALYSIS.md` 벌점 아이디어 2종 (Wifilicious Cloudflare 속도 테스트 / yFi 급락→자동 재연결). 09-05 이후 미등록 상태였음
- **원칙**: 사용자 개시형(측정 시점·데이터 소모 통제) + best-effort(실패는 안내, 조용한 침묵 금지)

---

## 1. 기능 1 — 속도 테스트 (T-205)

### 1.1 목표

- 진단 센터에서 **다운/업 실측 Mbps** 1회성 측정. "ISP vs Wi-Fi 판별" 힌트 문구 포함
- 핫스팟(유료/제한망) 연결 시 **데이터 소모 사전 경고** (TetherLens 정체성에 맞춤)

### 1.2 설계

- `NetworkDiagnostics.speedTest(progress:) async -> DiagnosticsEntry`
  - 다운: `URLSession`으로 고정 바이트 GET (Cloudflare `speed.cloudflare.com/__down?bytes=N` 1차, 실패 시 Apple CDN 폴백). N=10MB 기본, 저전력/핫스팟 시 5MB
  - 업: 동일 호스트로 POST 업로드 (10MB 랜덤 버퍼, 메모리 상주 1회)
  - 측정: 첫 바이트 제외(핸드셰이크 제외) 후 전송 구간만으로 Mbps 산출, 20초 타임아웃 + 취소 지원
- `DiagnosticsView`: "속도 테스트" 버튼 + 진행률 + 결과 entry (Mbps, 등급 문구). 핫스팟 연결 시 확인 문구
- 단위 테스트: Mbps 산출 순수 함수 + 타임아웃/취소 경로 (실망 호출은 수동)

### 1.3 범위 외

- 상시 백그라운드 측정 없음 (수동 개시만 — 에너지/데이터 정책)
- P2P·다중 스트림 병렬 측정 (v1은 단일 스트림)

## 2. 기능 2 — 연결 유지 (T-206)

### 2.1 목표

- 끊김/급락을 **즉시 감지 → 알림 → 원클릭 재연결 시도**. yFi식 "회의 중 끊김" 대응

### 2.2 설계

- `ConnectionGuardian` 신규 (PingMonitor + ReachabilityPolicy 이벤트 구독, 신규 타이머 없음)
  - 연속 실패 N회(기존 정책 재사용) → 끊김 확정 → NotificationManager 알림 (액션: "Wi-Fi 재연결")
  - 재연결: `networksetup -setairportpower` off/on best-effort 실행. 실패 시 수동 안내 문구 (sudo 필요 시 조용히 포기하지 않고 알림에 명시)
  - 자동 재시도 토글 (기본 OFF, SettingsView). ON이어도 1회만 시도 + 쿨다운 5분 (재연결 루프 방지)
- 단위 테스트: 쿨다운/1회-시도 상태머신 (실 `networksetup` 호출은 수동)

### 2.3 범위 외

- 특정 SSID 자동 joining (키체인·보안 이슈, 미지원)
- VPN 재연결 (OS/벤더 영역)

## 3. 검증 (T-207)

- `swift build` 경고 0 + `test.sh` 전체 통과
- 수동: 진단 센터 속도 테스트 (일반망/핫스팟 경고) + Wi-Fi 끄기→알림→재연결 액션
- DebugPanel ERROR 0. PERF: 신규 상시 타이머 0개, 측정 시 RSS +10MB 이내
- Info.plist bump는 릴리즈 시점 (0.35.0/35)
