import SwiftUI

struct ContentView: View {
    @State var items = ["A", "B", "C"]
    var body: some View {
        List {
            ForEach(items, id: \.self) { item in
                Section(header: Text(item)) {
                    Text("Row 1")
                }
            }
            .onMove { indices, newOffset in
                items.move(fromOffsets: indices, toOffset: newOffset)
            }
        }
    }
}
