import SwiftUI

// MARK: - Centralized Design Tokens
// All colors, spacing, and radii live here.
// Every view should reference AppTheme instead of hardcoding colors.

enum AppTheme {
    
    // MARK: - Vibrant Accent Palette
    // Highly saturated and bright — sharp and vibrant.
    
    /// Vibrant pink
    static let matteRose   = Color(hue: 0.92, saturation: 0.85, brightness: 1.0)
    
    /// Vibrant yellow/amber
    static let matteAmber  = Color(hue: 0.12, saturation: 0.90, brightness: 1.0)
    
    /// Vibrant indigo/purple
    static let matteSlate  = Color(hue: 0.70, saturation: 0.80, brightness: 1.0)
    
    /// Vibrant cyan/green
    static let matteTeal   = Color(hue: 0.45, saturation: 0.85, brightness: 1.0)
    
    /// Vibrant red
    static let matteRed    = Color(hue: 0.0, saturation: 0.85, brightness: 1.0)
    
    /// Vibrant bright blue (toned down slightly)
    static let matteBlue   = Color(hue: 0.58, saturation: 0.70, brightness: 0.95)
    
    // MARK: - Surface Colors (Dark Mode)
    
    /// Main background — pure black
    static let surfacePrimary   = Color.black
    
    /// Cards, elevated containers — very dark gray
    static let surfaceSecondary = Color(white: 0.10)
    
    /// Input fields, nested elements
    static let surfaceTertiary  = Color(white: 0.16)
    
    // MARK: - Surface Colors (Light Mode)
    
    /// Main background — warm off-white
    static let lightSurfacePrimary   = Color(hue: 0.08, saturation: 0.04, brightness: 0.97)
    
    /// Cards, elevated containers
    static let lightSurfaceSecondary = Color(white: 0.93)
    
    /// Input fields, nested elements
    static let lightSurfaceTertiary  = Color(white: 0.88)
    
    // MARK: - Adaptive Helpers
    
    /// Returns the appropriate surface color for the current color scheme.
    static func surface(_ level: SurfaceLevel, isDark: Bool) -> Color {
        switch (level, isDark) {
        case (.primary, true):   return surfacePrimary
        case (.primary, false):  return lightSurfacePrimary
        case (.secondary, true):  return surfaceSecondary
        case (.secondary, false): return lightSurfaceSecondary
        case (.tertiary, true):   return surfaceTertiary
        case (.tertiary, false):  return lightSurfaceTertiary
        }
    }
    
    /// Primary accent color (vibrant blue).
    static let accent = matteBlue
    
    // MARK: - Shadows (No Glows)
    // Neutral-only shadows. Never colored.
    
    /// Subtle lift for cards
    static func shadowLight() -> some ViewModifier {
        NeutralShadow(radius: 4, y: 2, opacity: 0.10)
    }
    
    /// Medium elevation for popups
    static func shadowMedium() -> some ViewModifier {
        NeutralShadow(radius: 8, y: 4, opacity: 0.15)
    }
    
    // MARK: - Corner Radii
    
    /// Small interactive elements (badges, chips)
    static let radiusSmall: CGFloat = 8
    
    /// Standard cards and containers
    static let radiusMedium: CGFloat = 14
    
    /// Large cards, sheets, popups
    static let radiusLarge: CGFloat = 20
    
    // MARK: - Spacing
    
    /// Tight spacing inside components
    static let spacingTight: CGFloat = 8
    
    /// Default spacing between elements
    static let spacingDefault: CGFloat = 16
    
    /// Generous spacing between sections
    static let spacingLoose: CGFloat = 24
}

// MARK: - Supporting Types

enum SurfaceLevel {
    case primary, secondary, tertiary
}

struct NeutralShadow: ViewModifier {
    let radius: CGFloat
    let y: CGFloat
    let opacity: Double
    
    func body(content: Content) -> some View {
        content.shadow(color: .black.opacity(opacity), radius: radius, x: 0, y: y)
    }
}

// MARK: - View Extensions

extension View {
    /// Applies a neutral, non-glowing shadow.
    func neutralShadow(radius: CGFloat = 4, y: CGFloat = 2, opacity: Double = 0.10) -> some View {
        self.shadow(color: .black.opacity(opacity), radius: radius, x: 0, y: y)
    }
    
    /// Standard card background with adaptive surface color and corner radius.
    func cardStyle(isDark: Bool, level: SurfaceLevel = .secondary) -> some View {
        self
            .background(AppTheme.surface(level, isDark: isDark))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous))
    }
}
