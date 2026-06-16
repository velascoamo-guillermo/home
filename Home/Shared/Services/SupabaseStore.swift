// Home/Shared/Services/SupabaseStore.swift
import Foundation
import Observation
import Supabase

@Observable
final class SupabaseStore {
    let client: SupabaseClient

    var pets: [Pet] = []
    var veterinarians: [Veterinarian] = []
    var appointments: [Appointment] = []
    var clinicalEntries: [ClinicalEntry] = []
    var events: [PetEvent] = []
    var files: [PetFile] = []
    var householdTasks: [HouseholdTask] = []
    var customSections: [TaskSection] = []
    var stockProducts: [StockProduct] = []

    var shoppingList: [StockProduct] {
        stockProducts.filter { $0.totalUnits == 0 }
    }

    var meals: [Meal] = []
    var mealProducts: [MealProduct] = []
    var isLoading = false
    var loadError: String? = nil

    private var localURL: URL {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.guille.Home")?
            .appendingPathComponent("home.sqlite")
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("home.sqlite")
    }
    private var _local: LocalStore?
    private var _sync: SyncEngine?
    private var reconnectTask: Task<Void, Never>?
    let reachability = Reachability()

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
            if _local == nil {
                let store = try await LocalStore(url: localURL)
                _sync = SyncEngine(local: store, gateway: SupabaseGateway(client: client))
                _local = store
                startReconnectObserver()
            }
            try await hydrate()
            isLoading = false
            await _sync?.sync(tables: SyncEngine.syncedTables)
            try? await hydrate()
            if loadError == nil { WidgetSnapshotWriter.write(from: self) }
        } catch {
            loadError = error.localizedDescription
            isLoading = false
        }
    }

    private func hydrate() async throws {
        guard let local = _local else { return }
        pets            = try await local.fetchAll(Pet.self)
        veterinarians   = try await local.fetchAll(Veterinarian.self)
        appointments    = try await local.fetchAll(Appointment.self)
        clinicalEntries = try await local.fetchAll(ClinicalEntry.self)
        events          = try await local.fetchAll(PetEvent.self)
        householdTasks  = try await local.fetchAll(HouseholdTask.self)
        customSections  = try await local.fetchAll(TaskSection.self)
        stockProducts   = try await local.fetchAll(StockProduct.self)
        meals           = try await local.fetchAll(Meal.self)
        mealProducts    = try await local.fetchAll(MealProduct.self)
    }

    private func startReconnectObserver() {
        reconnectTask = Task { @MainActor [weak self] in
            guard let stream = self?.reachability.changes else { return }
            for await online in stream where online {
                guard let self else { return }
                await self._sync?.sync(tables: SyncEngine.syncedTables)
                try? await self.hydrate()
            }
        }
    }

    // MARK: - Pets

    func addPet(_ pet: Pet) async throws {
        var p = pet; p.updatedAt = .now
        try await _local?.upsert([p], enqueue: true)
        pets.append(p)
        await _sync?.sync(tables: [Pet.tableName])
    }

    func updatePet(_ pet: Pet) async throws {
        var p = pet; p.updatedAt = .now
        try await _local?.upsert([p], enqueue: true)
        if let i = pets.firstIndex(where: { $0.id == p.id }) { pets[i] = p }
        await _sync?.sync(tables: [Pet.tableName])
    }

    func updatePetPhoto(_ pet: Pet, imageData: Data) async throws {
        guard reachability.isOnline else { throw SyncError.requiresConnection }
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
            guard reachability.isOnline else { throw SyncError.requiresConnection }
            let paths = petFiles.map(\.storagePath)
            try await client.storage.from("pet-files").remove(paths: paths)
        }
        for appt in appointments(for: pet.id) { try await _local?.softDelete(appt, enqueue: true) }
        for ce in clinicalEntries(for: pet.id) { try await _local?.softDelete(ce, enqueue: true) }
        for ev in events(for: pet.id) { try await _local?.softDelete(ev, enqueue: true) }
        try await _local?.softDelete(pet, enqueue: true)
        pets.removeAll { $0.id == pet.id }
        appointments.removeAll { $0.petId == pet.id }
        clinicalEntries.removeAll { $0.petId == pet.id }
        events.removeAll { $0.petId == pet.id }
        files.removeAll { $0.petId == pet.id }
        await _sync?.sync(tables: [Pet.tableName, Appointment.tableName, ClinicalEntry.tableName, PetEvent.tableName])
    }

    // MARK: - Vet

    func addVet(_ vet: Veterinarian) async throws {
        var v = vet; v.updatedAt = .now
        try await _local?.upsert([v], enqueue: true)
        veterinarians.append(v)
        await _sync?.sync(tables: [Veterinarian.tableName])
    }

    func updateVet(_ vet: Veterinarian) async throws {
        var v = vet; v.updatedAt = .now
        try await _local?.upsert([v], enqueue: true)
        if let i = veterinarians.firstIndex(where: { $0.id == v.id }) { veterinarians[i] = v }
        await _sync?.sync(tables: [Veterinarian.tableName])
    }

    func deleteVet(_ vet: Veterinarian) async throws {
        try await _local?.softDelete(vet, enqueue: true)
        veterinarians.removeAll { $0.id == vet.id }
        await _sync?.sync(tables: [Veterinarian.tableName])
    }

    // MARK: - Appointments

    func addAppointment(_ appt: Appointment) async throws {
        var a = appt; a.updatedAt = .now
        try await _local?.upsert([a], enqueue: true)
        appointments.append(a)
        await _sync?.sync(tables: [Appointment.tableName])
    }

    func updateAppointmentStatus(_ appt: Appointment, status: AppointmentStatus) async throws {
        var a = appt; a.status = status; a.updatedAt = .now
        try await _local?.upsert([a], enqueue: true)
        if let i = appointments.firstIndex(where: { $0.id == a.id }) { appointments[i] = a }
        await _sync?.sync(tables: [Appointment.tableName])
    }

    func deleteAppointment(_ appt: Appointment) async throws {
        try await _local?.softDelete(appt, enqueue: true)
        appointments.removeAll { $0.id == appt.id }
        await _sync?.sync(tables: [Appointment.tableName])
    }

    // MARK: - Clinical Entries

    func addClinicalEntry(_ entry: ClinicalEntry) async throws {
        var e = entry; e.updatedAt = .now
        try await _local?.upsert([e], enqueue: true)
        clinicalEntries.append(e)
        await _sync?.sync(tables: [ClinicalEntry.tableName])
    }

    func deleteClinicalEntry(_ entry: ClinicalEntry) async throws {
        let linked = files(for: entry.petId, linkedToType: "clinicalEntry", linkedToId: entry.id)
        if !linked.isEmpty {
            guard reachability.isOnline else { throw SyncError.requiresConnection }
            try await client.storage.from("pet-files").remove(paths: linked.map(\.storagePath))
        }
        try await _local?.softDelete(entry, enqueue: true)
        clinicalEntries.removeAll { $0.id == entry.id }
        files.removeAll { $0.linkedToId == entry.id && $0.linkedToType == "clinicalEntry" }
        await _sync?.sync(tables: [ClinicalEntry.tableName])
    }

    // MARK: - Events

    func addEvent(_ event: PetEvent) async throws {
        var e = event; e.updatedAt = .now
        try await _local?.upsert([e], enqueue: true)
        events.append(e)
        await _sync?.sync(tables: [PetEvent.tableName])
    }

    func deleteEvent(_ event: PetEvent) async throws {
        let linked = files(for: event.petId, linkedToType: "event", linkedToId: event.id)
        if !linked.isEmpty {
            guard reachability.isOnline else { throw SyncError.requiresConnection }
            try await client.storage.from("pet-files").remove(paths: linked.map(\.storagePath))
        }
        try await _local?.softDelete(event, enqueue: true)
        events.removeAll { $0.id == event.id }
        files.removeAll { $0.linkedToId == event.id && $0.linkedToType == "event" }
        await _sync?.sync(tables: [PetEvent.tableName])
    }

    // MARK: - Files (online-only)

    @discardableResult
    func uploadFile(data: Data, ext: String, petId: UUID,
                    linkedToType: String, linkedToId: UUID?) async throws -> PetFile {
        guard reachability.isOnline else { throw SyncError.requiresConnection }
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
        guard reachability.isOnline else { throw SyncError.requiresConnection }
        try await client.storage.from("pet-files").remove(paths: [file.storagePath])
        try await client.from("pet_files").delete().eq("id", value: file.id).execute()
        files.removeAll { $0.id == file.id }
    }

    func updateFileLink(_ file: PetFile) async throws {
        guard reachability.isOnline else { throw SyncError.requiresConnection }
        try await client.from("pet_files")
            .update(["linked_to_type": file.linkedToType, "linked_to_id": file.linkedToId?.uuidString])
            .eq("id", value: file.id)
            .execute()
        if let i = files.firstIndex(where: { $0.id == file.id }) {
            files[i] = file
        }
    }

    func analyzeFile(file: PetFile, petName: String) async throws -> ExtractionResult {
        guard reachability.isOnline else { throw SyncError.requiresConnection }
        let ext = (file.storagePath as NSString).pathExtension.lowercased()
        let mediaType = ext == "pdf" ? "application/pdf" : "image/jpeg"

        struct RequestBody: Encodable {
            let storagePath: String
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

        let body = RequestBody(storagePath: file.storagePath, mediaType: mediaType, petName: petName)

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
        let today = Calendar.current.startOfDay(for: .now)
        let appts = appointments
            .filter { $0.status == .upcoming }
            .compactMap { appt -> HomeItem? in
                guard let pet = pets.first(where: { $0.id == appt.petId }) else { return nil }
                return .appointment(appt, pet)
            }
        let tasks = householdTasks.map { HomeItem.task($0) }
        let petEvents = events
            .filter { $0.date >= today }
            .compactMap { event -> HomeItem? in
                guard let pet = pets.first(where: { $0.id == event.petId }) else { return nil }
                return .event(event, pet)
            }
        return (appts + tasks + petEvents).sorted { $0.dueDate < $1.dueDate }
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
        var s = section; s.updatedAt = .now
        try await _local?.upsert([s], enqueue: true)
        customSections.append(s)
        await _sync?.sync(tables: [TaskSection.tableName])
    }

    func deleteCustomSection(_ section: TaskSection) async throws {
        try await _local?.softDelete(section, enqueue: true)
        customSections.removeAll { $0.id == section.id }
        for i in householdTasks.indices where householdTasks[i].sectionId == section.id {
            householdTasks[i].sectionId = nil
        }
        await _sync?.sync(tables: [TaskSection.tableName])
    }

    // MARK: - Household Tasks

    func addTask(_ task: HouseholdTask) async throws {
        var t = task; t.updatedAt = .now
        try await _local?.upsert([t], enqueue: true)
        householdTasks.append(t)
        await _sync?.sync(tables: [HouseholdTask.tableName])
    }

    func updateTask(_ task: HouseholdTask) async throws {
        var t = task; t.updatedAt = .now
        try await _local?.upsert([t], enqueue: true)
        if let i = householdTasks.firstIndex(where: { $0.id == t.id }) { householdTasks[i] = t }
        await _sync?.sync(tables: [HouseholdTask.tableName])
    }

    func deleteTask(_ task: HouseholdTask) async throws {
        try await _local?.softDelete(task, enqueue: true)
        householdTasks.removeAll { $0.id == task.id }
        await _sync?.sync(tables: [HouseholdTask.tableName])
    }

    // MARK: - Stock

    enum CompletionResult: Equatable {
        case consumed
        case outOfStock(StockProduct)
        case noProduct
    }

    struct CompletionPlan {
        var updatedTask: HouseholdTask
        var updatedProduct: StockProduct?
        var result: CompletionResult
    }

    func completionPlan(for task: HouseholdTask) -> CompletionPlan {
        var updatedTask = task
        updatedTask.nextDueDate = Calendar.current.date(
            byAdding: .day, value: task.intervalDays, to: .now
        ) ?? .now

        guard let productId = task.productId,
              let product = stockProducts.first(where: { $0.id == productId }) else {
            return CompletionPlan(updatedTask: updatedTask, updatedProduct: nil, result: .noProduct)
        }

        guard let consumed = product.consuming(units: task.quantityPerCompletion) else {
            return CompletionPlan(updatedTask: updatedTask, updatedProduct: nil,
                                  result: .outOfStock(product))
        }

        return CompletionPlan(updatedTask: updatedTask, updatedProduct: consumed, result: .consumed)
    }

    @discardableResult
    func completeTask(_ task: HouseholdTask) async throws -> CompletionResult {
        let plan = completionPlan(for: task)
        try await updateTask(plan.updatedTask)
        if let product = plan.updatedProduct {
            try await updateProduct(product)
        }
        return plan.result
    }

    func addProduct(_ product: StockProduct) async throws {
        var p = product; p.updatedAt = .now
        try await _local?.upsert([p], enqueue: true)
        stockProducts.append(p)
        await _sync?.sync(tables: [StockProduct.tableName])
    }

    func updateProduct(_ product: StockProduct) async throws {
        var p = product; p.updatedAt = .now
        try await _local?.upsert([p], enqueue: true)
        if let i = stockProducts.firstIndex(where: { $0.id == p.id }) { stockProducts[i] = p }
        await _sync?.sync(tables: [StockProduct.tableName])
    }

    func replenish(_ product: StockProduct) async throws {
        try await updateProduct(product.replenished())
    }

    func deleteProduct(_ product: StockProduct) async throws {
        try await _local?.softDelete(product, enqueue: true)
        stockProducts.removeAll { $0.id == product.id }
        for i in householdTasks.indices where householdTasks[i].productId == product.id {
            householdTasks[i].productId = nil
        }
        await _sync?.sync(tables: [StockProduct.tableName])
    }
}
