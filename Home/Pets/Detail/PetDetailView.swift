import SwiftUI
import PhotosUI
import UIKit

struct PetDetailView: View {
    let pet: Pet
    @Environment(SupabaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var photoPickerItem: PhotosPickerItem? = nil
    @State private var isUploadingPhoto = false
    @State private var uploadError: String? = nil
    @State private var selectedSection: PetSection?
    @State private var showAddAppointment = false
    @State private var showAddEvent = false
    @State private var heroImage: UIImage?
    @State private var heroTintColor: Color?

    private var currentPet: Pet {
        store.pets.first(where: { $0.id == pet.id }) ?? pet
    }

    private var heroTint: Color { heroTintColor ?? Color(.systemGray3) }

    /// Foreground color readable on the tinted background.
    private var onTint: Color {
        var white: CGFloat = 0
        UIColor(heroTint).getWhite(&white, alpha: nil)
        return white > 0.6 ? .black : .white
    }

    private var ageString: String? {
        guard let birthday = currentPet.birthday else { return nil }
        let comps = Calendar.current.dateComponents([.year, .month], from: birthday, to: .now)
        if let y = comps.year, y > 0 { return "\(y) yr\(y == 1 ? "" : "s")" }
        if let m = comps.month { return "\(m) mo" }
        return nil
    }

    private var metaLine: String? {
        var parts: [String] = []
        if let age = ageString { parts.append(age) }
        if let birthday = currentPet.birthday {
            parts.append(birthday.formatted(date: .abbreviated, time: .omitted))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                content
            }
        }
        .scrollIndicators(.hidden)
        .background(heroTint.ignoresSafeArea())
        .ignoresSafeArea(.container, edges: .top)
        .task(id: currentPet.photoUrl) { await loadHero() }
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
        .sheet(isPresented: $showAddAppointment) { AddAppointmentSheet(petId: currentPet.id) }
        .sheet(isPresented: $showAddEvent) { AddEventSheet(petId: currentPet.id) }
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.black.opacity(0.35), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to My Pets")
            }
        }
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
        ZStack(alignment: .bottom) {
            Group {
                if let img = heroImage {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    Rectangle().fill(.quaternary)
                        .overlay {
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                }
            }
            .frame(height: 380)
            .frame(maxWidth: .infinity)
            .clipped()

            LinearGradient(colors: [.clear, heroTint], startPoint: .center, endPoint: .bottom)
                .frame(height: 380)
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 24) {
            titleBlock
            actionRow
            sectionsList
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
    }

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text(currentPet.name)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("\(currentPet.breed) · \(currentPet.type)")
                .font(.title3)
                .foregroundStyle(onTint.opacity(0.85))
            if let meta = metaLine {
                Text(meta)
                    .font(.subheadline)
                    .foregroundStyle(onTint.opacity(0.65))
            }
        }
        .foregroundStyle(onTint)
        .frame(maxWidth: .infinity)
    }

    private var actionRow: some View {
        HStack(spacing: 16) {
            CircleActionButton(systemImage: "calendar.day.timeline.left",
                               tint: onTint, label: "Add event") {
                showAddEvent = true
            }

            Button {
                showAddAppointment = true
            } label: {
                Label("Add Appointment", systemImage: "calendar.badge.plus")
                    .font(.headline)
                    .foregroundStyle(heroTint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white, in: Capsule())
            }

            if isUploadingPhoto {
                ProgressView()
                    .frame(width: 52, height: 52)
            } else {
                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    Image(systemName: "camera.fill")
                        .font(.title3)
                        .foregroundStyle(onTint)
                        .frame(width: 52, height: 52)
                        .background(onTint.opacity(0.15), in: Circle())
                }
                .accessibilityLabel("Change pet photo")
            }
        }
    }

    private var sectionsList: some View {
        VStack(spacing: 0) {
            ForEach(PetSection.allCases) { section in
                Button { selectedSection = section } label: {
                    HStack(spacing: 14) {
                        Image(systemName: section.icon)
                            .font(.body)
                            .frame(width: 26)
                        Text(section.title)
                            .font(.body)
                        Spacer()
                        if let count = count(for: section) {
                            Text("\(count)")
                                .font(.subheadline)
                                .foregroundStyle(onTint.opacity(0.6))
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(onTint.opacity(0.4))
                    }
                    .foregroundStyle(onTint)
                    .padding(.vertical, 15)
                }
                .buttonStyle(.plain)

                if section != PetSection.allCases.last {
                    Divider().overlay(onTint.opacity(0.2))
                }
            }
        }
    }

    private func count(for section: PetSection) -> Int? {
        switch section {
        case .vet:          return nil
        case .appointments: return store.appointments(for: currentPet.id).count
        case .history:      return store.clinicalEntries(for: currentPet.id).count
        case .events:       return store.events(for: currentPet.id).count
        case .files:        return store.files(for: currentPet.id).count
        }
    }

    // MARK: - Side effects

    private func loadHero() async {
        guard let urlStr = currentPet.photoUrl, let url = URL(string: urlStr) else {
            heroImage = nil
            heroTintColor = nil
            return
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let img = UIImage(data: data) else { return }
        heroImage = img
        heroTintColor = img.averageColor
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

private struct CircleActionButton: View {
    let systemImage: String
    let tint: Color
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 52, height: 52)
                .background(tint.opacity(0.15), in: Circle())
        }
        .accessibilityLabel(label)
    }
}

#Preview {
    NavigationStack {
        PetDetailView(pet: Pet(name: "Luna", type: "Dog", breed: "Golden Retriever"))
    }
    .environment(SupabaseStore())
}
