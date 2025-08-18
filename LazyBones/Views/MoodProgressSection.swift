import SwiftUI

struct MoodProgressSection: View {
    let goodCount: Int
    let badCount: Int
    
    var body: some View {
        MercuryThermometerView(goodCount: goodCount, badCount: badCount)
    }
}

#Preview {
    MoodProgressSection(goodCount: 3, badCount: 1)
}
