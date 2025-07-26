import SwiftUI

struct ProgressBarGoodBadView: View {
    let goodCount: Int
    let badCount: Int
    
    var total: Int { goodCount + badCount }
    var badRatio: CGFloat { total > 0 ? CGFloat(badCount) / CGFloat(total) : 0 }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 24) {
                VStack(spacing: 2) {
                    Text("\(goodCount)")
                        .font(.custom("Georgia-Bold", size: 45))
                        .foregroundColor(.green)
                    Text("молодец")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                VStack(spacing: 2) {
                    Text("\(badCount)")
                        .font(.custom("Georgia-Bold", size: 45))
                        .foregroundColor(.red)
                    Text("лаботряс")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.systemGray4))
                            .frame(height: 10)
                        if badCount > 0 {
                            Capsule()
                                .fill(Color.red)
                                .frame(width: geo.size.width * badRatio, height: 10)
                                .position(x: geo.size.width * (1 - badRatio) + (geo.size.width * badRatio) / 2, y: 5)
                            Circle()
                                .fill(Color.red)
                                .frame(width: 18, height: 18)
                                .position(x: geo.size.width * (1 - badRatio) + geo.size.width * badRatio, y: 5)
                                .shadow(color: Color.red.opacity(0.3), radius: 2, x: 0, y: 1)
                        }
                    }
                }
                .frame(height: 18)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

#Preview {
    VStack(spacing: 32) {
        ProgressBarGoodBadView(goodCount: 2, badCount: 4)
        ProgressBarGoodBadView(goodCount: 4, badCount: 2)
        ProgressBarGoodBadView(goodCount: 0, badCount: 1)
        ProgressBarGoodBadView(goodCount: 1, badCount: 12)
        ProgressBarGoodBadView(goodCount: 3, badCount: 0)
        ProgressBarGoodBadView(goodCount: 0, badCount: 0)
    }
    .padding()
    .background(Color(.systemGray6))
}
