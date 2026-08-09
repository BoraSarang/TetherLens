# TetherLens — 경쟁 앱 비교 분석

**작성일**: 2026-07-25 (v1.0)  
**갱신일**: 2026-08-09 (v2.0 — 동종 앱 10종 리서치 추가)
**버전**: v2.0

---

## 1. 개요

TetherLens는 macOS 메뉴바에서 핫스팟/테더링 데이터 사용량을 실시간 모니터링하고 관리하는 앱입니다.  
본 문서는 유사 기능을 제공하는 경쟁 앱들을 조사하고 TetherLens의 포지셔닝을 분석합니다.

---

## 2. 직접 경쟁자 (Hotspot / Tethering 특화)

### 2.1 TripMode
| 항목 | 내용 |
|------|------|
| **URL** | https://tripmode.ch |
| **가격** | $14.99/년 구독 or $50 일회성 (5 Mac) |
| **macOS** | 11.0+ |
| **배포** | Mac App Store + 직접 |
| **핵심 기능** | 핫스팟 자동 감지 → 앱별 차단/허용, 라이브 모니터, 프로필, 데이터 한도 설정, 스케줄러, 도메인 뷰 |
| **장점** | 앱 차단 기능 내장, 핫스팟 자동 전환, 프로필 기반 네트워크별 규칙, 사용자 피드백 우수 (MacWorld 5/5) |
| **단점** | 구독제, 통계/리포트 기능 부족 (장기 히스토리 없음), 방화벽 목적엔 오버스펙, 앱별 속도 제한 불가 |

### 2.2 HotspotPeek
| 항목 | 내용 |
|------|------|
| **URL** | https://anhphong.dev (개인 개발) |
| **가격** | $4.99 일회성 |
| **macOS** | 14.0+ |
| **배포** | Mac App Store |
| **핵심 기능** | NWPathMonitor.isExpensive 기반 핫스팟 감지, 세션/월별 사용량, 프로필 (여러 핫스팟), 할당량 알림 |
| **장점** | 저렴한 일회성 가격, 심플, 핫스팟에 특화 |
| **단점** | 앱별 트래픽 불가, 리포트/통계 없음, QoS 게이지 없음, 세션 시간 추적 없음, 개발 규모가 작음 |

### 2.3 DataCever
| 항목 | 내용 |
|------|------|
| **URL** | https://datacever.com |
| **가격** | $6.99 일회성 |
| **macOS** | 최신 |
| **배포** | Mac App Store |
| **핵심 기능** | 앱별 모니터, 앱별 차단, 앱별 할당량 (데이터 한도) |
| **장점** | 앱별 데이터 한도 기능이 독특, Mac App Store 배포 (설치 간편), 저렴한 가격 |
| **단점** | 핫스팟 특화 감지 없음, 프로필/SSID 전환 불가, 통계/그래프 부족, QoS 게이지 없음 |

---

## 3. 간접 경쟁자 (네트워크 모니터링 일반)

### 3.1 NetFluss
| 항목 | 내용 |
|------|------|
| **URL** | https://github.com/rana-gmbh/NetFluss (오픈소스) |
| **가격** | 무료 (오픈소스, 라이선스 확인 필요) |
| **macOS** | 14.0+ |
| **배포** | 직접 다운로드 |
| **핵심 기능** | 메뉴바 실시간 속도, Top 5 앱 리스트, 통계 창 (1H/24H/7D/30D/1Y), 라우터 대역폭 모니터링 (Fritz!Box/UniFi/OpenWRT/OPNsense), 속도 테스트 (M-Lab/Cloudflare), 다양한 메뉴바 스타일 |
| **장점** | 오픈소스, 풍부한 통계 기능, 라우터 모니터링, 속도 테스트 내장, macOS 26.5 ifi_ibytes 버그 대응 완료 |
| **단점** | 핫스팟 특화 기능 없음, 프로필/할당량 없음, SSID 기반 전환 불가 |

