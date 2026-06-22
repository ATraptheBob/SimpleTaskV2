import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var dragOffset: CGFloat = 0
    
    // Global Search State
    @State private var showGlobalSearch = false
    @State private var topDragOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            
            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    ZStack(alignment: .bottom) {
                        HStack(spacing: 0) {
                            InboxView()
                                .frame(width: geometry.size.width)
                                .clipped()
                            
                            HabitsView()
                                .frame(width: geometry.size.width)
                                .clipped()
                            
                            TimerView()
                                .frame(width: geometry.size.width)
                                .clipped()
                        }
                        .frame(width: geometry.size.width, alignment: .leading)
                        .offset(x: -CGFloat(selectedTab) * geometry.size.width + dragOffset)
                        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: dragOffset)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab)
                        
                        // Invisible overlay to catch edge swipes using UIKit
                        EdgeSwipeController { translation in
                            // Apply resistance if trying to swipe past the ends
                            if (selectedTab == 0 && translation > 0) || (selectedTab == 2 && translation < 0) {
                                dragOffset = translation * 0.3
                            } else {
                                dragOffset = translation
                            }
                        } onDragEnded: { translation in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                let threshold = geometry.size.width * 0.3
                                if translation < -threshold && selectedTab < 2 {
                                    selectedTab += 1
                                } else if translation > threshold && selectedTab > 0 {
                                    selectedTab -= 1
                                }
                                dragOffset = 0
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(width: geometry.size.width)
                    
                    TopPanGestureController { translation in
                        topDragOffset = translation
                    } onDragEnded: { translation in
                        if translation > 60 {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showGlobalSearch = true
                                topDragOffset = 0
                            }
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                topDragOffset = 0
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    if showGlobalSearch {
                        GlobalSearchView(isPresented: $showGlobalSearch)
                            .transition(.opacity)
                            .zIndex(100)
                    } else if topDragOffset > 0 {
                        Color.black.opacity(Double(min(topDragOffset / 200.0, 0.5)))
                            .ignoresSafeArea()
                            .zIndex(99)
                    }
                }
            }
            .ignoresSafeArea()
            
            // Interactive Page Indicator Pill
            PageIndicatorPill(selectedTab: $selectedTab, totalTabs: 3)
                .padding(.bottom, 16)
        }
    }
}

struct EdgeSwipeController: UIViewControllerRepresentable {
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: (CGFloat) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        vc.view.isUserInteractionEnabled = false // Allow touches to pass through
        
        DispatchQueue.main.async {
            let leftPan = context.coordinator.leftPan
            let rightPan = context.coordinator.rightPan
            
            if let parentView = vc.parent?.view ?? vc.view.window {
                parentView.addGestureRecognizer(leftPan)
                parentView.addGestureRecognizer(rightPan)
            }
        }
        
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: Coordinator) {
        if let parentView = uiViewController.parent?.view ?? uiViewController.view.window {
            parentView.removeGestureRecognizer(coordinator.leftPan)
            parentView.removeGestureRecognizer(coordinator.rightPan)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDragChanged: onDragChanged, onDragEnded: onDragEnded)
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let onDragChanged: (CGFloat) -> Void
        let onDragEnded: (CGFloat) -> Void
        
        lazy var leftPan: UIScreenEdgePanGestureRecognizer = {
            let pan = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.edges = .left
            pan.delegate = self
            return pan
        }()
        
        lazy var rightPan: UIScreenEdgePanGestureRecognizer = {
            let pan = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.edges = .right
            pan.delegate = self
            return pan
        }()

        init(onDragChanged: @escaping (CGFloat) -> Void, onDragEnded: @escaping (CGFloat) -> Void) {
            self.onDragChanged = onDragChanged
            self.onDragEnded = onDragEnded
        }

        @objc func handlePan(_ gesture: UIScreenEdgePanGestureRecognizer) {
            guard let view = gesture.view else { return }
            let translation = gesture.translation(in: view).x
            if gesture.state == .changed {
                onDragChanged(translation)
            } else if gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed {
                onDragEnded(translation)
            }
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return false
        }
    }
}
