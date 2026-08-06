# Session — 2026-08-06 (macOS) — v0.22.1

1. 무엇을: **v0.22.1 Android 핫스팟 감지 보강 (T-74~T-76)** + 수동 테스트 전체 통과. 사용자 수동 테스트 중 "Android 핫스팟인데 Wi-Fi로 표시" 발견 → `HotspotDetector` 감지 개선. 이전: v0.22.0 자동화 테스트 도입 (T-67~73), v0.21.1 Low 6건, 온보딩 크래시 수정.
2. 플랫폼: [macOS]
3. 빌드: swift test 32/32 통과 (7스위트, +HotspotDetectorTests 4개), build-macos.sh debug 성공. 수동 체크리스트 10항목 전부 ✅ (연결 타입 정상 표시, hosts 차단 4줄 확인, 알림/배터리 정상).
4. 남은 TODO: T-47 위젯(Xcode 전환 필요, 제외). **v0.21.1+v0.22.0+v0.22.1 커밋/태그/릴리즈 대기** (v0.22.0 자동화 포함 전부 미커밋).
5. 전달 로그:
   - **Android 핫스팟 오분류 원인**: 감지가 게이트웨이 대역(`192.168.43/80/42`) + 제한적 SSID 키워드에만 의존. 사용자 환경 게이트웨이 `10.229.78.251`(비표준) + SSID `OkStart`(키워드 없음) → `normalWiFi`로 분류됨.
   - **수정**: `isAndroidHotspotGateway(_:)` 신설(43/42/44/49/80/81/111.x), `isAndroidSSID(_:)` 키워드 확장(okstart/oppo/vivo/realme/infinix/tecno/tp-link), 분기 순서 개선(게이트웨이→iOS 대역→Android SSID→isExpensive→normalWiFi). `isPersonalRange` 제거. `private` → internal로 바꿔 테스트 가능.
   - **테스트 함정**: `TP-LINK_1234`가 `tplink` 키워드와 하이픈 때문에 매칭 안 됨 → `tp-link` 키워드 추가.
   - 수동 검증: `route -n get default`(gateway 10.229.78.251, en0) + `/etc/hosts`에 `# TetherLens SavingMode` 마커 + `127.0.0.1` 4줄 추가 확인.
6. 문서: TODO T-74~76, CHANGELOG v0.22.1, docs/tests/v0.22.0_macos.md 갱신(32개/수동 결과 테이블).
7. 오프라인 큐: N/A.
8. E2E/k6: N/A — 자동화 단위 테스트(32개) + 수동 체크리스트 10항목 전부 통과.