### 3.2 ova
| 항목 | 내용 |
|------|------|
| **URL** | https://ova.productdevbook.com |
| **가격** | 일회성 결제 (정확한 가격 미확인) |
| **macOS** | 14.0 (Apple Silicon + Intel) |
| **배포** | 직접 |
| **핵심 기능** | per-app 실시간 속도 (1Hz 샘플링), per-app 히스토리 (되감기 가능), 헬퍼 프로세스 통합 (Chrome/Slack helpers 통합), 로컬 전용, 풋프린트 3MB |
| **장점** | per-app 모니터링에 특화, 헬퍼 프로세스 통합 UX 우수, 히스토리 기능 강력, 저전력 (idle CPU 0.3%) |
| **단점** | 핫스팟 감지 없음, 앱 차단/방화벽 기능 없음, 시스템 전체 모니터링 없음 |

### 3.3 Bandwidth+
| 항목 | 내용 |
|------|------|
| **URL** | Mac App Store |
| **가격** | 무료 |
| **macOS** | 11.0+ |
| **배포** | Mac App Store |
| **핵심 기능** | 시스템 전체 업/다운로드 사용량, 네트워크 인터페이스별 월별 합계, 리셋 가능 |
| **장점** | 무료, 가벼움, 간단 |
| **단점** | per-app 불가, 실시간 속도 불가 (주기적 업데이트), 핫스팟 감지 불가, 히스토리 제한적 |

### 3.4 NetBar
| 항목 | 내용 |
|------|------|
| **URL** | https://github.com/mh-sudo/NetBar (오픈소스) |
| **가격** | 무료 (MIT) |
| **macOS** | 13.0+ |
| **배포** | 직접 |
| **핵심 기능** | 메뉴바 실시간 속도, VPN 국가 플래그, 사용량 트래킹 (1H/1D/1W/1M + 12개월), 인터페이스 락, 3중 VPN 감지 |
| **장점** | 오픈소스, 무료, VPN 감지 우수, 12개월 히스토리 |
| **단점** | 핫스팟 특화 없음, 프로필 없음, 할당량 알림 없음, 앱별 트래픽 불가 |

### 3.5 iStat Menus
| 항목 | 내용 |
|------|------|
| **URL** | https://bjango.com/mac/istatmenus/ |
| **가격** | 구독 또는 일회성 |
| **macOS** | 최신 |
| **배포** | 직접 |
| **핵심 기능** | 올인원 시스템 모니터 (CPU/GPU/메모리/디스크/센서/팬/네트워크/날씨), per-process 네트워크 |
| **장점** | 올인원, 커스터마이징, UI 완성도 높음 |
| **단점** | 핫스팟 특화 없음, 고가, 네트워크 모니터링이 부가 기능, 오버스펙 |

### 3.6 Little Snitch
| 항목 | 내용 |
|------|------|
| **URL** | https://www.obdev.at/products/littlesnitch/ |
| **가격** | $59 일회성 |
| **macOS** | 최신 |
| **배포** | 직접 |
| **핵심 기능** | 방화벽 (앱별 outbound 연결 제어), 네트워크 모니터 모드 (연결 그래프), 지리적 트래픽 뷰 |
| **장점** | 강력한 방화벽, 다양한 룰 시스템, 성숙한 제품 |
| **단점** | 방화벽이 주목적, 핫스팟 특화 없음, 고가, 모니터링 기능은 부차적, 시스템 확장 권한 필요 |

---

## 4. 기능 비교표

| 기능 | TetherLens | TripMode | HotspotPeek | DataCever | NetFluss | ova | Bandwidth+ | NetBar | Little Snitch |
|------|:----------:|:--------:|:-----------:|:---------:|:--------:|:---:|:----------:|:-----:|:-------------:|
| **메뉴바 속도** | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **핫스팟 감지** | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **SSID 프로필** | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **할당량/QoS 게이지** | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **앱별 트래픽** | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ |
| **앱별 차단** | ⬜ (NEFilter) | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| **통계/그래프** | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ✅ | ❌ |
| **세션 시간 추적** | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **DNS 프리셋** | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **절약 모드** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **외부 IP/GeoIP** | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| **Ping 모니터링** | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **자동 업데이트** | ✅ (Sparkle) | ✅ | ? | ? | ? | ? | ? | ? | ✅ |
| **방화벽** | ⬜ (Future) | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| **가격** | **무료** | $14.99/년 | $4.99 | $6.99 | 무료 (OSS) | 일회성 | 무료 | 무료 (OSS) | $59 |
| **오픈소스** | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ✅ | ❌ |

