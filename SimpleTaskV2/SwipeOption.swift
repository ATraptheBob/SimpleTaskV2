import SwiftUI

enum SwipeOption: String, CaseIterable {
    case edit = "Edit"
    case delete = "Delete"
    case toggle = "Check/Uncheck"
    case none = "None"
    
    // Automatically assigns the correct icon for the menu
    var icon: String {
        switch self {
        case .edit: return "pencil"
        case .delete: return "trash"
        case .toggle: return "checkmark.circle"
        case .none: return ""
        }
    }
    
    // Automatically assigns the native iOS colors
    var color: Color {
        switch self {
        case .edit: return .blue
        case .delete: return .red
        case .toggle: return .pink
        case .none: return .clear
        }
    }
}
