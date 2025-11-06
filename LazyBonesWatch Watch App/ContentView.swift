import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: WatchMainViewModel
    
    var body: some View {
        NavigationStack {
            MainWatchView()
                .environmentObject(viewModel)
        }
    }
}