> ✅ = 지원 | ❌ = 미지원 | ⬜ = 계획 중 | ? = 미확인

---

## 5. TetherLens 포지셔닝 맵

### 5.1 강점 (Competitive Advantages)

| # | 강점 | 설명 | 경쟁자 대비 |
|---|------|------|------------|
| 1 | **완전 무료 + 오픈소스** | 무료로 모든 기능 제공 | TripMode $14.99/년 vs 무료 |
| 2 | **핫스팟 특화 + 포괄적 기능** | 단순 모니터링에 그치지 않고 통계/세션/DNS/절약모드까지 통합 | TripMode는 통계 부족, HotspotPeek은 기능 빈약 |
| 3 | **세션 시간 추적** | SSID 기준 자동 세션 시작/종료, 세션별 사용량 | 경쟁자 중 유일 |
| 4 | **DNS 프리셋 변경** | osascript로 DNS 서버 변경 | 경쟁자 중 유일 |
| 5 | **절약 모드** | osascript로 시스템 설정 자동 제어 | TripMode(앱 차단)와 다른 접근 |
| 6 | **통계/리포트** | Swift Charts 그래프 + 일별/세션별 리포트 | TripMode/HotspotPeek 부재 영역 |
| 7 | **외부 IP/Ping/GeoIP** | 연결 품질 종합 모니터링 | NetFluss/ova 등 순수 모니터 앱보다 종합적 |
| 8 | **프로필 통계 버튼** | 팝오버에서 바로 프로필별 통계 | TripMode에도 없는 UX |

### 5.2 약점

| # | 약점 | 설명 | 영향 |
|---|------|------|------|
| 1 | **앱 차단 불가** | NEFilterDataProvider 미구현 (SPM 한계) | TripMode/DataCever 대비 핵심 기능缺失 |
| 2 | **앱별 할당량 불가** | 앱별 데이터 한도 설정 불가 | DataCever만의 강점 |
| 3 | **Mac App Store 미등록** | 직접 배포만 가능 (Sparkle) | 사용자 접근성 제한 |
| 4 | **Notarization 미완료** | 유료 계정 필요 | 보안 경고 발생 가능 |
| 5 | **앱 트래픽 히스토리 부족** | nettop 기반 실시간만, 장기 저장 없음 | ova 대비 히스토리 기능 부족 |
| 6 | **브랜드/마케팅 부재** | 개인 프로젝트 수준 | 인지도 낮음 |

### 5.3 포지셔닝 맵

```
                    핫스팟 특화
                        │
                        │
          TetherLens ●   │   ● TripMode
                        │
                        │
    ────────────────────┼─────────────────── 기능 다양성
                        │
                        │
          NetFluss ●    │
          ova ●         │
          Bandwidth+ ●  │
                        │
                    일반 모니터링
```

```
                    무료
                      │
                      │
    TetherLens ●      │
    NetFluss ●        │
    NetBar ●          │
    Bandwidth+ ●      │
                      │
──────────────────────┼────────────────────── 기능 깊이
                      │
                      │
                      │   ● TripMode ($14.99/년)
                      │   ● DataCever ($6.99)
                      │   ● HotspotPeek ($4.99)
                      │   ● Little Snitch ($59)
                      │
                    유료
```

---

## 6. 경쟁사 전략 분석

### 6.1 TripMode (가장 강력한 경쟁자)

