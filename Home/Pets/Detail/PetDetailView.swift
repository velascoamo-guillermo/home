import SwiftUI
import PhotosUI

struct PetDetailView: View {
    let pet: Pet
    @Environment(SupabaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var photoPickerItem: PhotosPickerItem? = nil
    @State private var isUploadingPhoto = false
    @State private var uploadError: String? = nil
    @State private var selectedSection: PetSection?

    private var currentPet: Pet {
        store.pets.first(where: { $0.id == pet.id }) ?? pet
    }

    private var ageString: String? {
        guard let birthday = currentPet.birthday else { return nil }
        let comps = Calendar.current.dateComponents([.year, .month], from: birthday, to: .now)
        if let y = comps.year, y > 0 { return "\(y) yr\(y == 1 ? "" : "s")" }
        if let m = comps.month { return "\(m) mo" }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                petNameHeader
                if currentPet.birthday != nil {
                    statsRow
                }
                sectionGrid
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background {
            ZStack {
                petBackground
                LinearGradient(
                    colors: [.clear, .black.opacity(0.65)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
        }
        .sheet(item: $selectedSection) { section in
            NavigationStack {
                switch section {
                case .vet:          VetTabView(pet: currentPet)
                case .appointments: AppointmentsTabView(pet: currentPet)
                case .history:      ClinicalHistoryTabView(pet: currentPet)
                case .events:       EventsTabView(pet: currentPet)
                case .files:        FilesTabView(pet: currentPet)
                }
            }
            .navigationTitle(section.title)
        }
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                        Text("My Pets")
                    }
                    .font(.body)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                }
            }
        }
        .onChange(of: photoPickerItem) { _, item in
            guard let item else { return }
            Task {
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
                    // Resize and encode off the main actor — UIGraphicsImageRenderer is thread-safe since iOS 10
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
        .alert("Upload Failed", isPresented: Binding(
            get: { uploadError != nil },
            set: { if !$0 { uploadError = nil } }
        )) {
            Button("OK") { uploadError = nil }
        } message: {
            if let msg = uploadError { Text(msg) }
        }
    }

    @ViewBuilder
    private var petBackground: some View {
        if let urlStr = currentPet.photoUrl, let url = URL(string: urlStr) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(.quaternary)
            }
            .ignoresSafeArea()
        } else {
            Rectangle().fill(.quaternary).ignoresSafeArea()
        }
    }

    private var petNameHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(currentPet.name)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("\(currentPet.breed) · \(currentPet.type)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                ZStack {
                    if isUploadingPhoto {
                        ProgressView()
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "camera")
                            .font(.body)
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                    }
                }
            }
            .accessibilityLabel("Change pet photo")
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            if let age = ageString {
                StatPill(label: "Age", value: age)
            }
            if let birthday = currentPet.birthday {
                StatPill(label: "Birthday", value: birthday.formatted(date: .abbreviated, time: .omitted))
            }
            Spacer()
        }
    }

    private var sectionGrid: some View {
        VStack(spacing: 14) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                PetSectionCard(section: .vet)          { selectedSection = .vet }
                PetSectionCard(section: .appointments) { selectedSection = .appointments }
                PetSectionCard(section: .history)      { selectedSection = .history }
                PetSectionCard(section: .events)       { selectedSection = .events }
            }
            PetSectionCard(section: .files) { selectedSection = .files }
        }
    }
}

private enum PetSection: String, Identifiable {
    case vet, appointments, history, events, files
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .vet:          return "stethoscope"
        case .appointments: return "calendar"
        case .history:      return "clock.arrow.circlepath"
        case .events:       return "list.bullet"
        case .files:        return "folder"
        }
    }

    var title: String {
        switch self {
        case .vet:          return "Vet / Clinic"
        case .appointments: return "Appointments"
        case .history:      return "History"
        case .events:       return "Events"
        case .files:        return "Files"
        }
    }
}

private struct PetSectionCard: View {
    let section: PetSection
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: section.icon)
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text(section.title)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
        .buttonStyle(.plain)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
        .accessibilityLabel(section.title)
    }
}

private struct StatPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.subheadline.bold())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .glassEffect(in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    NavigationStack {
        PetDetailView(pet: Pet(name: "Luna", type: "Dog", breed: "Golden Retriever"))
    }
    .environment(SupabaseStore())
}
