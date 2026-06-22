import SwiftUI

enum SwipeOption: String, CaseIterable {
    case edit = "Edit"
    case delete = "Delete"
    case toggle = "Check/Uncheck"
    case date = "Reschedule" // NEW ACTION
    case restore = "Restore"
    case none = "None"
    
    var icon: String {
        switch self {
        case .edit: return "pencil"
        case .delete: return "trash"
        case .toggle: return "checkmark.circle"
        case .date: return "calendar" // NEW
        case .restore: return "arrow.uturn.backward"
        case .none: return ""
        }
    }
    
    var color: Color {
        switch self {
        case .edit: return .blue
        case .delete: return .red
        case .toggle: return .pink
        case .date: return .purple // NEW
        case .restore: return .green
        case .none: return .clear
        }
    }
}