| 항목 | 분석 |
|------|------|
| **비즈니스 모델** | 구독 $14.99/년 + 일회성 $50 (5 Mac) |
| **핵심 가치** | "Save data, browse faster" — 앱 차단으로 데이터 절약 |
| **타겟** | 여행자, 테더링 사용자, 데이터 제한 환경 |
| **강점** | 브랜드 인지도, MacWorld 5/5, New York Times 소개, 완성도 높은 UI |
| **취약점** | 통계/리포트 부족, 세션 추적 없음, DNS 변경 없음, 구독 피로 |
| **TetherLens 대응** | 통계/DNS/세션 등 TripMode에 없는 기능으로 차별화, 무료 가격 우위 |

### 6.2 HotspotPeek (가장 가까운 대체재)

| 항목 | 분석 |
|------|------|
| **비즈니스 모델** | 일회성 $4.99 |
| **핵심 가치** | "Track hotspot data usage" — 핫스팟 전용 심플 모니터 |
| **타겟** | 테더링 사용자, 저예산 |
| **강점** | 심플함, 저렴함, App Store |
| **취약점** | 기능 부족 (앱 트래픽/통계/세션/DNS 없음) |
| **TetherLens 대응** | 모든 기능 무료 제공으로 압도 |

### 6.3 DataCever

| 항목 | 분석 |
|------|------|
| **비즈니스 모델** | 일회성 $6.99 |
| **핵심 가치** | "Per-app data quota" — 앱별 데이터 한도 |
| **타겟** | 앱별 데이터 제어가 필요한 사용자 |
| **강점** | 유일한 앱별 할당량 기능, Mac App Store |
| **취약점** | 핫스팟 감지 없음, 제한적 기능 |
| **TetherLens 대응** | 미래 앱 차단 기능 추가 시 직접 경쟁 |

---

## 7. 제언 (Strategic Recommendations)

### 7.1 단기 (현재 상태로)

| 우선순위 | 제안 | 근거 |
|----------|------|------|
| **P0** | 오픈소스 마케팅 강화 (GitHub README/데모) | 무료 + 오픈소스가 가장 강력한 무기 |
| **P1** | HotspotPeek 대비 차별점 홍보 | "HotspotPeek이 할 수 없는 10가지" |
| **P1** | 사용자 피드백 수집 채널 마련 | GitHub Issues, 이메일 |

### 7.2 중기 (NEFilterDataProvider 추가 시)

| 우선순위 | 제안 | 근거 |
|----------|------|------|
| **P0** | 앱 차단 기능 구현 (NEFilterDataProvider) | TripMode와의 가장 큰 격차 해소 |
| **P1** | 앱별 할당량 기능 | DataCever의 유일한 강점 제거 |
| **P2** | Mac App Store 배포 검토 | 사용자 접근성 향상 |

### 7.3 장기

| 제안 | 근거 |
|------|------|
| Notarization + 공식 서명 | 보안 경고 제거, 신뢰도 향상 |
| 글로벌 사용자 대상 현지화 | 해외 사용자 확대 (영어/일본어 등) |
| 브랜드 구축 (웹사이트/로고) | TripMode 수준의 브랜드 인지도 |

---

## 8. 결론

TetherLens는 **핫스팟/테더링 데이터 모니터링**이라는 틈새 시장에서 **무료 + 오픈소스 + 포괄적 기능**이라는 독보적인 포지션을 가지고 있습니다.

| 항목 | 평가 |
|------|------|
| **직접 경쟁자 대비** | TripMode는 앱 차단에서 앞서나, TetherLens는 통계/세션/DNS/절약모드 등 더 넓은 기능 세트를 무료로 제공 |
| **간접 경쟁자 대비** | 핫스팟 특화 + 프로필 관리 + 통계까지 커버하는 앱은 TetherLens가 유일 |
| **가격 경쟁력** | 모든 경쟁 유료 앱 대비 무료가 가장 강력한 장점 |
| **핵심 격차** | 앱 차단 기능 (NEFilterDataProvider) — 추가 시 경쟁 우위 확보 가능 |

> **핵심 메시지**: "TripMode의 기능 대부분을 무료로 + TripMode에 없는 기능까지"

