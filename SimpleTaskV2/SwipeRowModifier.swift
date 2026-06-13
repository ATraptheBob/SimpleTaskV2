import SwiftUI

struct SwipeRowModifier: ViewModifier {
    let leftOption: SwipeOption
    let rightOption: SwipeOption
    let onLeftSwipe: () -> Void
    let onRightSwipe: () -> Void

    @State private var offset: CGFloat = 0
    @State private var triggered = false
    @AppStorage("isDarkMode") private var isDarkMode = true

    private let triggerThreshold: CGFloat = 40

    func body(content: Content) -> some View {
        ZStack {
            GeometryReader { geo in
                ZStack {
                    if offset > 0 {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(leftOption.color)
                            .overlay(
                                HStack {
                                    Image(systemName: leftOption.icon)
                                        .font(.title3.bold())
                                        .foregroundColor(.white)
                                        .scaleEffect(offset > triggerThreshold ? 1.2 : 0.8)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: offset > triggerThreshold)
                                        .padding(.leading, 20)
                                    Spacer()
                                }
                            )
                    }

                    if offset < 0 {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(rightOption.color)
                            .overlay(
                                HStack {
                                    Spacer()
                                    Image(systemName: rightOption.icon)
                                        .font(.title3.bold())
                                        .foregroundColor(.white)
                                        .scaleEffect(offset < -triggerThreshold ? 1.2 : 0.8)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: offset < -triggerThreshold)
                                        .padding(.trailing, 20)
                                }
                            )
                    }
                }
            }

            content
                .background(isDarkMode ? Color.black : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 30)
                        .onChanged { value in
                            let drag = value.translation.width
                            offset = drag > 0 ? pow(drag, 0.9) : -pow(-drag, 0.9)

                            if offset > triggerThreshold && !triggered && leftOption != .none {
                                HapticAndSoundManager.shared.triggerHapticSelection()
                                triggered = true
                            } else if offset < -triggerThreshold && !triggered && rightOption != .none {
                                HapticAndSoundManager.shared.triggerHapticSelection()
                                triggered = true
                            } else if abs(offset) < triggerThreshold {
                                triggered = false
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                if offset > triggerThreshold && leftOption != .none {
                                    onLeftSwipe()
                                } else if offset < -triggerThreshold && rightOption != .none {
                                    onRightSwipe()
                                }
                                offset = 0
                                triggered = false
                            }
                        }
                )
        }
    }
}

extension View {
    func customSwipeActions(left: SwipeOption, right: SwipeOption, onLeft: @escaping () -> Void, onRight: @escaping () -> Void) -> some View {
        self.modifier(SwipeRowModifier(leftOption: left, rightOption: right, onLeftSwipe: onLeft, onRightSwipe: onRight))
    }
}
