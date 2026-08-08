#!/bin/zsh
# battery-profile.sh — macOS 배터리/전력 소모 프로파일링 (zsh 호환)
# usage:
#   ./scripts/battery-profile.sh [-d seconds] [app_name ...]
#   ./scripts/battery-profile.sh -d 60 tetherlens opencode tube
#   ./scripts/battery-profile.sh -d 120           # 앱 이름 생략 시 기본 대상 감지
#
# 산출물: docs/screenshots/macos/battery_YYYYMMDD_HHMM.txt
set -euo pipefail

DURATION=60
SUDO_MODE=0
OUT_DIR="docs/screenshots/macos"
TARGETS=()

while getopts "d:p" opt; do
  case $opt in
    d) DURATION="$OPTARG" ;;
    p) SUDO_MODE=1 ;;
    *) echo "unknown option"; exit 1 ;;
  esac
done
shift $((OPTIND-1))
TARGETS=("$@")

mkdir -p "$OUT_DIR"
STAMP=$(date +%Y%m%d_%H%M)
OUT="$OUT_DIR/battery_${STAMP}.txt"

if [ ${#TARGETS[@]} -eq 0 ]; then
  TARGETS=("TetherLens" "OpenCode" "TubeKeep")
fi

typeset -A PIDS SUM MAX CNT
for name in "${TARGETS[@]}"; do
  PIDS[$name]=$(pgrep -if "$name" | tr '\n' ' ' || true)
done

echo "대상 프로세스:"
for name in "${TARGETS[@]}"; do
  echo "  $name -> ${PIDS[$name]:-(없음)}"
done

INTERVAL=2
SAMPLES=$((DURATION / INTERVAL))
[ "$SAMPLES" -lt 1 ] && SAMPLES=1

for i in $(seq 1 "$SAMPLES"); do
  for name in "${TARGETS[@]}"; do
    total=0
    n=0
    for pid in ${(z)${PIDS[$name]}}; do
      val=$(ps -p "$pid" -o %cpu= 2>/dev/null || echo 0)
      val=${val:-0}
      total=$(echo "$total $val" | awk '{printf "%.2f", $1+$2}')
      n=$((n+1))
    done
    if [ "$n" -gt 0 ]; then
      avg=$(echo "$total" | awk -v n="$n" '{printf "%.2f", $1/n}')
      SUM[$name]=$(echo "${SUM[$name]:-0} $avg" | awk '{printf "%.2f", $1+$2}')
      CNT[$name]=$((${CNT[$name]:-0}+1))
      if [ "$(echo "$avg ${MAX[$name]:-0}" | awk '{print ($1>$2)?1:0}')" = "1" ]; then
        MAX[$name]="$avg"
      fi
    fi
  done
  sleep "$INTERVAL"
done

{
  echo "== 배터리 프로파일 리포트: $(date '+%Y-%m-%d %H:%M') =="
  echo "측정 구간: ${DURATION}초 (샘플 ${SAMPLES}개, 간격 ${INTERVAL}초)"
  echo ""
  echo "--- 프로세스별 CPU 사용률 ---"
  for name in "${TARGETS[@]}"; do
    cnt=${CNT[$name]:-0}
    if [ "$cnt" -gt 0 ]; then
      mean=$(echo "${SUM[$name]:-0}" | awk -v c="$cnt" '{printf "%.2f", $1/c}')
      printf "%-12s 평균 %5.2f%%   최대 %5.2f%%  (샘플 %d)\n" "$name" "$mean" "${MAX[$name]}" "$cnt"
    else
      printf "%-12s (실행 중이 아님)\n" "$name"
    fi
  done
  echo ""
  echo "--- 상위 10 프로세스 (전체 CPU%) ---"
  ps -A -o %cpu= -o comm= | sort -rn | head -10 | awk '{printf "%6.1f%%  %s\n", $1, $2}'
  echo ""
  if [ "$SUDO_MODE" = "1" ]; then
    echo "--- powermetrics (시스템 mW, sudo) ---"
    sudo powermetrics -n "$SAMPLES" -i "$((INTERVAL * 1000))" 2>/dev/null \
      | rg "Package Power|Average CPU" | tail -20 || echo "(powermetrics 실패 — sudo 미허용일 수 있음)"
  else
    echo "--- powermetrics 생략 (-p 옵션으로 sudo 전력 측정 활성화 가능) ---"
  fi
} | tee "$OUT"

echo ""
echo "리포트 저장: $OUT"
