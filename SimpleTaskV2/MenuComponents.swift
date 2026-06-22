import SwiftUI

struct HamburgerButton: View {
    @Binding var isOpen: Bool
    @AppStorage("isDarkMode") private var isDarkMode = true
    var body: some View {
        Button(action: {
            HapticAndSoundManager.shared.triggerHapticSelection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { isOpen.toggle() }
        }) {
            VStack(spacing: 6) {
                Capsule().fill(isOpen ? AppTheme.accent : (isDarkMode ? Color.gray : Color.black)).frame(width: 24, height: 3).rotationEffect(.degrees(isOpen ? 45 : 0)).offset(y: isOpen ? 9 : 0)
                Capsule().fill(isDarkMode ? Color.gray : Color.black).frame(width: 24, height: 3).opacity(isOpen ? 0 : 1)
                Capsule().fill(isOpen ? AppTheme.accent : (isDarkMode ? Color.gray : Color.black)).frame(width: 24, height: 3).rotationEffect(.degrees(isOpen ? -45 : 0)).offset(y: isOpen ? -9 : 0)
            }
            .frame(width: 44, height: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(isOpen ? "Close Menu" : "Open Menu")
    }
}

struct MenuLink: View {
    let title: String
    let icon: String
    let badgeCount: Int?
    
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    init(title: String, icon: String, badgeCount: Int? = nil) {
        self.title = title
        self.icon = icon
        self.badgeCount = badgeCount
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
            }
            
            Text(title)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(isDarkMode ? .white : .black)
            
            Spacer()
            
            if let count = badgeCount, count > 0 {
                Text("\(count)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.accent)
                    .clipShape(Capsule())
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.gray.opacity(0.5))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}