---

# 부록 A. 신규 동종 앱 리서치 (2026-08-09 기준)

> 사용자 제안 10종 앱을 조사하고 TetherLens 대비 격차/참고 기능을 정리한다.
> 기존 v1.0(구 경쟁자 중심)과 달리, 이 부록은 **신규 등장 앱 + Wi-Fi 일반 진단 앱**을 포함한다.

## A.1 App / 제품 목록

| # | 제품 | 유형 | 가격 | 배포 |
|---|------|------|------|------|
| 1 | **HotspotPeek 2.0** | 핫스팟/네트워크 데이터 카운터 | 무료 + Pro $4.99 | Mac App Store |
| 2 | **Hotspot Guard** | 앱별 데이터 한도/차단 | 무료 (얼리액세스) | 직접 다운로드 |
| 3 | **WiFi & IP Info – One Click 2.2** | 네트워크 대시보드 + 진단 | $0.99 + Pro $9.99 | Mac App Store |
| 4 | **QuickNetStats** | 메뉴바 네트워크 상태 | 무료 (MIT, OSS) | Homebrew · GitHub |
| 5 | **Wifilicious 2.0** | Wi-Fi 신호/속도/추세 + AI | 유료 (Mac Store/Setapp) | Mac App Store |
| 6 | **yFi** | Wi-Fi 연결 안정성 | 무료 | Mac App Store |
| 7 | **Adrian Granados WiFi Signal** | Wi-Fi 신호 감시 | 유료 | 직접/Mac Store |
| 8 | **Wifiry (AppYogi)** | Wi-Fi 신호 강도 표시 | $9.99 | Mac App Store |
| 9 | **WiFiSpoof 4** | MAC 주소 변경 | $24.99 | 직접 · Mac App Store |
| 10 | **LeanRunning** | USB/WiFi 트리거 자동화 | $14.99 | 직접 |

## A.2. 개별 상세 분석

### A.2.1 HotspotPeek 2.0 — 가장 근접한 대체재
| 항목 | 내용 |
|------|------|
| **핵심** | ~~iPhone 핫스팟만 감지~~ → v2.0에서 **모든 네트워크 측정**으로 재작성. 네트워크별 카운터, 월/주/일 리셋, 데이터 한도(90%/50%/75% 알림), 4GB wrap 대응, `netstat` 교차 검증(일치 0.02%), 바이트 중복 카운트 제거 |
| **강점** | "단순함 + 정확성". 카운터 정확도에 대한 신뢰성 강조(리뷰에서 `nettop`/`netstat` 대비 검증 내세움). 무료로 기본 한도 추적 제공 |
| **약점** | 앱별 트래픽 없음, 세션/통계/리포트 없음, QoS 게이지 없음, 프로필(SSID) 관리 없음. 기능이 매우 얕음 |
| **벌 점** | ⭐ 카운터 정확성 → `netstat` 교차검증 아이디어. ⭐ `netstat` 교차검증과 월/주/일·한도 알림은 TetherLens QoS와 겹침 (참고: TetherLens도 4종 네트워크 측정 이미 지원). ⭐ 메뉴바 사용량 한 줄 표시 UX |

### A.2.2 Hotspot Guard — 앱별 가드 (TetherLens 최대 차이)
| 항목 | 내용 |
|------|------|
| **핵심** | **앱별 데이터 한도** (분/시간), 앱 수준 경고/차단 선택, 시스템 업데이트 재시도→3진 프리즈(손실 절약), 앱 149종 내장 지식팩 제공 |
| **특징** | "데이터가 줄줄 샌다" → per-app 가드. 마케딕(온프레미스이며 원격 조회 off-by-default) |
| **약점** | 프로세스 차단 수준(방화벽 X), SIM플 드라이브, EBITDA 베타 |
| **벌 점** | ⭐ TetherLens가 **없는 핵심 기능** = per-app 차단/한도. 현재 앱별 트래픽 순위만 있고, 차단·한도는 없음 → 최우선 후보 |

