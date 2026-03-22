import SwiftUI

struct SettingsView: View {
    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()
            
            List {
                Section(header: Text("Preferences").foregroundColor(.gray)) {
                    HStack {
                        Text("Theme")
                        Spacer()
                        Text("Dark").foregroundColor(.gray)
                    }
                    .listRowBackground(Color(white: 0.1))
                }
                
                Section(header: Text("Data").foregroundColor(.gray)) {
                    Text("Export Data").foregroundColor(.blue)
                }
                .listRowBackground(Color(white: 0.1))
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
    }
}
