import SwiftUI

struct PlanView: View {
    @EnvironmentObject var viewModel: WatchMainViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.planItems.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("План на сегодня пуст")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else {
                    ForEach(Array(viewModel.planItems.enumerated()), id: \.offset) { index, item in
                        PlanItemRow(item: item, index: index)
                    }
                }
                
                // Мотивационный лозунг
                if !viewModel.motivationalSlogan.isEmpty {
                    Divider()
                        .padding(.vertical, 8)
                    
                    Text(viewModel.motivationalSlogan)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding()
        }
        .navigationTitle("План на день")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.refreshData()
        }
    }
}

struct PlanItemRow: View {
    let item: String
    let index: Int
    
    var body: some View {
        HStack(spacing: 8) {
            Text("\(index + 1).")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            Text(item)
                .font(.body)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