### A.2.3 WiFi & IP Info – One Click 2.2 — 진단 (Insights) 분야 최강
| 항목 | 내용 |
|------|------|
| **핵심** | 대시보드: SSID/시그널/로컬·외부 IP/게이트웨이/캡티브 포탈/uptime/업데이트 알림. VPN/proxy 감지(WireGuard·Tailscale·IPSec·PAC). 진단: latency/jitter/packet loss 그래프, 커스텀 ping 대상, traceroute("slow jump" marking). networkQuality(RPM/bufferbloat). DNS leak test. Connection Log (CSV export). Helpdesk 리포트 한 클릭 copy |
| **특징** | v2.2가 배터리 최적화 폴pulling 정지, 쓸쓸 배치, 이벤트 구독 → 초기 에너지 문제 해결. SwiftUI/Swift 6, 12개 언어 |
| **약점** | 핫스팟 특화 없음, 데이터 사용(quota) 추적 없음, 프로필 없음 |
| **벌 점** | ⭐**진단 탭** (VPN/proxy·Latency/traceroute·DNS Leak·bufferbloat) — TetherLens는 ping만 있고 진단 세트가 전무 → 차별 근거. ⭐ 메뉴바 아이콘 상태 그래프(정상/비정상/연결 안 원 색상). ⭐ 프로얼 레포트(Markdown 하나로 헬프데스크 전달) — TetherLens의 Report 창과 유사 컨셉 재사용 가능 |

### A.2.4 QuickNetStats — 연결 즉시 감지 + 링크 품질
| 항목 | 내용 |
|------|------|
| **핵심** | **연결 상태 즉시 반영** (macOS 버전이라 불과). 링크 품질(Good/Minimal/Moderate) speedtest 없이 추정, IPv4 목록 클립보드 클릭 복사, 캡티브 포탈 확인, 연결 유형(Wi-Fi/Ethernet/Hotspot) 표시 |
| **특징** | 무료 OSS, Homebrew 케스크. battery-light. macOS 13+ |
| **벌 점** | ⭐ 이미 TetherLens가 핑/네트워크 감지에 해당 — 하지만 "빠른 끊김 감지(SW CLI)" + `Ethernet/Hotspot 구분` 아이디어는 활용 가능. IP 클립보드 UX 요구성 |

### A.2.5 Wifilicious 2.0 — 신호/추가/속도/AI 분야
| 항목 | 내용 |
|------|------|
| **핵심** | 시그널(우) tab: RSSI/SNR/noise floor/채널/bandwidth. **Speed** tab: Cloudflare 속도 테스트(연결~9/5MB, Wi-Fi 병목과 ISP 구분). **Trends**: last hour→month 시계열. **Details**: IPv4/6·BSSID·gateway·MAC·CC. Apple Intelligence 온디바이스 "Ask/요약" (macOS 26) |
| **특징** | "Another Wow": iPhone에서도. 7메트릭 트렌드 저장. 온디바이스 strict(누도바0bytes). 14언어. Apple Store + Setapp |
| **벌 점** | ⭐ **메뉴바 커스터마이징**(12개 토글 필드 선택)과 **시그널/대역 표시**는 현재 TetherLens 메뉴바에 부재. ⭐ **속도 테스트**(Cloudflare SpeedTest) TetherLens는 실시간 대역만 — "수도 테스트 한 번으로 ISP vs Wi-Fi 판별" 아이디어 |

### A.2.6 yFi — TX rate 안정성
| 항목 | 내용 |
|------|------|
| **핵심** | 메뉴송 위젯: 속도 급락 감지 → 경고/자동 재연결. 회의 중 앱 네트워크 절방 |
| **벌 점** | TetherLens의 핑 안정성과 중복. 앱별 행동 모델(속도 급락 → 자동 재연결)은 화면에 참고만 |

