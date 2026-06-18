import SwiftUI
import EventKit

struct ReorderListsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var calendarIds: [String]
    let calendars: [EKCalendar]
    let isDarkMode: Bool
    var onSave: ([String]) -> Void
    var isHidden: (String) -> Bool
    var toggleHidden: (String) -> Void
    
    private func calendarFor(id: String) -> EKCalendar? {
        calendars.first(where: { $0.calendarIdentifier == id })
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                (isDarkMode ? Color(white: 0.08) : Color(white: 0.95)).ignoresSafeArea()
                
                List {
                    ForEach(calendarIds, id: \.self) { id in
                        if let cal = calendarFor(id: id) {
                            HStack(spacing: 12) {
                                Button(action: {
                                    toggleHidden(id)
                                }) {
                                    Image(systemName: isHidden(id) ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(isHidden(id) ? .gray : .blue)
                                        .frame(width: 24)
                                }
                                .buttonStyle(.plain)
                                
                                Circle()
                                    .fill(Color(cgColor: cal.cgColor))
                                    .frame(width: 12, height: 12)
                                Text(cal.title)
                                    .foregroundColor(isDarkMode ? .white : .black)
                                    .fontWeight(.medium)
                                    .opacity(isHidden(id) ? 0.5 : 1.0)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onMove { from, to in
                        calendarIds.move(fromOffsets: from, toOffset: to)
                    }
                    .listRowBackground(isDarkMode ? Color(white: 0.12) : Color.white)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, .constant(.active))
            }
            .navigationTitle("Reorder Lists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onSave(calendarIds)
                        dismiss()
                    }
                    .foregroundColor(.pink)
                    .fontWeight(.bold)
                }
            }
        }
    }
}
