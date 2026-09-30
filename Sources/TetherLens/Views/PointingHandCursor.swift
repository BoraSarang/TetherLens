import SwiftUI
import AppKit

/// hover 진입 시 손가락 커서를 push 하고, **이탈하거나 뷰가 사라질 때** pop 한다.
///
/// `onHover(false)` 는 마우스가 뷰 밖으로 나갈 때만 오고, 뷰가 제거되면 오지 않는다.
/// 즉 pop 없이 push 만 남으면 커서 스택이 점점 쌓여 나중에 **앱 전체**에서
/// 손가락 커서가 고정된다 (T-250 #11).
///
/// push/pop 횟수를 `@State` 로 짝지어 짝이 어긋나지 않게 한다.
struct PointingHandCursor: ViewModifier {
    /// 지금 push 된 상태인가. `pop()` 은 이 값이 true 일 때만 호출한다
    /// (스택 언더플로우로 다른 뷰의 커서를 밀어내는 것을 막는다).
    @State private var isPushed = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                if inside, !isPushed {
                    NSCursor.pointingHand.push()
                    isPushed = true
                } else if !inside, isPushed {
                    NSCursor.pop()
                    isPushed = false
                }
            }
            .onDisappear {
                // hover-out 없이 뷰가 사라지는 경우 — 남은 push 를 되돌린다
                if isPushed {
                    NSCursor.pop()
                    isPushed = false
                }
            }
    }
}

extension View {
    /// 클릭 가능한 요소에 손가락 커서를 붙인다
    func pointingHandCursor() -> some View {
        modifier(PointingHandCursor())
    }

    /// 조건부 손가락 커서 — `isOn` 이 false 면 커서를 건드리지 않는다
    func pointingHandCursor(isOn: Bool) -> some View {
        modifier(OptionalPointingHand(isOn: isOn))
    }
}

/// 조건부 적용 — `isOn` 이 false 면 아예 커서를 건드리지 않는다.
/// (동적으로 클릭 가능/불가능이 바뀌는 요소용)
struct OptionalPointingHand: ViewModifier {
    let isOn: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isOn {
            content.modifier(PointingHandCursor())
        } else {
            content
        }
    }
}
