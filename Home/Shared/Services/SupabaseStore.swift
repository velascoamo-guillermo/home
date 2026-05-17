// Home/Shared/Services/SupabaseStore.swift
import Foundation
import Observation
import Supabase

@Observable
final class SupabaseStore {
    private let client: SupabaseClient

    var pets: [Pet] = []
    var veterinarian: Veterinarian? = nil
    var appointments: [Appointment] = []
    var clinicalEntries: [ClinicalEntry] = []
    var events: [PetEvent] = []
    var files: [PetFile] = []
    var isLoading = false
    var loadError: String? = nil

    init() {
        self.client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey
        )
    }

    // MARK: - Bootstrap

    func loadAll() async {
        isLoading = true
        loadError = nil
        do {
            async let p: [Pet] = client.from("pets").select().execute().value
            async let v: [Veterinarian] = client.from("veterinarian").select().execute().value
            async let a: [Appointment] = client.from("appointments").select().execute().value
            async let ce: [ClinicalEntry] = client.from("clinical_entries").select().execute().value
            async let pe: [PetEvent] = client.from("pet_events").select().execute().value
            async let pf: [PetFile] = client.from("pet_files").select().execute().value

            pets = try await p
            veterinarian = try await v.first
            appointments = try await a
            clinicalEntries = try await ce
            events = try await pe
            files = try await pf
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Pets

    func addPet(_ pet: Pet) async throws {
        try await client.from("pets").insert(pet).execute()
        pets.append(pet)
    }

    func deletePet(_ pet: Pet) async throws {
        let petFiles = files(for: pet.id)
        if !petFiles.isEmpty {
            let paths = petFiles.map(\.storagePath)
            try await client.storage.from("pet-files").remove(paths: paths)
        }
        try await client.from("pets").delete().eq("id", value: pet.id).execute()
        pets.removeAll { $0.id == pet.id }
        appointments.removeAll { $0.petId == pet.id }
        clinicalEntries.removeAll { $0.petId == pet.id }
        events.removeAll { $0.petId == pet.id }
        files.removeAll { $0.petId == pet.id }
    }

    // MARK: - Vet

    func upsertVet(_ vet: Veterinarian) async throws {
        try await client.from("veterinarian").upsert(vet).execute()
        veterinarian = vet
    }

    // MARK: - Appointments

    func addAppointment(_ appt: Appointment) async throws {
        try await client.from("appointments").insert(appt).execute()
        appointments.append(appt)
    }

    func updateAppointmentStatus(_ appt: Appointment, status: AppointmentStatus) async throws {
        try await client.from("appointments")
            .update(["status": status.rawValue])
            .eq("id", value: appt.id)
            .execute()
        if let i = appointments.firstIndex(where: { $0.id == appt.id }) {
            appointments[i].status = status
        }
    }

    func deleteAppointment(_ appt: Appointment) async throws {
        try await client.from("appointments").delete().eq("id", value: appt.id).execute()
        appointments.removeAll { $0.id == appt.id }
    }

    // MARK: - Clinical Entries

    func addClinicalEntry(_ entry: ClinicalEntry) async throws {
        try await client.from("clinical_entries").insert(entry).execute()
        clinicalEntries.append(entry)
    }

    func deleteClinicalEntry(_ entry: ClinicalEntry) async throws {
        let linked = files(for: entry.petId, linkedToType: "clinicalEntry", linkedToId: entry.id)
        if !linked.isEmpty {
            try await client.storage.from("pet-files").remove(paths: linked.map(\.storagePath))
        }
        try await client.from("clinical_entries").delete().eq("id", value: entry.id).execute()
        clinicalEntries.removeAll { $0.id == entry.id }
        files.removeAll { $0.linkedToId == entry.id && $0.linkedToType == "clinicalEntry" }
    }

    // MARK: - Events

    func addEvent(_ event: PetEvent) async throws {
        try await client.from("pet_events").insert(event).execute()
        events.append(event)
    }

    func deleteEvent(_ event: PetEvent) async throws {
        let linked = files(for: event.petId, linkedToType: "event", linkedToId: event.id)
        if !linked.isEmpty {
            try await client.storage.from("pet-files").remove(paths: linked.map(\.storagePath))
        }
        try await client.from("pet_events").delete().eq("id", value: event.id).execute()
        events.removeAll { $0.id == event.id }
        files.removeAll { $0.linkedToId == event.id && $0.linkedToType == "event" }
    }

    // MARK: - Files

    @discardableResult
    func uploadFile(data: Data, ext: String, petId: UUID,
                    linkedToType: String, linkedToId: UUID?) async throws -> PetFile {
        let fileId = UUID()
        let storagePath = "\(petId)/\(fileId).\(ext)"
        let sourceType: FileSourceType = ext == "pdf" ? .document : .photo

        try await client.storage.from("pet-files").upload(storagePath, data: data)

        let file = PetFile(
            id: fileId, petId: petId, storagePath: storagePath,
            sourceType: sourceType, linkedToType: linkedToType,
            linkedToId: linkedToId, createdAt: .now
        )
        try await client.from("pet_files").insert(file).execute()
        files.append(file)
        return file
    }

    func deleteFile(_ file: PetFile) async throws {
        try await client.storage.from("pet-files").remove(paths: [file.storagePath])
        try await client.from("pet_files").delete().eq("id", value: file.id).execute()
        files.removeAll { $0.id == file.id }
    }

    func updateFileLink(_ file: PetFile) async throws {
        try await client.from("pet_files")
            .update(["linked_to_type": file.linkedToType, "linked_to_id": file.linkedToId?.uuidString])
            .eq("id", value: file.id)
            .execute()
        if let i = files.firstIndex(where: { $0.id == file.id }) {
            files[i] = file
        }
    }

    func fileUrl(for file: PetFile) -> URL {
        client.storage.from("pet-files").getPublicURL(path: file.storagePath)
    }

    // MARK: - In-memory filters

    func appointments(for petId: UUID) -> [Appointment] {
        appointments.filter { $0.petId == petId }
    }

    func clinicalEntries(for petId: UUID) -> [ClinicalEntry] {
        clinicalEntries.filter { $0.petId == petId }.sorted { $0.date > $1.date }
    }

    func events(for petId: UUID) -> [PetEvent] {
        events.filter { $0.petId == petId }.sorted { $0.date > $1.date }
    }

    func files(for petId: UUID, linkedToType: String? = nil, linkedToId: UUID? = nil) -> [PetFile] {
        files.filter { f in
            guard f.petId == petId else { return false }
            if let type = linkedToType, f.linkedToType != type { return false }
            if let id = linkedToId, f.linkedToId != id { return false }
            return true
        }
    }
}
