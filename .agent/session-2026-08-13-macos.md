## v0.28.2 세션 (08:00 종료)
1. T-146~149: 네트워크 API 호출 최적화 — IP 동일 시 ipapi.co 생략, ipRefreshTimer 3600s, 저전력 IP 로그 info 하향, 위치 15분 쿨다운
2. 플랫폼: macOS
3. 빌드: test.sh 43개 통과. DebugPanel 실측 — IP 동일 생략(07:19:11), 위치 쿨다운 스킵(07:24/07:29), 15분 후에만 실제 요청(07:34). v0.28.1 balance=0 유지
4. 남은 TODO: 없음
5. 다음 전달: 없음
6. 문서: TODO v0.28.2, CHANGELOG v0.28.2
7. 오프라인 큐: 해당 없음
8. 커밋 b177216 → main + v0.28.2 태그 + GitHub Release 완료
