import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var googleWorkspace = GoogleWorkspaceManager.shared

    // Focus Settings
    @AppStorage("pomodoroDuration") private var pomodoroDuration = 25
    @AppStorage("breakDuration") private var breakDuration = 5
    
    @AppStorage("archiveSetting") private var archiveSetting: String = "Midnight"
    
    // Swipe Settings
    @AppStorage("leftSwipeAction") private var leftSwipeAction: SwipeOption = .edit
    @AppStorage("rightSwipeAction") private var rightSwipeAction: SwipeOption = .delete
    
    // Preferences
    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("enableHaptics") private var enableHaptics = true
    @AppStorage("enableSounds") private var enableSounds = true
    @AppStorage("useDynamicBackground") private var useDynamicBackground = true
    @AppStorage("geminiApiKey") private var geminiApiKey: String = ""
    // Alerts
    @State private var showingEraseConfirmation = false
    
    // Sync
    @AppStorage("syncIntervalMinutes") private var syncIntervalMinutes: Int = 30

    var body: some View {
        ZStack {
            DynamicBackgroundView()
            
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
                            Image(systemName: "cup.and.saucer.fill").foregroundColor(.green)
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
                .listRowBackground(isDarkMode ? Color(white: 0.1) : Color.white)
                
                Section(header: Text("Preferences").foregroundColor(.gray)) {
                    Toggle(isOn: $isDarkMode) {
                        HStack {
                            Image(systemName: "moon.fill").foregroundColor(.indigo)
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
                    
                    Toggle(isOn: $useDynamicBackground) {
                        HStack {
                            Image(systemName: "sparkles").foregroundColor(.pink)
                            Text("Dynamic Background")
                        }
                    }
                }
                .listRowBackground(isDarkMode ? Color(white: 0.1) : Color.white)
                
                Section(header: Text("Sync").foregroundColor(.gray)) {
                    Picker(selection: $syncIntervalMinutes) {
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("1 hour").tag(60)
                        Text("2 hours").tag(120)
                        Text("Manual only").tag(0)
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath").foregroundColor(.blue)
                            Text("Auto-Sync Interval")
                        }
                    }
                    .onChange(of: syncIntervalMinutes) { _, newValue in
                        if newValue > 0 {
                            EventKitManager.shared.syncIntervalMinutes = newValue
                            EventKitManager.shared.restartSyncTimer()
                        } else {
                            EventKitManager.shared.syncIntervalMinutes = 0
                            // Stop timer by setting a very large value — or just invalidate
                            EventKitManager.shared.restartSyncTimer()
                        }
                    }
                    
                    Button(action: {
                        Task {
                            await EventKitManager.shared.loadData()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise").foregroundColor(.green)
                            Text("Sync Now")
                        }
                    }
                }
                .listRowBackground(isDarkMode ? Color(white: 0.1) : Color.white)
                
                Section(header: Text("Integrations").foregroundColor(.gray)) {
                    HStack {
                        Image(systemName: "envelope.fill").foregroundColor(.blue)
                        Text("Google Workspace")
                        Spacer()
                        if googleWorkspace.isSignedIn {
                            Text("Connected")
                                .font(.caption)
                                .foregroundColor(.green)
                            Button("Sign Out") {
                                googleWorkspace.signOut()
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        } else {
                            Button("Sign In") {
                                Task {
                                    try? await googleWorkspace.signIn()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "sparkles").foregroundColor(.pink)
                        SecureField("Gemini API Key", text: $geminiApiKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                .listRowBackground(isDarkMode ? Color(white: 0.1) : Color.white)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .toolbar(.hidden, for: .tabBar)
    }
}
