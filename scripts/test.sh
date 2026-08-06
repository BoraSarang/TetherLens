#!/bin/bash
# TetherLens 자동화 테스트 + 수동 테스트 안내
# 1) 서비스 로직 단위 테스트(swift test) 자동 실행
# 2) 실패 시 실패 목록 출력 후 exit 1
# 3) 통과 시 자동화 불가 항목(UI/권한/네트워크) 수동 체크리스트 안내
# 주의: macOS 기본 bash 3.2가 이모지를 파싱하지 못하므로 ASCII만 사용
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

LOG="/tmp/tetherlens-test-$(date +%Y%m%d-%H%M%S).log"

echo "=============================================="
echo " TetherLens 자동화 테스트 (swift test)"
echo "=============================================="
echo ""

if swift test 2>&1 | tee "$LOG"; then
  PASS_COUNT=$(grep -c $'\xE2\x9C\x94 Test' "$LOG" || true)
  echo ""
  echo "=============================================="
  echo " [PASS] 자동화 테스트 전체 통과 (${PASS_COUNT}개)"
  echo " 로그: $LOG"
  echo "=============================================="
else
  echo ""
  echo "=============================================="
  echo " [FAIL] 자동화 테스트 실패 - 아래를 확인하세요"
  echo "=============================================="
  grep -E $'\xE2\x9C\x98|failed with' "$LOG" | head -30 || true
  echo ""
  echo " 전체 로그: $LOG"
  exit 1
fi

echo ""
echo "=============================================="
echo " 수동 테스트 체크리스트 (자동화 불가 항목)"
echo "=============================================="
echo ""
echo "1. 메뉴바 표시 + 오른쪽 클릭 '더보기' 드롭다운 메뉴"
echo "2. 팝오버 열기 (속도/SSID/할당량 QoS 게이지 표시)"
echo "3. 온보딩 첫 실행 + 위치/알림 권한 요청 순서"
echo "4. 실제 핫스팟 연결 감지 (SSID + iOS/Android OS 구분)"
echo "5. 절약모드 hosts 차단 (sudo 필요 - T-41~T-43)"
echo "6. 트래픽 실측 (nettop) + 메뉴바 속도/사용량 갱신"
echo "7. ping 레이턴시 + QoS 게이지 색상 경계 (절약모드 ON/OFF 각각)"
echo "8. 할당량 경고 알림 (50/80/95/100%) + 레이턴시 알림"
echo "9. DebugPanel (Cmd+D): ERROR 0건 확인"
echo "10. 배터리: 저전력 모드에서 위치/IP 갱신 중지"
echo ""
echo "상세 절차: docs/tests/v0.21.0_macos.md (T-01~T-56)"
echo ""
