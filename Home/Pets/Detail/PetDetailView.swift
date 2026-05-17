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
    @Namespace private var tabIndicator

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
        GlassEffectContainer {
            HStack(spacing: 0) {
                ForEach(PetDetailTab.allCases, id: \.self) { (tab: PetDetailTab) in
                    let selected = selectedTab == tab
                    Button {
                        withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 15, weight: selected ? .semibold : .regular))
                            Text(tab.rawValue)
                                .font(.caption2)
                                .fontWeight(selected ? .semibold : .regular)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .foregroundStyle(selected ? Color.primary : Color.secondary)
                        .background {
                            if selected {
                                Capsule()
                                    .glassEffect(.regular, in: Capsule())
                                    .matchedGeometryEffect(id: "tab", in: tabIndicator)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .overlay(alignment: .bottom) {
            Divider().opacity(0.3)
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
