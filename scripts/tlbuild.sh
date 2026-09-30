#!/bin/zsh
# swift build 출력을 읽을 수 있게 압축한다.
# 컴파일러가 붙이는 수천 자짜리 커맨드라인을 걸러 실제 진단만 남긴다.
cd "$(dirname "$0")/.." || exit 1
swift build 2>&1 \
  | grep -v "swift-frontend" \
  | grep -vE "^\s*\|" \
  | grep -vE "^\s*[0-9]+ \|" \
  | grep -E "error:|warning:|Build complete|Build failed|Compiling|\[[0-9]+ ?/ ?[0-9]+\]" \
  | grep -vE "warning: .*(NoUsage|VariableNeverMutated)\]" \
  | sed -E 's/\[1;3[0-9]m//g; s/\[0m//g' \
  | uniq
