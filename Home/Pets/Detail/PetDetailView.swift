import SwiftUI
import PhotosUI
import UIKit

struct PetDetailView: View {
    let pet: Pet
    @Environment(SupabaseStore.self) private var store
    @State private var photoPickerItem: PhotosPickerItem? = nil
    @State private var isUploadingPhoto = false
    @State private var uploadError: String? = nil
    @State private var selectedSection: PetSection?
    @State private var showAddAppointment = false
    @State private var showAddEvent = false
    @State private var heroImage: UIImage?

    private static let heroHeight: CGFloat = 380

    private var currentPet: Pet {
        store.pets.first(where: { $0.id == pet.id }) ?? pet
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                content
            }
        }
        .scrollIndicators(.hidden)
        .gradientCanvas()
        .ignoresSafeArea(.container, edges: .top)
        .task(id: currentPet.photoUrl) { await loadHero() }
        .sheet(item: $selectedSection) { section in
            NavigationStack {
                switch section {
                case .vet:          VetTabView(pet: currentPet)
                case .appointments: AppointmentsTabView(pet: currentPet)
                case .history:      ClinicalHistoryTabView(pet: currentPet)
                case .events:       EventsTabView(pet: currentPet)
                case .weight:       WeightTabView(pet: currentPet)
                case .files:        FilesTabView(pet: currentPet)
                }
            }
            .navigationTitle(section.title)
        }
        .sheet(isPresented: $showAddAppointment) { AddAppointmentSheet(petId: currentPet.id) }
        .sheet(isPresented: $showAddEvent) { AddEventSheet(petId: currentPet.id) }
        .toolbarBackground(.hidden, for: .navigationBar)
        .onChange(of: photoPickerItem) { _, item in
            guard let item else { return }
            Task { await uploadPhoto(item) }
        }
        .alert("Upload Failed", isPresented: Binding(
            get: { uploadError != nil },
            set: { if !$0 { uploadError = nil } }
        )) {
            Button("OK") { uploadError = nil }
        } message: {
            if let msg = uploadError { Text(msg) }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        Group {
            if let img = heroImage {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Rectangle().fill(Palette.pets)
                    .overlay {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Palette.accent.opacity(0.5))
                            .accessibilityHidden(true)
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.heroHeight)
        .clipped()
        // Fade to transparent so the gradient canvas shows through instead of a flat tint.
        .mask(alignment: .top) {
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0.45),
                    .init(color: .black.opacity(0.6), location: 0.7),
                    .init(color: .black.opacity(0.15), location: 0.9),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: Self.heroHeight)
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 24) {
            titleBlock
            actionRow
            if let next = PetDetailSummary.nextAppointment(store.appointments(for: currentPet.id), now: .now) {
                nextUpCard(next)
            }
            sectionGrid
        }
        .padding(.horizontal, 20)
        .padding(.top, -48)
        .padding(.bottom, 32)
    }

    private var titleBlock: some View {
        let age = PetDetailSummary.ageText(birthday: currentPet.birthday, now: .now, calendar: .current)
        let weight = PetDetailSummary.weightText(store.weightEntries(for: currentPet.id))
        return VStack(spacing: 10) {
            Text(currentPet.name)
                .font(.largeTitle.bold())
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
            Text("\(currentPet.breed) · \(currentPet.type)")
                .font(.title3)
                .foregroundStyle(Palette.inkSecondary)
            if age != nil || weight != nil {
                HStack(spacing: 8) {
                    if let age { infoPill(age, systemImage: "birthday.cake") }
                    if let weight { infoPill(weight, systemImage: "scalemass") }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func infoPill(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.footnote.weight(.medium))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Palette.surface, in: .capsule)
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            Chip(title: "Appointment", systemImage: "plus", fill: Palette.pets, isSelected: false) {
                showAddAppointment = true
            }
            Chip(title: "Event", systemImage: "plus", fill: Palette.tasks, isSelected: false) {
                showAddEvent = true
            }
            if isUploadingPhoto {
                ProgressView()
                    .frame(width: 44, height: 38)
            } else {
                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    Image(systemName: "camera.fill")
                }
                .buttonStyle(ChipButtonStyle(fill: Palette.stock, isSelected: false))
                .accessibilityLabel("Change pet photo")
            }
        }
        .foregroundStyle(Palette.ink)
    }

    private func nextUpCard(_ appointment: Appointment) -> some View {
        Button { selectedSection = .appointments } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(Palette.pets)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "stethoscope")
                            .foregroundStyle(Palette.ink)
                    }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("NEXT UP")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.inkSecondary)
                    Text(appointment.reason.isEmpty ? "Appointment" : appointment.reason)
                        .font(.headline)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Text(appointment.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkSecondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(Palette.inkSecondary)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .background(Palette.surface, in: .rect(cornerRadius: 20))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var sectionGrid: some View {
        TileGrid {
            ForEach(PetSection.allCases) { section in
                Button { selectedSection = section } label: {
                    Tile(title: section.title, systemImage: section.icon,
                         fill: section.fill, badge: count(for: section))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func count(for section: PetSection) -> Int? {
        switch section {
        case .vet:          return nil
        case .appointments: return store.appointments(for: currentPet.id).count
        case .history:      return store.clinicalEntries(for: currentPet.id).count
        case .events:       return store.events(for: currentPet.id).count
        case .weight:       return store.weightEntries(for: currentPet.id).count
        case .files:        return store.files(for: currentPet.id).count
        }
    }

    // MARK: - Side effects

    private func loadHero() async {
        guard let urlStr = currentPet.photoUrl, let url = URL(string: urlStr) else {
            heroImage = nil
            return
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let img = UIImage(data: data) else { return }
        heroImage = img
    }

    private func uploadPhoto(_ item: PhotosPickerItem) async {
        isUploadingPhoto = true
        defer {
            isUploadingPhoto = false
            photoPickerItem = nil
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                uploadError = "Could not read the selected photo."
                return
            }
            let compressResult = await Task.detached(priority: .userInitiated) {
                guard let uiImage = UIImage(data: data),
                      let compressed = uiImage.resized(maxDimension: 512).jpegData(compressionQuality: 0.8)
                else { return Data?.none }
                return compressed
            }.value
            guard let compressed = compressResult else {
                uploadError = "Could not process the selected photo."
                return
            }
            try await store.updatePetPhoto(currentPet, imageData: compressed)
        } catch {
            uploadError = error.localizedDescription
        }
    }
}

private enum PetSection: String, CaseIterable, Identifiable {
    case vet, appointments, history, events, weight, files
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .vet:          return "stethoscope"
        case .appointments: return "calendar"
        case .history:      return "clock.arrow.circlepath"
        case .events:       return "list.bullet"
        case .weight:       return "scalemass.fill"
        case .files:        return "folder.fill"
        }
    }

    var title: String {
        switch self {
        case .vet:          return "Vet / Clinic"
        case .appointments: return "Appointments"
        case .history:      return "History"
        case .events:       return "Events"
        case .weight:       return "Weight"
        case .files:        return "Files"
        }
    }

    var fill: Color {
        switch self {
        case .vet:          return Palette.pets
        case .appointments: return Palette.tasks
        case .history:      return Palette.stock
        case .events:       return Palette.meals
        case .weight:       return Palette.shopping
        case .files:        return Palette.surface
        }
    }
}

#Preview {
    NavigationStack {
        PetDetailView(pet: Pet(name: "Luna", type: "Dog", breed: "Golden Retriever"))
    }
    .environment(SupabaseStore())
}
