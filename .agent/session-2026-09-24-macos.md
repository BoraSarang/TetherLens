# session-2026-09-24-macos

1. v0.37.0 iStat 스타일 트래픽 + CPU/GPU/MEM 카드 대시보드 구현 (bd TetherLens-4kb) — 3면 전부
2. 신규: MetricsHistory(60점 링, refresh 편승) + DesignSystem/Components(TLSparkline·TLShareBar·MetricCard·TLGaugeBar·TLCoreBars·SystemMetricsCards)
3. SystemResourceMonitor: gpuPercent + IOKit GPU(3클래스·4키) + perCore(host_processor_info 델타) + load1(getloadavg) + formatMemUsedTotal
4. UI: 3면 점유율 바 + 카드 compact/standard/full, Localized gpu/더보기
5. 설정: 플로팅 창 섹션 CPU/GPU/RAM 카드 개별 토글 — 기본 RAM ON, CPU·GPU OFF (단일 showSystemGraphs 제거)
6. 팝오버 상태행: 외부 IP 칩 왼쪽 게이트웨이 칩 추가 (탭 복사)
7. 카드 trailing 통일: CPU/GPU/RAM 모두 제목 오른쪽 우측 수치 (hero 제거)
8. 플로팅 호버: 투명도 옆 차트 아이콘 드롭다운 — CPU/GPU/RAM 카드 on/off (설정과 동일 키)
9. RAM 라벨 통일: Localized.memory/sortByMemory/showMemGraph/systemLoadSummary → RAM (한/영)
10. 플로팅 카드 배경 투명도: MetricCard.backgroundOpacity — 슬라이더가 창+카드 배경에 동시 적용 (텍스트 선명)
11. 앱 트래픽 잘림 수정: 고정 높이 + 카드 → 전체 ScrollView + List→LazyVStack
12. 앱 트래픽 카드 스타일: 프로세스 목록 MetricCard 셸 통일 + alwaysShowAll(플로팅 토글 무관)
13. 앱 트래픽 창: 640×760 고정 + windowResizability(.contentSize) 리사이즈 금지
14. 플로팅 재구성: 네트워크 카드 항상(팝오버 차트 TLNetworkSpeedChart + 큰 숫자 + 프로세스 Top3) + 프로세스/그래프 분리 토글 제거
15. NetworkMonitor.shared(ObservableObject) — 팝오버/플로팅 공유, 메뉴바도 shared 사용
16. 검증: test.sh 122개 통과, swift build 완료, build-macos.sh debug 실행
17. 문서: PLAN_v0.37.0_iStat_macos.md(§3.1), TODO T-211~222, CHANGELOG [Unreleased], 세션 로그, bd 4kb notes
18. 남은 TODO: GUI 육안(네트워크 카드·카드 토글·스크롤·리사이즈 금지) 사용자 몫, Info.plist bump는 릴리즈 시점
19. 큐: bd 4kb close, TetherLens-9a5(v0.31 플로팅) 별건 미처리 잔류
20. 메뉴 조사 후 P0+P1 일괄: rename "시스템 대시보드"(appTraffic/appTrafficButton/showAppTrafficLabel/창 제목+안내 문구, 식별자 유지, 리포트 탭만 "프로세스 트래픽")
21. P1: 팝오버 … 사용량 리포트 중복 제거, ⌘K 팔레트 순서 동일 그리드 + 진단/프로필 추가(프로필은 moreAction 팝오버 오버레이)
22. 검증: test.sh 122개 통과, swift build OK
23. v0.38.0 안정성 리팩터링 (bd hx3, closed): NWPathMonitor 재생성, start 멱등, ifa_addr 가드, DataStore/ProfileManager try!·as! 안전화, LocationManager 강제해제 제거
24. v0.38.1 성능 리팩터링 (bd mt9): NetworkMonitor/TrafficMonitor/MetricsHistory @Published→단일 스냅샷, AppBlockManager CSV 캐시, DebugLogger DateFormatter+MainActor 직push, HotspotDetector route/DNS 백그라운드, 뷰 sort·filter·share hoisting, 플로팅 $apps→$snapshot
25. 최종 검증: swift build OK + test.sh 122개 통과. CHANGELOG·PLAN §3.3 갱신
26. 잔류 마감: bd 4kb(v0.37 iStat)·9a5(v0.31 플로팅) close + TODO 섹션 ✅ 갱신 (T-169~174, T-211~222)
27. 재점검 조사(2회 explore): 안정성 P1 3건(IPResolver URL! / isCurrentPathExpensive 이중 resume / DNS 메인스레드 Process) + 성능 P1/P2 body 고비용 연산·DateFormatter·타이머 tolerance
28. 신규 bd: k5o(안정성)·rsk(성능) 등록, TODO T-223~226, PLAN §3.4·CHANGELOG 반영
29. v0.38.2 패치: ResumeOnceGate, currentServersAsync, IPResolver URL guard, PopoverView 리소스 섹션/ReportView markdown 캐시/ReportAppTrafficView·Heatmap·Timeline hoisting, static DateFormatter, NetworkMonitor leeway, FloatingWindowViewModel 단일 스냅샷
30. 최종 검증: swift build OK + test.sh 122개 통과. bd k5o·rsk close, TODO T-223~226 ✅
31. 릴리즈 v0.37.0: Info.plist 0.37.0/37, CHANGELOG [Unreleased]→[0.37.0], PR·머지·태그·Release CI
