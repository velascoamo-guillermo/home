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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(PetDetailTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.caption)
                            Text(tab.rawValue)
                                .font(.caption2)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .foregroundStyle(selectedTab == tab ? .tint : .secondary)
                    }
                    .overlay(alignment: .bottom) {
                        if selectedTab == tab {
                            Rectangle()
                                .frame(height: 2)
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }
        }
        .background(.bar)
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
