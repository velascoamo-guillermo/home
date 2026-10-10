#if os(macOS)
import PhotosUI
import SwiftUI

struct MacPetDetailView: View {
    let pet: Pet
    @Bindable var model: MacWindowModel
    @Environment(SupabaseStore.self) private var store
    @AppStorage("mac.pet.tab") private var tab: PetTab = .appointments
    @State private var photoItem: PhotosPickerItem?
    @State private var isUploadingPhoto = false
    @State private var uploadError: String?
    @State private var importFailure: String?

    private var currentPet: Pet { store.pets.first { $0.id == pet.id } ?? pet }

    @concurrent
    nonisolated static func thumbnail(from data: Data) async -> Data? {
        PlatformImage(data: data)?.resized(maxDimension: 512).jpegData(compressionQuality: 0.8)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .gradientCanvas()
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Section", selection: $tab) {
                    ForEach(PetTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await uploadPhoto(item) }
        }
        .alert("Upload Failed", isPresented: Binding(
            get: { uploadError != nil },
            set: { if !$0 { uploadError = nil } }
        )) {
            Button("OK") { uploadError = nil }
        } message: {
            Text(uploadError ?? "")
        }
        .fileImporter(isPresented: Self.importBinding(for: pet.id, model: model), allowedContentTypes: PetFileImport.allowedTypes,
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                tab = .files
                Task {
                    let failures = await PetFileImporter.importFiles(urls, petID: currentPet.id, into: store)
                    importFailure = PetFileImporter.message(for: failures)
                }
            case .failure(let error):
                importFailure = Self.importFailureMessage(for: error)
            }
        }
        .alert("Some Files Weren't Added", isPresented: Binding(
            get: { importFailure != nil },
            set: { if !$0 { importFailure = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(importFailure ?? "")
        }
    }

    /// Dismissing the importer in any way (pick, Cancel, Escape) must clear `pendingAction`,
    /// or every New-item menu command stays disabled.
    static func importBinding(for petID: UUID, model: MacWindowModel) -> Binding<Bool> {
        Binding(
            get: {
                if case .importFiles(let id)? = model.pendingAction { return id == petID }
                return false
            },
            set: { if !$0 { model.pendingAction = nil } })
    }

    static func importFailureMessage(for error: any Error) -> String? {
        if let error = error as? CocoaError, error.code == .userCancelled { return nil }
        return error.localizedDescription
    }

    private var header: some View {
        let age = PetDetailSummary.ageText(birthday: currentPet.birthday, now: .now, calendar: .current)
        let weight = PetDetailSummary.weightText(store.weightEntries(for: currentPet.id))
        return HStack(spacing: 16) {
            PetAvatarView(pet: currentPet, size: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(currentPet.name)
                    .font(.title2.bold())
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text("\(currentPet.breed) · \(currentPet.type)")
                    .foregroundStyle(Palette.inkSecondary)
                HStack(spacing: 12) {
                    if let age { Label(age, systemImage: "birthday.cake") }
                    if let weight { Label(weight, systemImage: "scalemass") }
                }
                .font(.callout)
                .foregroundStyle(Palette.inkSecondary)
            }
            Spacer()
            if isUploadingPhoto {
                ProgressView().controlSize(.small)
            } else {
                PhotosPicker("Change Photo…", selection: $photoItem, matching: .images)
            }
        }
        .padding(20)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .vet:          VetTabView(pet: currentPet)
        case .appointments: AppointmentsTabView(pet: currentPet)
        case .history:      ClinicalHistoryTabView(pet: currentPet)
        case .events:       EventsTabView(pet: currentPet)
        case .weight:       WeightTabView(pet: currentPet)
        case .files:        MacPetFilesView(pet: currentPet)
        }
    }

    private func uploadPhoto(_ item: PhotosPickerItem) async {
        isUploadingPhoto = true
        defer {
            isUploadingPhoto = false
            photoItem = nil
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                uploadError = "Could not read the selected photo."
                return
            }
            guard let jpeg = await Self.thumbnail(from: data) else {
                uploadError = "Could not process the selected photo."
                return
            }
            try await store.updatePetPhoto(currentPet, imageData: jpeg)
        } catch {
            uploadError = error.localizedDescription
        }
    }
}
#endif
