import SwiftUI

struct SwipeRowModifier: ViewModifier {
    let leftOption: SwipeOption
    let rightOption: SwipeOption
    let onLeftSwipe: () -> Void
    let onRightSwipe: () -> Void

    @State private var offset: CGFloat = 0
    @State private var triggered = false
    @State private var dragDirectionDetermined = false
    @State private var isHorizontalDrag = false
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
                            .mask(
                                ZStack {
                                    HStack {
                                        Rectangle()
                                            .frame(width: max(offset + 16, 0))
                                        Spacer()
                                    }
                                    RoundedRectangle(cornerRadius: offset != 0 ? 16 : 0)
                                        .offset(x: offset)
                                        .blendMode(.destinationOut)
                                }
                                .compositingGroup()
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
                            .mask(
                                ZStack {
                                    HStack {
                                        Spacer()
                                        Rectangle()
                                            .frame(width: max(-offset + 16, 0))
                                    }
                                    RoundedRectangle(cornerRadius: offset != 0 ? 16 : 0)
                                        .offset(x: offset)
                                        .blendMode(.destinationOut)
                                }
                                .compositingGroup()
                            )
                    }
                }
            }

            content
                .background(Color.clear)
                .contentShape(Rectangle())
                .clipShape(RoundedRectangle(cornerRadius: offset != 0 ? 16 : 0))
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 15)
                        .onChanged { value in
                            if !dragDirectionDetermined {
                                dragDirectionDetermined = true
                                isHorizontalDrag = abs(value.translation.width) > abs(value.translation.height) * 1.5
                            }
                            
                            guard isHorizontalDrag else { return }
                            
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
                            dragDirectionDetermined = false
                            guard isHorizontalDrag else { return }
                            
                            withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) {
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
