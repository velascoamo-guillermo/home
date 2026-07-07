import SwiftUI
import Charts

struct WeightTabView: View {
    let pet: Pet
    @Environment(SupabaseStore.self) private var store
    @State private var showAdd = false

    var entries: [WeightEntry] { store.weightEntries(for: pet.id) }

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView("No Weight Entries", systemImage: "scalemass",
                    description: Text("Tap + to log a weight."))
                    .listRowBackground(Color.clear)
            }
            if entries.count >= 2 {
                Section {
                    chart
                        .frame(height: 220)
                        .padding(.vertical, 8)
                }
            }
            ForEach(entries) { entry in
                HStack {
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    Spacer()
                    Text(entry.weightKg.formatted(.number.precision(.fractionLength(0...1))) + " kg")
                        .font(.headline)
                }
                .contextMenu {
                    Button(role: .destructive) {
                        Task { try? await store.deleteWeightEntry(entry) }
                    } label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add", systemImage: "plus") { showAdd = true }
            }
        }
        .sheet(isPresented: $showAdd) { AddWeightEntrySheet(petId: pet.id) }
    }

    private var chart: some View {
        Chart(entries.sorted { $0.date < $1.date }) { entry in
            LineMark(
                x: .value("Date", entry.date),
                y: .value("Weight", entry.weightKg)
            )
            PointMark(
                x: .value("Date", entry.date),
                y: .value("Weight", entry.weightKg)
            )
        }
        .chartYAxisLabel("kg")
    }
}
