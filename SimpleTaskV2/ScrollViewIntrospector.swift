internal import Combine

import SwiftUI
import UIKit

struct ScrollViewAutoScroller: ViewModifier {
    var isScrollingUp: Bool
    var isScrollingDown: Bool
    var speed: CGFloat = 8
    var onOffsetChange: ((CGFloat) -> Void)? = nil
    
    @State private var scrollView: UIScrollView?
    
    func body(content: Content) -> some View {
        content
            .background(ScrollViewIntrospector(scrollView: $scrollView, onOffsetChange: onOffsetChange))
            .onReceive(Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()) { _ in
                guard let scrollView = scrollView else { return }
                
                if isScrollingUp {
                    var newOffset = scrollView.contentOffset
                    newOffset.y -= speed
                    
                    let minOffsetY = -scrollView.adjustedContentInset.top
                    if newOffset.y < minOffsetY {
                        newOffset.y = minOffsetY
                    }
                    
                    if scrollView.contentOffset.y != newOffset.y {
                        scrollView.setContentOffset(newOffset, animated: false)
                    }
                } else if isScrollingDown {
                    var newOffset = scrollView.contentOffset
                    newOffset.y += speed
                    
                    let maxOffsetY = max(-scrollView.adjustedContentInset.top, scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom)
                    if newOffset.y > maxOffsetY {
                        newOffset.y = maxOffsetY
                    }
                    
                    if scrollView.contentOffset.y != newOffset.y {
                        scrollView.setContentOffset(newOffset, animated: false)
                    }
                }
            }
    }
}

extension View {
    func autoScroll(isScrollingUp: Bool, isScrollingDown: Bool, speed: CGFloat = 8, onOffsetChange: ((CGFloat) -> Void)? = nil) -> some View {
        self.modifier(ScrollViewAutoScroller(isScrollingUp: isScrollingUp, isScrollingDown: isScrollingDown, speed: speed, onOffsetChange: onOffsetChange))
    }
}

private struct ScrollViewIntrospector: UIViewRepresentable {
    @Binding var scrollView: UIScrollView?
    var onOffsetChange: ((CGFloat) -> Void)?

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            self.scrollView = findScrollView(in: view)
            if let scv = self.scrollView, let callback = self.onOffsetChange {
                context.coordinator.setupKVO(on: scv, callback: callback)
            }
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if scrollView == nil {
            DispatchQueue.main.async {
                self.scrollView = findScrollView(in: uiView)
                if let scv = self.scrollView, let callback = self.onOffsetChange {
                    context.coordinator.setupKVO(on: scv, callback: callback)
                }
            }
        }
    }

    private func findScrollView(in view: UIView) -> UIScrollView? {
        var current: UIView? = view
        while let superview = current?.superview {
            if let scrollView = superview as? UIScrollView {
                return scrollView
            }
            current = superview
        }
        return nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject {
        private var observer: NSKeyValueObservation?

        func setupKVO(on scrollView: UIScrollView, callback: @escaping (CGFloat) -> Void) {
            observer?.invalidate()
            observer = scrollView.observe(\.contentOffset, options: [.new]) { scrollView, _ in
                // Using a small delay or dispatch async so it doesn't interrupt state
                DispatchQueue.main.async {
                    callback(scrollView.contentOffset.y)
                }
            }
        }

        deinit {
            observer?.invalidate()
        }
    }
}
