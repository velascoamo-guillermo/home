import SwiftUI

enum PetDetailTab: String, CaseIterable {
    case vet = "Vet"
    case appointments = "Appointments"
    case history = "History"
    case events = "Events"
    case files = "Files"

    var icon: String {
        switch self {
        case .vet:          return "stethoscope"
        case .appointments: return "calendar"
        case .history:      return "clock.arrow.circlepath"
        case .events:       return "list.bullet"
        case .files:        return "folder"
        }
    }
}

struct PetDetailView: View {
    let pet: Pet
    @State private var selectedTab: PetDetailTab = .vet

    var body: some View {
        VStack(spacing: 0) {
            petHeader
            tabPicker
            tabContent
        }
        .navigationTitle(pet.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var petHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: pet.type == "Dog" ? "dog.fill" : "cat.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text(pet.name)
                .font(.title2.bold())
            Text("\(pet.breed) · \(pet.type)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 16)
    }

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(PetDetailTab.allCases, id: \.self) { tab in
                let selected = selectedTab == tab
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 15, weight: selected ? .semibold : .regular))
                        Text(tab.rawValue)
                            .font(.caption2)
                            .fontWeight(selected ? .semibold : .regular)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                }
                .overlay(alignment: .bottom) {
                    if selected {
                        Rectangle()
                            .frame(height: 2)
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .vet:          VetTabView(pet: pet)
        case .appointments: AppointmentsTabView(pet: pet)
        case .history:      ClinicalHistoryTabView(pet: pet)
        case .events:       EventsTabView(pet: pet)
        case .files:        FilesTabView(pet: pet)
        }
    }
}

#Preview {
    NavigationStack {
        PetDetailView(pet: Pet(name: "Luna", type: "Dog", breed: "Golden Retriever"))
    }
    .environment(DataStore())
}
