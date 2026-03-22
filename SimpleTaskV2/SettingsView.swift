import SwiftUI

struct SettingsView: View {
    // This automatically saves to the device and updates globally
    @AppStorage("pomodoroDuration") private var pomodoroDuration = 25

    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()
            
            Form {
                Section(header: Text("Focus Timer").foregroundColor(.gray)) {
                    Stepper(value: $pomodoroDuration, in: 5...120, step: 5) {
                        HStack {
                            Image(systemName: "timer").foregroundColor(.pink)
                            Text("Session Length")
                            Spacer()
                            Text("\(pomodoroDuration) min").foregroundColor(.gray)
                        }
                    }
                }
                .listRowBackground(Color(white: 0.1))
                
                Section(header: Text("App Data").foregroundColor(.gray)) {
                    Text("Export Backup").foregroundColor(.blue)
                }
                .listRowBackground(Color(white: 0.1))
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
    }
}
