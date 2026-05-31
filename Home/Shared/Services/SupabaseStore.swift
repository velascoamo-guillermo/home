// Home/Shared/Services/SupabaseStore.swift
import Foundation
import Observation
import Supabase

@Observable
final class SupabaseStore {
    private let client: SupabaseClient

    var pets: [Pet] = []
    var veterinarians: [Veterinarian] = []
    var appointments: [Appointment] = []
    var clinicalEntries: [ClinicalEntry] = []
    var events: [PetEvent] = []
    var files: [PetFile] = []
    var householdTasks: [HouseholdTask] = []
    var customSections: [TaskSection] = []
    var isLoading = false
    var loadError: String? = nil

    init() {
        self.client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey,
            options: .init(auth: .init(emitLocalSessionAsInitialSession: true))
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
            async let ht: [HouseholdTask] = client.from("household_tasks").select().execute().value
            async let cs: [TaskSection]   = client.from("task_sections").select().execute().value

            pets = try await p
            veterinarians = try await v
            appointments = try await a
            clinicalEntries = try await ce
            events = try await pe
            files = try await pf
            householdTasks = try await ht
            customSections = try await cs
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

    func updatePet(_ pet: Pet) async throws {
        try await client.from("pets").update(pet).eq("id", value: pet.id).execute()
        if let i = pets.firstIndex(where: { $0.id == pet.id }) {
            pets[i] = pet
        }
    }

    func updatePetPhoto(_ pet: Pet, imageData: Data) async throws {
        let storagePath = "\(pet.id)/photo.jpg"
        try await client.storage.from("pet-files").upload(
            storagePath,
            data: imageData,
            options: FileOptions(contentType: "image/jpeg", upsert: true)
        )
        let photoUrl = try client.storage.from("pet-files").getPublicURL(path: storagePath)
        var updated = pet
        updated.photoUrl = "\(photoUrl.absoluteString)?t=\(Int(Date().timeIntervalSince1970))"
        do {
            try await updatePet(updated)
        } catch {
            try? await client.storage.from("pet-files").remove(paths: [storagePath])
            throw error
        }
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

    func addVet(_ vet: Veterinarian) async throws {
        try await client.from("veterinarian").insert(vet).execute()
        veterinarians.append(vet)
    }

    func updateVet(_ vet: Veterinarian) async throws {
        try await client.from("veterinarian").update(vet).eq("id", value: vet.id).execute()
        if let i = veterinarians.firstIndex(where: { $0.id == vet.id }) {
            veterinarians[i] = vet
        }
    }

    func deleteVet(_ vet: Veterinarian) async throws {
        try await client.from("veterinarian").delete().eq("id", value: vet.id).execute()
        veterinarians.removeAll { $0.id == vet.id }
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

    func analyzeFile(file: PetFile, petName: String) async throws -> ExtractionResult {
        let fileURL = fileUrl(for: file)
        let ext = (file.storagePath as NSString).pathExtension.lowercased()
        let mediaType = ext == "pdf" ? "application/pdf" : "image/jpeg"

        struct RequestBody: Encodable {
            let fileUrl: String
            let mediaType: String
            let petName: String
        }

        struct ResponseBody: Decodable {
            let success: Bool
            let visitDate: String?
            let diagnosis: String?
            let testResults: [String: String]?
            let medications: [String]?
            let recommendations: String?
            let error: String?
        }

        let body = RequestBody(fileUrl: fileURL.absoluteString, mediaType: mediaType, petName: petName)

        do {
            let response: ResponseBody = try await client.functions
                .invoke("analyze-pet-file", options: FunctionInvokeOptions(body: body))

            guard response.success else {
                throw ExtractionError.invalidResponse(0)
            }

            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = TimeZone(identifier: "UTC")
            dateFormatter.dateFormat = "yyyy-MM-dd"
            var visitDate: Date? = nil
            if let dateStr = response.visitDate { visitDate = dateFormatter.date(from: dateStr) }

            return ExtractionResult(
                visitDate: visitDate,
                diagnosis: response.diagnosis ?? "",
                testResults: response.testResults ?? [:],
                medications: response.medications ?? [],
                recommendations: response.recommendations ?? ""
            )
        } catch let fnError as FunctionsError {
            switch fnError {
            case .httpError(let code, _):
                throw ExtractionError.invalidResponse(code)
            case .relayError:
                throw ExtractionError.networkError(fnError)
            }
        } catch let extractionError as ExtractionError {
            throw extractionError
        } catch {
            throw ExtractionError.networkError(error)
        }
    }

    func fileUrl(for file: PetFile) -> URL {
        // storagePath is always a valid path we constructed — getPublicURL only throws on malformed input
        try! client.storage.from("pet-files").getPublicURL(path: file.storagePath)
    }

    // MARK: - In-memory filters

    var homeTimeline: [HomeItem] {
        let appts = appointments
            .filter { $0.status == .upcoming }
            .compactMap { appt -> HomeItem? in
                guard let pet = pets.first(where: { $0.id == appt.petId }) else { return nil }
                return .appointment(appt, pet)
            }
        let tasks = householdTasks.map { HomeItem.task($0) }
        return (appts + tasks).sorted { $0.dueDate < $1.dueDate }
    }

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

    // MARK: - Custom Sections

    func addCustomSection(_ section: TaskSection) async throws {
        try await client.from("task_sections").insert(section).execute()
        customSections.append(section)
    }

    func deleteCustomSection(_ section: TaskSection) async throws {
        try await client.from("task_sections").delete().eq("id", value: section.id).execute()
        customSections.removeAll { $0.id == section.id }
        for i in householdTasks.indices where householdTasks[i].sectionId == section.id {
            householdTasks[i].sectionId = nil
        }
    }

    // MARK: - Household Tasks

    func addTask(_ task: HouseholdTask) async throws {
        try await client.from("household_tasks").insert(task).execute()
        householdTasks.append(task)
    }

    func updateTask(_ task: HouseholdTask) async throws {
        try await client.from("household_tasks").update(task).eq("id", value: task.id).execute()
        if let i = householdTasks.firstIndex(where: { $0.id == task.id }) {
            householdTasks[i] = task
        }
    }

    func deleteTask(_ task: HouseholdTask) async throws {
        try await client.from("household_tasks").delete().eq("id", value: task.id).execute()
        householdTasks.removeAll { $0.id == task.id }
    }
}
