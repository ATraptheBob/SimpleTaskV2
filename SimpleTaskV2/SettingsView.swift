import SwiftUI

struct SettingsView: View {
    // Focus Settings
    @AppStorage("pomodoroDuration") private var pomodoroDuration = 25
    @AppStorage("breakDuration") private var breakDuration = 5
    
    @AppStorage("leftSwipeAction") private var leftSwipeAction: SwipeOption = .edit
    @AppStorage("rightSwipeAction") private var rightSwipeAction: SwipeOption = .delete
    
    // Preferences
    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("enableHaptics") private var enableHaptics = true
    @AppStorage("enableSounds") private var enableSounds = true
    
    var body: some View {
        ZStack {
            // Adapts background color based on theme
            (isDarkMode ? Color(white: 0.05) : Color(white: 0.95)).ignoresSafeArea()
            
            Form {
                Section(header: Text("Focus Engine").foregroundColor(.gray)) {
                    Stepper(value: $pomodoroDuration, in: 5...120, step: 5) {
                        HStack {
                            Image(systemName: "timer").foregroundColor(.pink)
                            Text("Focus Length")
                            Spacer()
                            Text("\(pomodoroDuration) min").foregroundColor(.gray)
                        }
                    }
                    
                    Stepper(value: $breakDuration, in: 1...30, step: 1) {
                        HStack {
                            Image(systemName: "cup.and.saucer.fill").foregroundColor(.orange)
                            Text("Break Length")
                            Spacer()
                            Text("\(breakDuration) min").foregroundColor(.gray)
                        }
                    }
                }
                .listRowBackground(isDarkMode ? Color(white: 0.1) : Color.white)
                
                Section(header: Text("Swipe Actions").foregroundColor(.gray)) {
                    Picker("Swipe Right ➡️", selection: $leftSwipeAction) {
                        ForEach(SwipeOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    
                    Picker("Swipe Left ⬅️", selection: $rightSwipeAction) {
                        ForEach(SwipeOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                }
                
                Section(header: Text("Preferences").foregroundColor(.gray)) {
                    Toggle(isOn: $isDarkMode) {
                        HStack {
                            Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                                .foregroundColor(isDarkMode ? .purple : .yellow)
                            Text("Dark Mode")
                        }
                    }
                    
                    Toggle(isOn: $enableHaptics) {
                        HStack {
                            Image(systemName: "hand.tap.fill").foregroundColor(.blue)
                            Text("Haptic Feedback")
                        }
                    }
                    
                    Toggle(isOn: $enableSounds) {
                        HStack {
                            Image(systemName: "speaker.wave.2.fill").foregroundColor(.green)
                            Text("Sound Effects")
                        }
                    }
                }
                .listRowBackground(isDarkMode ? Color(white: 0.1) : Color.white)
                
                Section(header: Text("Data & Privacy").foregroundColor(.gray)) {
                    Button(action: { print("Exporting...") }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up").foregroundColor(.blue)
                            Text("Export Backup").foregroundColor(.blue)
                        }
                    }
                    
                    Button(action: { print("Deleting...") }) {
                        HStack {
                            Image(systemName: "trash").foregroundColor(.red)
                            Text("Erase All Data").foregroundColor(.red)
                        }
                    }
                }
                .listRowBackground(isDarkMode ? Color(white: 0.1) : Color.white)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
    }
}
