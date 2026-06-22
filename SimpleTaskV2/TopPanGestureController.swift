import SwiftUI
import UIKit

struct TopPanGestureController: UIViewControllerRepresentable {
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: (CGFloat) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        vc.view.isUserInteractionEnabled = false
        
        DispatchQueue.main.async {
            let pan = context.coordinator.pan
            if let parentView = vc.parent?.view ?? vc.view.window {
                parentView.addGestureRecognizer(pan)
            }
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: Coordinator) {
        if let parentView = uiViewController.parent?.view ?? uiViewController.view.window {
            parentView.removeGestureRecognizer(coordinator.pan)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDragChanged: onDragChanged, onDragEnded: onDragEnded)
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let onDragChanged: (CGFloat) -> Void
        let onDragEnded: (CGFloat) -> Void
        
        lazy var pan: UIPanGestureRecognizer = {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.delegate = self
            return pan
        }()

        init(onDragChanged: @escaping (CGFloat) -> Void, onDragEnded: @escaping (CGFloat) -> Void) {
            self.onDragChanged = onDragChanged
            self.onDragEnded = onDragEnded
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view else { return }
            let translation = gesture.translation(in: view).y
            if gesture.state == .changed {
                // Only report positive (downward) translation
                if translation > 0 {
                    onDragChanged(translation)
                }
            } else if gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed {
                onDragEnded(translation)
            }
        }
        
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer, let view = pan.view else { return false }
            let location = pan.location(in: view)
            let velocity = pan.velocity(in: view)
            
            // Start if in top 120 points and dragging mostly downwards
            if location.y < 120 && velocity.y > abs(velocity.x) && velocity.y > 0 {
                return true
            }
            return false
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Prevent other scrollviews from stealing if we are paning down from top
            return false
        }
    }
}
