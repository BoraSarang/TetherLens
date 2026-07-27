# Bug: 팝오버가 다른 앱 클릭 시 닫히지 않음 (시트 연 후)

## 상태
open · priority=2 · type=bug · created=2026-07-25

## 재현
1. 메뉴바 클릭 → 팝오버 오픈
2. 프로필 편집 클릭 → 시트 오픈
3. 시트 닫기 버튼으로 닫음
4. 다른 앱(Opencode 등) 클릭
5. 팝오버가 사라지지 않음

## 시도한 해결책
- `NSEvent.addGlobalMonitorForEvents` → 팝오버 버튼 이벤트 깨짐
- `NSWorkspace.didActivateApplicationNotification` → 동일하게 버튼 이벤트 깨짐
- `NSApplication.didResignActiveNotification` → 기본 케이스(시트 없이 직접 클릭)는 동작하나 위 재현 케이스에서 실패
- `NSPopover.behavior = .transient` → LSUIElement 앱에서 cross-app close 동작 안 함

## 원인 (추정)
LSUIElement(메뉴바 앱) 특성상 앱 활성화/비활성화 이벤트가 정상 전달되지 않음.
특히 SwiftUI 시트가 열려 있을 때 popover의 event tracking state와 충돌.

## 이후 작업 방향
- NSPopover + LSUIElement 환경에서 cross-app close를 안정적으로 처리하는 방법 연구 필요
- 또는 custom NSWindow 기반 팝오버 구현 고려