### A.2.7 Adrian Granados WiFi Signal — 신호 감시
| 항목 | 내용 |
|------|------|
| **핵심** | 신호/SNR 임계 위반 알림, 로밍 감지, 메뉴바 커스텀 패턴 |
| **벌 점** | 시그널 측정(위칭)은 WiFi Signal가 표준. TetherLens 시그널 표시가 없으면 이메일들이 있음. 로밍 감지(AP 변경) 아이디어 참고값 |

### A.2.8 Wifiry / WiFiSpoof / LeanRunning (기타)
| 제품 | 요지 | TetherLens 관계 |
|------|------|----------------|
| **Wifiry** | 메뉴바에 신호% + 강도 컨텍트색(그린/옐로우/레드), 네트워크 상세 | 시그널% + 컬러 규칙 표시 참조, 구세대 |
| **WiFiSpoof** | MAC 주소 임스 품, 네트워크별 룰(직장/집) | 방화벽/프라이버시 별개 앱. 개념상 지세 TetherLens [외IP]와 별 스코프 |
| **LeanRunning** | USB/WiFi 연결 이벤트 → 앱/쇼컷 자동 실행 | ⭐ WiFi 트리거 자동화 아이디어 — TetherLens의 "SSID → 프로필 전환/자동 실행"과 시너지될 수 있는 훅. 기능 확대 선택지 |

## A.3. 기능 비교표 (신규 10종 vs TetherLens)

> ⓘ 2026-08-09 코드베이스 검증 반영: TetherLens 열은 실제 소스(`HotspotDetector.swift`, `PopoverView.swift`, `SettingsManager.swift`, `TrafficMonitor.swift`, `AppBlockManager.swift`) 기준으로 정정.

| 기능 | TetherLens | HotspotPeek | Hotspot Guard | WiFi&IP OneClick | QuickNetStats | Wifilicious |
|------|:--:|:--:|:--:|:--:|:--:|:--:|
| **메뉴바 실시간 속도** | ✅ | ✅(한 줄) | ⬜ | ✅ | ✅ | ✅ |
| **핫스팟/테더링 감지** | ✅ (4종) | ✅ | ✅ | ✅ | ✅ | ❌ |
| **per-app 데이터 차단/한도** | ⬜ (알림만) | ❌ | ✅ | ❌ | ❌ | ❌ |
| **per-app 트래픽 (nettop)** | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **네트워크/SSID 프로필** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **QoS/할당량 게이지·소진일 예측** | ✅ | ✅(일부) | ⬜ | ❌ | ❌ | ❌ |
| **세션 시간 추적** | ✅ | ❌ | ❌ | ✅(conn log) | ❌ | ❌ |
| **모든 네트워크 측정** | ✅ (iOS/Android/일반/유선) | ✅ | ✅ | ❌ | ❌ | ❌ |
| **IPv4 복사 (클립보드)** | ✅ (local/ext/gateway/BSSID/SSID) | ❌ | ❌ | ✅ | ✅ | ✅ |
| **메뉴바 표시 옵션 커스터마이징** | ✅ (3가지) | ❌ | ❌ | ✅ | ✅ | ✅ |
| **VPN/proxy 감지** | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| **DNS leak · traceroute · bufferbloat** | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| **RSSI/SNR 시그널 상세** | ✅ (RSSI/noise/링크속도) | ❌ | ❌ | ✅(일부) | ✅ | ✅ |
| **GPS/IP 위치 히스토리** | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **DNS 프리셋 직접 변경** | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **절약 모드(시스템 제어)** | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **위젯 자동화 트리거** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **오픈소스/로컬 프라이버시** | ✅ | 교차 검증 | 온디바 | 옵션 | ✅ OSS | 옵션 |

> ⬜ = 미구현(계획 가능) · ✅ = 지원 · ❌ = 미지원

## A.4. TetherLens 격차/기회 분석

### A.4.1 신규 앱이 갖고 TetherLens가 없는 것

> 2026-08-09 코드베이스 검증 후 정정: per-app 차단/NEFilter 제약, 모든 네트워크 측정 지원, IP 복사·메뉴바 옵션 존재를 반영.

| 우선순위 | 격차 | 참고 앱 | 근거 |
|------|------|---------|------|
| 🔴 **P0** | **per-app 데이터 차단/한도** | Hotspot Guard | TetherLens는 per-app **알림**까지만 구현(`AppBlockManager` — 데이터 사용 시 프로세스명 기반 UNNotification). 진짜 네트워크 차단(NEFilterDataProvider)은 **Apple 유료 개발자 계정 + 시스템 확장** 필요. 무료/OSS 배포와 충돌 → **구현 보류한 영역** |
| 🟠 **P1** | **연결 진단 심화**: VPN/proxy 감지 · DNS leak · traceroute · bufferbloat(RPM) · 커스텀 ping | WiFi&IP OneClick | 핑 인프라 재활용. TetherLens는 RSSI/트래픽/핑은 있으나 VPN·DNS leak·traceroute는 결여. 헬프데스크 리포트(Markdown) 연계로 신뢰 확보 |
| 🟡 **P1** | **메뉴바 표시 옵션 확장**: 시그널/네트워크명 3개 외 추가 항목 | Wifilicious | 현재 `menuBarMode(.speedOnly)` + `showTotalColumn` + `showSSIDInMenuBar` **3가지 옵션 이미 존재**. 기회는 "RSSI/속도 배지 등 더 많은 필드 선택"으로 축소 |
| 🟡 **P2** | **사용 내역 CSV/Markdown export** | WiFi&IP · QuickNetStats | 디버그/헬프데스크 공유용. 이미 `copyValue` IP 복사는 있고, 마크다운 리포트 연결가 있는 Report 창을 확장 |
| ⬜ **P2** | **WiFi 이벤트 → 자동화 트리거**: SSID 전환 시 앱 실행/종료·쇼컷 | LeanRunning | "핫스팟에 붙으면 절약 모드+X 종료, 홈 와이파이면 시놀로지 재개" 같은 자동 실행. 프로필 전환 훅과 결합 |

> IP 클립보드 복사(SSID/BSSID/gateway/local/external IP)는 `PopoverView.detailRow(copyValue:)` 로 **이미 지원** → 격차 항목에서 제외.

### A.4.2 TetherLens가 유지하는 강점 (신규 앱 대비)
- **완전 무료 + OSS**: One Click($9.99), Wifilicious(유료), Hotspot Guard(유료 예정) 대비 격차
- **모든 네트워크 측정 + 세션 + SSID 자동 프로필**: `normalWiFi/iOSPersonalHotspot/androidHotspot/ethernet` 4종을 프로필로 자동 등록·전환 — 신규 경쟁 중 유일한 조합
- **per-app 트래픽 순위(nettop)**: HotspotPeek/OneClick은 측정만 일부, TetherLens는 트래픽 순위까지
- **QoS 게이지+소진일 예측+기간 그래프**: 어떤 경쟁도 저수준
- **IPv4/IPv6 복사, RSSI·링크속도·채널·대역 상세, DNS 프리셋 적용, 절약 모드**: 올인원 특화

## A.5. 권장 사항 / 우선 구현 순서

> 2026-08-09 코드베이스 검증 반영 (per-app 차단·모든 네트워크·IP 복사 정정)

| 구분 | 우선순위 | 내용 | Impact |
|------|---------|------|--------|
| 신뢰 개선 | **P1** | 연결 진단 심화 (VPN/proxy 감지 · DNS leak · traceroute · 커스텀 ping) | 파워유저 확보, 기존 핑/RSSI 인프라 재사용 |
| UX 개선 | **P1** | 메뉴바 표시 옵션 확장 + 사용 내역 Markdown/CSV export | 낮은 비용 편의, 헬프데스크 공유 |
| 자동화 | **P2** | WiFi/SSID 전환 트리거 (프로필 → 앱/쇼컷 자동) | 고급 사용자, 프로필 훅과 결합 |
| 원격 제어 | **보류** | per-app 네트워크 차단(NEFilter) | Apple 유료 개발자 + Network Extension 필요, 무료 배포와 충돌 → 행동 제한 |
