# Supabase Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the local JSON DataStore with Supabase (online-only), sharing data between two users with no auth.

**Architecture:** `SupabaseStore` (`@Observable`) replaces `DataStore` as the single source of truth. All mutations hit Supabase immediately and update local in-memory state optimistically. Files stored in Supabase Storage bucket `pet-files`.

**Tech Stack:** `supabase-swift` (SPM), Supabase Postgres + Storage, `Config.xcconfig` for credentials (gitignored).

---

## File Map

**Create:**
```
Config.xcconfig                                     (gitignored — credentials)
Home/Shared/Config/SupabaseConfig.swift             (reads from Info.plist, no secrets)
Home/Shared/Services/SupabaseStore.swift            (replaces DataStore)
HomeTests/SupabaseStoreTests.swift                  (unit tests for in-memory filters)
```

**Modify:**
```
Home/Pets/Pet.swift                                 — add CodingKeys, photoFilename → photoUrl
Home/Pets/Models/Veterinarian.swift                 — add CodingKeys
Home/Pets/Models/Appointment.swift                  — add CodingKeys
Home/Pets/Models/ClinicalEntry.swift                — add CodingKeys, remove fileIds
Home/Pets/Models/PetEvent.swift                     — add CodingKeys, remove fileIds
Home/Pets/Models/PetFile.swift                      — replace FileLink with flat fields, add CodingKeys
Home/ContentView.swift                              — inject SupabaseStore, show loading/error state
Home/Pets/PetsView.swift                            — async deletePet
Home/Pets/Detail/Tabs/VetTabView.swift              — async vet operations
Home/Pets/Detail/Sheets/VetEditSheet.swift          — async save
Home/Pets/Detail/Tabs/AppointmentsTabView.swift     — async mutations
Home/Pets/Detail/Sheets/AddAppointmentSheet.swift   — async save
Home/Pets/Detail/Tabs/ClinicalHistoryTabView.swift  — async mutations
Home/Pets/Detail/Sheets/AddClinicalEntrySheet.swift — async save + uploadFile
Home/Pets/Detail/Sheets/ClinicalEntryDetailView.swift — async uploadFile
Home/Pets/Detail/Tabs/EventsTabView.swift           — async mutations
Home/Pets/Detail/Sheets/AddEventSheet.swift         — async save + uploadFile
Home/Pets/Detail/Sheets/EventDetailView.swift       — async uploadFile
Home/Pets/Detail/Tabs/FilesTabView.swift            — async uploadFile
Home/Pets/Files/FilePickerCoordinator.swift         — onPick becomes async throws
Home/Pets/Files/FilePreviewView.swift               — remote URL, AsyncImage
Home/Pets/Claude/ExtractionService.swift            — accept URL directly
Home/Pets/Claude/ExtractionResultSheet.swift        — pass URL
Home/.gitignore or root .gitignore                  — add *.xcconfig
Home.xcodeproj/project.pbxproj                      — add SPM package, new files, Config.xcconfig
```

**Delete:**
```
Home/Pets/Store/DataStore.swift
Home/Pets/Store/AppData.swift
Home/Auth/AuthManager.swift
Home/Auth/LoginView.swift
```

---

## Task 1: Manual Supabase Setup (human steps)

**Files:** None (manual steps in browser + terminal)

- [ ] **Step 1: Create Supabase project**

Go to https://supabase.com → New project. Note down:
- Project URL: `https://xxxx.supabase.co`
- Anon key: `eyJh...`

- [ ] **Step 2: Run SQL schema in Supabase SQL Editor**

```sql
create table pets (
  id uuid primary key,
  name text not null,
  type text not null,
  breed text not null,
  photo_url text
);

create table veterinarian (
  id uuid primary key,
  name text not null,
  clinic_name text not null,
  phone text not null,
  address text not null,
  notes text not null
);

create table appointments (
  id uuid primary key,
  pet_id uuid references pets(id) on delete cascade,
  date timestamptz not null,
  reason text not null,
  notes text not null,
  status text not null
);

create table clinical_entries (
  id uuid primary key,
  pet_id uuid references pets(id) on delete cascade,
  date timestamptz not null,
  title text not null,
  description text not null
);

create table pet_events (
  id uuid primary key,
  pet_id uuid references pets(id) on delete cascade,
  date timestamptz not null,
  title text not null,
  category text not null,
  notes text not null,
  value text
);

create table pet_files (
  id uuid primary key,
  pet_id uuid references pets(id) on delete cascade,
  storage_path text not null,
  source_type text not null,
  linked_to_type text not null,
  linked_to_id uuid,
  created_at timestamptz not null
);
```

- [ ] **Step 3: Create Storage bucket**

In Supabase → Storage → New bucket → name: `pet-files` → Public: ON → Create.

- [ ] **Step 4: Create `Config.xcconfig` in project root**

```
SUPABASE_URL = https://xxxx.supabase.co
SUPABASE_ANON_KEY = eyJh...
```

Replace `xxxx` and the key with actual values. Do NOT commit this file.

- [ ] **Step 5: Add `*.xcconfig` to `.gitignore`**

```bash
echo "*.xcconfig" >> "/Users/guillermovelasco/Documents/Projects/Swifts Projects/Home/.gitignore"
```

---

## Task 2: Add supabase-swift Package + SupabaseConfig

**Files:**
- Modify: `Home.xcodeproj/project.pbxproj` (via Xcode UI)
- Create: `Home/Shared/Config/SupabaseConfig.swift`
- Modify: `Home/HomeApp.swift` or `Info.plist` target settings

- [ ] **Step 1: Add supabase-swift via Xcode SPM**

In Xcode: File → Add Package Dependencies → paste URL:
```
https://github.com/supabase/supabase-swift
```
Version: Up to Next Major from `2.0.0`. Add to **Home** target only. Select product: **Supabase**.

- [ ] **Step 2: Link Config.xcconfig to project**

In Xcode: click the project (blue icon) → select `Home` target → Build Settings → at the top, set configuration file for Debug and Release to `Config.xcconfig`.

- [ ] **Step 3: Add keys to Info.plist entries**

In Xcode → Home target → Info tab → add two rows:
- Key: `SUPABASE_URL`, Value: `$(SUPABASE_URL)`
- Key: `SUPABASE_ANON_KEY`, Value: `$(SUPABASE_ANON_KEY)`

- [ ] **Step 4: Create SupabaseConfig.swift**

```swift
// Home/Shared/Config/SupabaseConfig.swift
import Foundation

enum SupabaseConfig {
    static let url: URL = {
        guard let str = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              let url = URL(string: str) else {
            fatalError("SUPABASE_URL missing from Info.plist — create Config.xcconfig")
        }
        return url
    }()

    static let anonKey: String = {
        guard let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
              !key.isEmpty else {
            fatalError("SUPABASE_ANON_KEY missing from Info.plist — create Config.xcconfig")
        }
        return key
    }()
}
```

- [ ] **Step 5: Add SupabaseConfig.swift to Xcode project**

Drag into Project Navigator → ensure target membership = Home.

- [ ] **Step 6: Build to verify SPM resolves and config compiles**

`Cmd+B`. Expected: Build Succeeded (Supabase module resolves, no fatalError triggered since xcconfig is present).

- [ ] **Step 7: Commit**

```bash
git add Home/Shared/Config/SupabaseConfig.swift .gitignore
git commit -m "feat: add supabase-swift package and SupabaseConfig"
```

---

## Task 3: Update Swift Models

**Files:**
- Modify: `Home/Pets/Pet.swift`
- Modify: `Home/Pets/Models/Veterinarian.swift`
- Modify: `Home/Pets/Models/Appointment.swift`
- Modify: `Home/Pets/Models/ClinicalEntry.swift`
- Modify: `Home/Pets/Models/PetEvent.swift`
- Modify: `Home/Pets/Models/PetFile.swift`

- [ ] **Step 1: Update Pet.swift**

```swift
// Home/Pets/Pet.swift
import Foundation

struct Pet: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var type: String
    var breed: String
    var photoUrl: String? = nil

    enum CodingKeys: String, CodingKey {
        case id, name, type, breed
        case photoUrl = "photo_url"
    }
}
```

- [ ] **Step 2: Update Veterinarian.swift**

```swift
// Home/Pets/Models/Veterinarian.swift
import Foundation

struct Veterinarian: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var clinicName: String
    var phone: String
    var address: String
    var notes: String

    enum CodingKeys: String, CodingKey {
        case id, name, phone, address, notes
        case clinicName = "clinic_name"
    }
}
```

- [ ] **Step 3: Update Appointment.swift**

```swift
// Home/Pets/Models/Appointment.swift
import Foundation

enum AppointmentStatus: String, Codable, CaseIterable, Hashable {
    case upcoming, done, cancelled
}

struct Appointment: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var petId: UUID
    var date: Date
    var reason: String
    var notes: String
    var status: AppointmentStatus

    enum CodingKeys: String, CodingKey {
        case id, date, reason, notes, status
        case petId = "pet_id"
    }
}
```

- [ ] **Step 4: Update ClinicalEntry.swift** (remove fileIds)

```swift
// Home/Pets/Models/ClinicalEntry.swift
import Foundation

struct ClinicalEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var petId: UUID
    var date: Date
    var title: String
    var description: String

    enum CodingKeys: String, CodingKey {
        case id, date, title, description
        case petId = "pet_id"
    }
}
```

- [ ] **Step 5: Update PetEvent.swift** (remove fileIds)

```swift
// Home/Pets/Models/PetEvent.swift
import Foundation

enum EventCategory: String, Codable, CaseIterable, Hashable {
    case vaccine, grooming, medication, weight, other

    var icon: String {
        switch self {
        case .vaccine:    return "syringe"
        case .grooming:   return "scissors"
        case .medication: return "pill"
        case .weight:     return "scalemass"
        case .other:      return "note.text"
        }
    }
    var label: String { rawValue.capitalized }
}

struct PetEvent: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var petId: UUID
    var date: Date
    var title: String
    var category: EventCategory
    var notes: String
    var value: String?

    enum CodingKeys: String, CodingKey {
        case id, date, title, category, notes, value
        case petId = "pet_id"
    }
}
```

- [ ] **Step 6: Replace PetFile.swift** (FileLink → flat fields)

```swift
// Home/Pets/Models/PetFile.swift
import Foundation

enum FileSourceType: String, Codable, Hashable {
    case photo, document, scan
}

struct PetFile: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var petId: UUID
    var storagePath: String
    var sourceType: FileSourceType
    var linkedToType: String   // "event" | "clinicalEntry" | "standalone"
    var linkedToId: UUID?
    var createdAt: Date

    var displayName: String {
        URL(string: storagePath)?.lastPathComponent ?? storagePath
    }

    enum CodingKeys: String, CodingKey {
        case id, petId = "pet_id"
        case storagePath = "storage_path"
        case sourceType = "source_type"
        case linkedToType = "linked_to_type"
        case linkedToId = "linked_to_id"
        case createdAt = "created_at"
    }
}
```

- [ ] **Step 7: Build — expect errors** (DataStore references FileLink, old models)

`Cmd+B`. Expected: many errors. These get fixed in subsequent tasks. Do not proceed until Task 4 is done.

- [ ] **Step 8: Commit what compiles**

```bash
git add Home/Pets/Pet.swift Home/Pets/Models/
git commit -m "feat: update models with CodingKeys for Supabase, flatten FileLink"
```

---

## Task 4: Create SupabaseStore

**Files:**
- Create: `Home/Shared/Services/SupabaseStore.swift`
- Create: `HomeTests/SupabaseStoreTests.swift`

- [ ] **Step 1: Write failing tests for in-memory filter methods**

```swift
// HomeTests/SupabaseStoreTests.swift
import Testing
import Foundation
@testable import Home

@Suite("SupabaseStore filters") struct SupabaseStoreTests {

    @Test("appointments(for:) returns only matching petId")
    func appointmentsFilter() {
        let store = SupabaseStore()
        let petA = UUID()
        let petB = UUID()
        store.appointments = [
            Appointment(petId: petA, date: .now, reason: "check", notes: "", status: .upcoming),
            Appointment(petId: petB, date: .now, reason: "vacc", notes: "", status: .upcoming)
        ]
        #expect(store.appointments(for: petA).count == 1)
        #expect(store.appointments(for: petA)[0].reason == "check")
    }

    @Test("files(for:linkedToType:) filters by petId and type")
    func filesFilter() {
        let store = SupabaseStore()
        let petId = UUID()
        let eventId = UUID()
        store.files = [
            PetFile(petId: petId, storagePath: "a/b.jpg", sourceType: .photo,
                    linkedToType: "standalone", linkedToId: nil, createdAt: .now),
            PetFile(petId: petId, storagePath: "a/c.pdf", sourceType: .document,
                    linkedToType: "event", linkedToId: eventId, createdAt: .now)
        ]
        #expect(store.files(for: petId, linkedToType: "standalone").count == 1)
        #expect(store.files(for: petId).count == 2)
        #expect(store.files(for: UUID()).count == 0)
    }
}
```

- [ ] **Step 2: Run tests — expect compile error (SupabaseStore not defined)**

`Cmd+U`. Expected: compile error.

- [ ] **Step 3: Create SupabaseStore.swift**

```swift
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
        // Delete Storage files first
        let petFiles = files(for: pet.id)
        if !petFiles.isEmpty {
            let paths = petFiles.map(\.storagePath)
            try await client.storage.from("pet-files").remove(paths: paths)
        }
        // DB cascade handles appointments, entries, events, file rows
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
```

- [ ] **Step 4: Add SupabaseStore.swift to Xcode project (Home target) and SupabaseStoreTests.swift to HomeTests target**

Drag files into Project Navigator with correct target membership.

- [ ] **Step 5: Run tests**

`Cmd+U`. Expected: `SupabaseStoreTests` suite passes (2 tests). Build may still have errors in view files — that's expected until Task 5+.

- [ ] **Step 6: Commit**

```bash
git add Home/Shared/Services/SupabaseStore.swift HomeTests/SupabaseStoreTests.swift
git commit -m "feat: add SupabaseStore with full CRUD and file operations"
```

---

## Task 5: Update ContentView + Delete Dead Code

**Files:**
- Modify: `Home/ContentView.swift`
- Delete: `Home/Pets/Store/DataStore.swift`
- Delete: `Home/Pets/Store/AppData.swift`
- Delete: `Home/Auth/AuthManager.swift`
- Delete: `Home/Auth/LoginView.swift`

- [ ] **Step 1: Replace ContentView.swift**

```swift
// Home/ContentView.swift
import SwiftUI

struct ContentView: View {
    @State private var store = SupabaseStore()

    var body: some View {
        Group {
            if store.isLoading {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = store.loadError {
                ContentUnavailableView(
                    "Connection Error",
                    systemImage: "wifi.slash",
                    description: Text(error)
                ) {
                    Button("Retry") {
                        Task { await store.loadAll() }
                    }
                }
            } else {
                MainTabView()
            }
        }
        .environment(store)
        .task { await store.loadAll() }
    }
}

#Preview {
    ContentView()
}
```

- [ ] **Step 2: Delete dead files from Xcode project**

In Xcode Project Navigator: right-click each file → Delete → Move to Trash:
- `Home/Pets/Store/DataStore.swift`
- `Home/Pets/Store/AppData.swift`
- `Home/Auth/AuthManager.swift`
- `Home/Auth/LoginView.swift`

- [ ] **Step 3: Build — expect remaining errors in view files**

`Cmd+B`. Expected: errors about `DataStore` references in views. These get fixed in Tasks 6–11.

- [ ] **Step 4: Commit**

```bash
git add Home/ContentView.swift
git commit -m "feat: ContentView uses SupabaseStore with loading/error state, remove dead auth/store files"
```

---

## Task 6: Update PetsView + VetTabView + VetEditSheet

**Files:**
- Modify: `Home/Pets/PetsView.swift`
- Modify: `Home/Pets/Detail/Tabs/VetTabView.swift`
- Modify: `Home/Pets/Detail/Sheets/VetEditSheet.swift`

- [ ] **Step 1: Replace PetsView.swift**

```swift
// Home/Pets/PetsView.swift
import SwiftUI

struct PetsView: View {
    @Environment(SupabaseStore.self) private var store
    @State private var showAddPet = false

    var body: some View {
        NavigationStack {
            List(store.pets) { pet in
                NavigationLink(value: pet) {
                    PetRow(pet: pet)
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", role: .destructive) {
                        Task { try? await store.deletePet(pet) }
                    }
                }
            }
            .navigationTitle("My Pets")
            .navigationDestination(for: Pet.self) { pet in
                PetDetailView(pet: pet)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Pet", systemImage: "plus") { showAddPet = true }
                }
            }
            .sheet(isPresented: $showAddPet) { AddPetSheet() }
        }
    }
}

private struct AddPetSheet: View {
    @Environment(SupabaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var type = "Dog"
    @State private var breed = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Picker("Type", selection: $type) {
                    Text("Dog").tag("Dog")
                    Text("Cat").tag("Cat")
                    Text("Other").tag("Other")
                }
                TextField("Breed", text: $breed)
            }
            .navigationTitle("Add Pet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let pet = Pet(name: name, type: type, breed: breed)
                        Task {
                            try? await store.addPet(pet)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || breed.isEmpty)
                }
            }
        }
    }
}

#Preview {
    PetsView().environment(SupabaseStore())
}
```

- [ ] **Step 2: Replace VetTabView.swift**

```swift
// Home/Pets/Detail/Tabs/VetTabView.swift
import SwiftUI

struct VetTabView: View {
    let pet: Pet
    @Environment(SupabaseStore.self) private var store
    @State private var showEdit = false

    var body: some View {
        ScrollView {
            if let vet = store.veterinarian {
                VetCard(vet: vet).padding()
            } else {
                ContentUnavailableView(
                    "No Veterinarian",
                    systemImage: "stethoscope",
                    description: Text("Add your vet's contact information.")
                )
                .padding(.top, 60)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(store.veterinarian == nil ? "Add Vet" : "Edit") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            VetEditSheet(existing: store.veterinarian)
        }
    }
}

private struct VetCard: View {
    let vet: Veterinarian
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(vet.name, systemImage: "person.fill").font(.headline)
            Label(vet.clinicName, systemImage: "building.2.fill")
                .font(.subheadline).foregroundStyle(.secondary)
            Divider()
            if !vet.phone.isEmpty {
                Link(destination: URL(string: "tel:\(vet.phone.replacingOccurrences(of: " ", with: ""))")!) {
                    Label(vet.phone, systemImage: "phone.fill")
                }
            }
            if !vet.address.isEmpty {
                Link(destination: URL(string: "maps://?q=\(vet.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!) {
                    Label(vet.address, systemImage: "map.fill")
                }
            }
            if !vet.notes.isEmpty {
                Divider()
                Text(vet.notes).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
```

- [ ] **Step 3: Replace VetEditSheet.swift**

```swift
// Home/Pets/Detail/Sheets/VetEditSheet.swift
import SwiftUI

struct VetEditSheet: View {
    let existing: Veterinarian?
    @Environment(SupabaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var clinicName: String = ""
    @State private var phone: String = ""
    @State private var address: String = ""
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Doctor") {
                    TextField("Name", text: $name)
                    TextField("Clinic", text: $clinicName)
                }
                Section("Contact") {
                    TextField("Phone", text: $phone).keyboardType(.phonePad)
                    TextField("Address", text: $address)
                }
                Section("Notes") {
                    TextField("Specialty, hours...", text: $notes, axis: .vertical).lineLimit(3...6)
                }
            }
            .navigationTitle(existing == nil ? "Add Vet" : "Edit Vet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let vet = Veterinarian(
                            id: existing?.id ?? UUID(),
                            name: name, clinicName: clinicName,
                            phone: phone, address: address, notes: notes
                        )
                        Task {
                            try? await store.upsertVet(vet)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || clinicName.isEmpty)
                }
            }
            .onAppear {
                if let v = existing {
                    name = v.name; clinicName = v.clinicName
                    phone = v.phone; address = v.address; notes = v.notes
                }
            }
        }
    }
}
```

- [ ] **Step 4: Build — verify these files compile cleanly**

`Cmd+B`. Expected: still errors in other view files.

- [ ] **Step 5: Commit**

```bash
git add Home/Pets/PetsView.swift Home/Pets/Detail/Tabs/VetTabView.swift Home/Pets/Detail/Sheets/VetEditSheet.swift
git commit -m "feat: migrate PetsView, VetTabView, VetEditSheet to SupabaseStore"
```

---

## Task 7: Appointments

**Files:**
- Modify: `Home/Pets/Detail/Tabs/AppointmentsTabView.swift`
- Modify: `Home/Pets/Detail/Sheets/AddAppointmentSheet.swift`

- [ ] **Step 1: Replace AppointmentsTabView.swift**

```swift
// Home/Pets/Detail/Tabs/AppointmentsTabView.swift
import SwiftUI

struct AppointmentsTabView: View {
    let pet: Pet
    @Environment(SupabaseStore.self) private var store
    @State private var showAdd = false

    private var upcoming: [Appointment] {
        store.appointments(for: pet.id).filter { $0.status == .upcoming }.sorted { $0.date < $1.date }
    }
    private var past: [Appointment] {
        store.appointments(for: pet.id).filter { $0.status != .upcoming }.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            if upcoming.isEmpty && past.isEmpty {
                ContentUnavailableView("No Appointments", systemImage: "calendar.badge.plus",
                    description: Text("Tap + to schedule a visit."))
                    .listRowBackground(Color.clear)
            }
            if !upcoming.isEmpty {
                Section("Upcoming") {
                    ForEach(upcoming) { appt in
                        AppointmentRow(appointment: appt)
                            .swipeActions(edge: .trailing) {
                                Button("Cancel", role: .destructive) {
                                    Task { try? await store.updateAppointmentStatus(appt, status: .cancelled) }
                                }
                                Button("Done") {
                                    Task { try? await store.updateAppointmentStatus(appt, status: .done) }
                                }.tint(.green)
                            }
                    }
                }
            }
            if !past.isEmpty {
                Section("Past") {
                    ForEach(past) { appt in
                        AppointmentRow(appointment: appt)
                            .swipeActions {
                                Button("Delete", role: .destructive) {
                                    Task { try? await store.deleteAppointment(appt) }
                                }
                            }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add", systemImage: "plus") { showAdd = true }
            }
        }
        .sheet(isPresented: $showAdd) { AddAppointmentSheet(petId: pet.id) }
    }
}

private struct AppointmentRow: View {
    let appointment: Appointment

    private var statusColor: Color {
        switch appointment.status {
        case .upcoming:  return .blue
        case .done:      return .green
        case .cancelled: return .red
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(appointment.reason).font(.headline)
                Text(appointment.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
                if !appointment.notes.isEmpty {
                    Text(appointment.notes).font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Text(appointment.status.rawValue.capitalized)
                .font(.caption2.bold())
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(statusColor.opacity(0.15), in: Capsule())
                .foregroundStyle(statusColor)
        }
    }
}
```

- [ ] **Step 2: Replace AddAppointmentSheet.swift**

```swift
// Home/Pets/Detail/Sheets/AddAppointmentSheet.swift
import SwiftUI

struct AddAppointmentSheet: View {
    let petId: UUID
    @Environment(SupabaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date = .now
    @State private var reason: String = ""
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date & Time", selection: $date)
                Section("Details") {
                    TextField("Reason for visit", text: $reason)
                    TextField("Notes (optional)", text: $notes, axis: .vertical).lineLimit(2...4)
                }
            }
            .navigationTitle("New Appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let appt = Appointment(petId: petId, date: date, reason: reason, notes: notes, status: .upcoming)
                        Task {
                            try? await store.addAppointment(appt)
                            dismiss()
                        }
                    }
                    .disabled(reason.isEmpty)
                }
            }
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add Home/Pets/Detail/Tabs/AppointmentsTabView.swift Home/Pets/Detail/Sheets/AddAppointmentSheet.swift
git commit -m "feat: migrate appointments views to SupabaseStore"
```

---

## Task 8: Clinical History

**Files:**
- Modify: `Home/Pets/Detail/Tabs/ClinicalHistoryTabView.swift`
- Modify: `Home/Pets/Detail/Tabs/ClinicalEntryRow.swift`
- Modify: `Home/Pets/Detail/Sheets/AddClinicalEntrySheet.swift`
- Modify: `Home/Pets/Detail/Sheets/ClinicalEntryDetailView.swift`

- [ ] **Step 1: Update ClinicalEntryRow.swift** (fileCount now uses store query)

```swift
// Home/Pets/Detail/Tabs/ClinicalEntryRow.swift
import SwiftUI

struct ClinicalEntryRow: View {
    let entry: ClinicalEntry
    let fileCount: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title).font(.headline)
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption).foregroundStyle(.secondary)
                if !entry.description.isEmpty {
                    Text(entry.description).font(.caption2).foregroundStyle(.tertiary).lineLimit(2)
                }
            }
            Spacer()
            if fileCount > 0 {
                Label("\(fileCount)", systemImage: "paperclip")
                    .font(.caption2).foregroundStyle(.secondary)
                    .accessibilityLabel("\(fileCount) attached \(fileCount == 1 ? "file" : "files")")
            }
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }
}
```

- [ ] **Step 2: Replace ClinicalHistoryTabView.swift**

```swift
// Home/Pets/Detail/Tabs/ClinicalHistoryTabView.swift
import SwiftUI

struct ClinicalHistoryTabView: View {
    let pet: Pet
    @Environment(SupabaseStore.self) private var store
    @State private var showAdd = false
    @State private var selectedEntry: ClinicalEntry? = nil

    var entries: [ClinicalEntry] { store.clinicalEntries(for: pet.id) }

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView("No Clinical History", systemImage: "clock.arrow.circlepath",
                    description: Text("Tap + to add a clinical entry."))
                    .listRowBackground(Color.clear)
            }
            ForEach(entries) { entry in
                let fileCount = store.files(for: pet.id, linkedToType: "clinicalEntry", linkedToId: entry.id).count
                Button { selectedEntry = entry } label: {
                    ClinicalEntryRow(entry: entry, fileCount: fileCount)
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button("Delete", role: .destructive) {
                        Task { try? await store.deleteClinicalEntry(entry) }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add", systemImage: "plus") { showAdd = true }
            }
        }
        .sheet(isPresented: $showAdd) { AddClinicalEntrySheet(petId: pet.id) }
        .sheet(item: $selectedEntry) { entry in ClinicalEntryDetailView(entry: entry, pet: pet) }
    }
}
```

- [ ] **Step 3: Replace AddClinicalEntrySheet.swift**

```swift
// Home/Pets/Detail/Sheets/AddClinicalEntrySheet.swift
import SwiftUI

struct AddClinicalEntrySheet: View {
    let petId: UUID
    @Environment(SupabaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date = .now
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var showFilePicker = false
    @State private var pendingFiles: [PetFile] = []

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                Section("Entry") {
                    TextField("Title (e.g. Annual checkup)", text: $title)
                    TextField("Diagnosis / findings", text: $description, axis: .vertical).lineLimit(3...6)
                }
                Section("Files") {
                    Button { showFilePicker = true } label: {
                        Label("Attach file", systemImage: "plus.circle")
                    }
                    ForEach(pendingFiles) { file in
                        Label(file.displayName,
                              systemImage: file.sourceType == .document ? "doc.fill" : "photo.fill")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }.disabled(title.isEmpty)
                }
            }
            .sheet(isPresented: $showFilePicker) {
                FilePickerCoordinator { data, ext in
                    // Files uploaded as standalone first; relinked on save
                    let f = try await store.uploadFile(data: data, ext: ext, petId: petId,
                                                       linkedToType: "standalone", linkedToId: nil)
                    pendingFiles.append(f)
                }
            }
        }
    }

    private func save() {
        let entry = ClinicalEntry(petId: petId, date: date, title: title, description: description)
        Task {
            try? await store.addClinicalEntry(entry)
            // Relink pending files to this entry
            for file in pendingFiles {
                if let i = store.files.firstIndex(where: { $0.id == file.id }) {
                    var updated = store.files[i]
                    updated.linkedToType = "clinicalEntry"
                    updated.linkedToId = entry.id
                    try? await store.updateFileLink(updated)
                }
            }
            dismiss()
        }
    }
}
```

**Note:** `store.updateFileLink` is added to SupabaseStore in Step 4.

- [ ] **Step 4: Add `updateFileLink` to SupabaseStore**

Add this method to `SupabaseStore.swift` after `deleteFile`:

```swift
func updateFileLink(_ file: PetFile) async throws {
    try await client.from("pet_files")
        .update(["linked_to_type": file.linkedToType, "linked_to_id": file.linkedToId?.uuidString])
        .eq("id", value: file.id)
        .execute()
    if let i = files.firstIndex(where: { $0.id == file.id }) {
        files[i] = file
    }
}
```

- [ ] **Step 5: Replace ClinicalEntryDetailView.swift**

```swift
// Home/Pets/Detail/Sheets/ClinicalEntryDetailView.swift
import SwiftUI

struct ClinicalEntryDetailView: View {
    let entry: ClinicalEntry
    let pet: Pet
    @Environment(SupabaseStore.self) private var store
    @State private var showFilePicker = false
    @State private var selectedFile: PetFile? = nil

    var files: [PetFile] {
        store.files(for: pet.id, linkedToType: "clinicalEntry", linkedToId: entry.id)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Date") {
                        Text(entry.date.formatted(date: .long, time: .omitted))
                    }
                    if !entry.description.isEmpty {
                        Text(entry.description).font(.subheadline)
                    }
                }
                Section("Files") {
                    ForEach(files) { file in
                        Button { selectedFile = file } label: {
                            Label(file.displayName,
                                  systemImage: file.sourceType == .document ? "doc.fill" : "photo.fill")
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                Task { try? await store.deleteFile(file) }
                            }
                        }
                    }
                    Button { showFilePicker = true } label: {
                        Label("Add file", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle(entry.title)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showFilePicker) {
                FilePickerCoordinator { data, ext in
                    try await store.uploadFile(data: data, ext: ext, petId: pet.id,
                                               linkedToType: "clinicalEntry", linkedToId: entry.id)
                }
            }
            .sheet(item: $selectedFile) { file in
                FilePreviewView(file: file, pet: pet)
            }
        }
    }
}
```

- [ ] **Step 6: Commit**

```bash
git add Home/Pets/Detail/Tabs/ClinicalHistoryTabView.swift \
        Home/Pets/Detail/Tabs/ClinicalEntryRow.swift \
        Home/Pets/Detail/Sheets/AddClinicalEntrySheet.swift \
        Home/Pets/Detail/Sheets/ClinicalEntryDetailView.swift \
        Home/Shared/Services/SupabaseStore.swift
git commit -m "feat: migrate clinical history views to SupabaseStore"
```

---

## Task 9: Events

**Files:**
- Modify: `Home/Pets/Detail/Tabs/EventsTabView.swift`
- Modify: `Home/Pets/Detail/Tabs/EventRow.swift` (no change needed — no DataStore dependency)
- Modify: `Home/Pets/Detail/Sheets/AddEventSheet.swift`
- Modify: `Home/Pets/Detail/Sheets/EventDetailView.swift`

- [ ] **Step 1: Replace EventsTabView.swift**

```swift
// Home/Pets/Detail/Tabs/EventsTabView.swift
import SwiftUI

struct EventsTabView: View {
    let pet: Pet
    @Environment(SupabaseStore.self) private var store
    @State private var showAdd = false
    @State private var selectedEvent: PetEvent? = nil

    var events: [PetEvent] { store.events(for: pet.id) }

    var body: some View {
        List {
            if events.isEmpty {
                ContentUnavailableView("No Events", systemImage: "list.bullet",
                    description: Text("Track vaccines, grooming, medications and more."))
                    .listRowBackground(Color.clear)
            }
            ForEach(events) { event in
                Button { selectedEvent = event } label: { EventRow(event: event) }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            Task { try? await store.deleteEvent(event) }
                        }
                    }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add", systemImage: "plus") { showAdd = true }
            }
        }
        .sheet(isPresented: $showAdd) { AddEventSheet(petId: pet.id) }
        .sheet(item: $selectedEvent) { event in EventDetailView(event: event, pet: pet) }
    }
}
```

- [ ] **Step 2: Replace AddEventSheet.swift**

```swift
// Home/Pets/Detail/Sheets/AddEventSheet.swift
import SwiftUI

struct AddEventSheet: View {
    let petId: UUID
    @Environment(SupabaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date = .now
    @State private var title: String = ""
    @State private var category: EventCategory = .other
    @State private var notes: String = ""
    @State private var value: String = ""
    @State private var showFilePicker = false
    @State private var pendingFiles: [PetFile] = []

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                Section("Event") {
                    TextField("Title", text: $title)
                    Picker("Category", selection: $category) {
                        ForEach(EventCategory.allCases, id: \.self) { cat in
                            Label(cat.label, systemImage: cat.icon).tag(cat)
                        }
                    }
                    if category == .weight {
                        TextField("Value (e.g. 4.2 kg)", text: $value)
                    }
                    TextField("Notes (optional)", text: $notes, axis: .vertical).lineLimit(2...4)
                }
                Section("Files") {
                    Button { showFilePicker = true } label: {
                        Label("Attach file", systemImage: "plus.circle")
                    }
                    ForEach(pendingFiles) { file in
                        Label(file.displayName,
                              systemImage: file.sourceType == .document ? "doc.fill" : "photo.fill")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }.disabled(title.isEmpty)
                }
            }
            .sheet(isPresented: $showFilePicker) {
                FilePickerCoordinator { data, ext in
                    let f = try await store.uploadFile(data: data, ext: ext, petId: petId,
                                                       linkedToType: "standalone", linkedToId: nil)
                    pendingFiles.append(f)
                }
            }
        }
    }

    private func save() {
        let event = PetEvent(
            petId: petId, date: date, title: title, category: category,
            notes: notes, value: value.isEmpty ? nil : value
        )
        Task {
            try? await store.addEvent(event)
            for file in pendingFiles {
                if let i = store.files.firstIndex(where: { $0.id == file.id }) {
                    var updated = store.files[i]
                    updated.linkedToType = "event"
                    updated.linkedToId = event.id
                    try? await store.updateFileLink(updated)
                }
            }
            dismiss()
        }
    }
}
```

- [ ] **Step 3: Replace EventDetailView.swift**

```swift
// Home/Pets/Detail/Sheets/EventDetailView.swift
import SwiftUI

struct EventDetailView: View {
    let event: PetEvent
    let pet: Pet
    @Environment(SupabaseStore.self) private var store
    @State private var showFilePicker = false
    @State private var selectedFile: PetFile? = nil

    var files: [PetFile] {
        store.files(for: pet.id, linkedToType: "event", linkedToId: event.id)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Category") { Label(event.category.label, systemImage: event.category.icon) }
                    LabeledContent("Date") { Text(event.date.formatted(date: .long, time: .omitted)) }
                    if let v = event.value { LabeledContent("Value", value: v) }
                    if !event.notes.isEmpty { Text(event.notes).font(.subheadline) }
                }
                Section("Files") {
                    ForEach(files) { file in
                        Button { selectedFile = file } label: {
                            Label(file.displayName,
                                  systemImage: file.sourceType == .document ? "doc.fill" : "photo.fill")
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                Task { try? await store.deleteFile(file) }
                            }
                        }
                    }
                    Button { showFilePicker = true } label: {
                        Label("Add file", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle(event.title)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showFilePicker) {
                FilePickerCoordinator { data, ext in
                    try await store.uploadFile(data: data, ext: ext, petId: pet.id,
                                               linkedToType: "event", linkedToId: event.id)
                }
            }
            .sheet(item: $selectedFile) { file in FilePreviewView(file: file, pet: pet) }
        }
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add Home/Pets/Detail/Tabs/EventsTabView.swift \
        Home/Pets/Detail/Sheets/AddEventSheet.swift \
        Home/Pets/Detail/Sheets/EventDetailView.swift
git commit -m "feat: migrate events views to SupabaseStore"
```

---

## Task 10: FilesTabView + FilePickerCoordinator (async onPick)

**Files:**
- Modify: `Home/Pets/Detail/Tabs/FilesTabView.swift`
- Modify: `Home/Pets/Files/FilePickerCoordinator.swift`

- [ ] **Step 1: Update FilePickerCoordinator — make onPick async**

Change the `onPick` signature from `throws -> Void` to `async throws -> Void`, and update all internal call sites:

```swift
// Home/Pets/Files/FilePickerCoordinator.swift
import SwiftUI
import PhotosUI
import VisionKit

struct FilePickerCoordinator: View {
    var onPick: (Data, String) async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var photoPickerItem: PhotosPickerItem? = nil
    @State private var showCamera = false
    @State private var showDocPicker = false
    @State private var showScanner = false

    var body: some View {
        NavigationStack {
            List {
                Button { showCamera = true } label: { Label("Take Photo", systemImage: "camera") }
                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                }
                Button { showDocPicker = true } label: { Label("Choose File", systemImage: "doc") }
                Button { showScanner = true } label: { Label("Scan Document", systemImage: "doc.viewfinder") }
            }
            .navigationTitle("Add File")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .onChange(of: photoPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    try? await onPick(data, "jpg")
                    await MainActor.run { dismiss() }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                if let data = image.jpegData(compressionQuality: 0.8) {
                    Task { try? await onPick(data, "jpg") }
                }
                dismiss()
            }
        }
        .sheet(isPresented: $showDocPicker) {
            DocumentPicker { data in
                Task {
                    try? await onPick(data, "pdf")
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showScanner) {
            ScannerView { pdfData in
                Task {
                    try? await onPick(pdfData, "pdf")
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Camera (unchanged)

struct CameraPicker: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let vc = UIImagePickerController()
        vc.sourceType = .camera
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { onCapture(image) }
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Document Picker (unchanged)

struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (Data) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let vc = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image, .data])
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (Data) -> Void
        init(onPick: @escaping (Data) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else { return }
            onPick(data)
        }
    }
}

// MARK: - Scanner (unchanged)

struct ScannerView: UIViewControllerRepresentable {
    var onScan: (Data) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: (Data) -> Void
        init(onScan: @escaping (Data) -> Void) { self.onScan = onScan }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: CGSize(width: 612, height: 792)))
            let data = renderer.pdfData { ctx in
                for i in 0..<scan.pageCount {
                    ctx.beginPage()
                    scan.imageOfPage(at: i).draw(in: CGRect(origin: .zero, size: CGSize(width: 612, height: 792)))
                }
            }
            onScan(data)
            controller.dismiss(animated: true)
        }
    }
}
```

- [ ] **Step 2: Replace FilesTabView.swift**

```swift
// Home/Pets/Detail/Tabs/FilesTabView.swift
import SwiftUI

struct FilesTabView: View {
    let pet: Pet
    @Environment(SupabaseStore.self) private var store
    @State private var showFilePicker = false
    @State private var selectedFile: PetFile? = nil

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]
    var standaloneFiles: [PetFile] { store.files(for: pet.id, linkedToType: "standalone") }

    var body: some View {
        ScrollView {
            if standaloneFiles.isEmpty {
                ContentUnavailableView("No Files", systemImage: "folder",
                    description: Text("Add vet reports, photos, and other documents."))
                    .padding(.top, 60)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(standaloneFiles) { file in
                        FileGridCell(url: store.fileUrl(for: file), sourceType: file.sourceType)
                            .onTapGesture { selectedFile = file }
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    Task { try? await store.deleteFile(file) }
                                }
                            }
                    }
                }
                .padding()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add", systemImage: "plus") { showFilePicker = true }
            }
        }
        .sheet(isPresented: $showFilePicker) {
            FilePickerCoordinator { data, ext in
                _ = try await store.uploadFile(data: data, ext: ext, petId: pet.id,
                                               linkedToType: "standalone", linkedToId: nil)
            }
        }
        .sheet(item: $selectedFile) { file in FilePreviewView(file: file, pet: pet) }
    }
}

private struct FileGridCell: View {
    let url: URL
    let sourceType: FileSourceType

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(.regularMaterial)
            .frame(height: 100)
            .overlay {
                if sourceType == .document || sourceType == .scan {
                    Image(systemName: "doc.fill").font(.largeTitle).foregroundStyle(.secondary)
                } else {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill().clipped()
                    } placeholder: {
                        ProgressView()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add Home/Pets/Detail/Tabs/FilesTabView.swift Home/Pets/Files/FilePickerCoordinator.swift
git commit -m "feat: migrate FilesTabView, make FilePickerCoordinator.onPick async"
```

---

## Task 11: FilePreviewView + ExtractionService

**Files:**
- Modify: `Home/Pets/Files/FilePreviewView.swift`
- Modify: `Home/Pets/Claude/ExtractionService.swift`
- Modify: `Home/Pets/Claude/ExtractionResultSheet.swift`

- [ ] **Step 1: Replace FilePreviewView.swift**

```swift
// Home/Pets/Files/FilePreviewView.swift
import SwiftUI
import PDFKit

struct FilePreviewView: View {
    let file: PetFile
    let pet: Pet
    @Environment(SupabaseStore.self) private var store
    @State private var showExtraction = false

    private var fileURL: URL { store.fileUrl(for: file) }
    private var canExtract: Bool { file.sourceType == .document || file.sourceType == .scan }

    var body: some View {
        NavigationStack {
            Group {
                if file.sourceType == .photo {
                    ScrollView([.horizontal, .vertical]) {
                        AsyncImage(url: fileURL) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            ProgressView()
                        }
                        .padding()
                    }
                } else if file.sourceType == .document || file.sourceType == .scan {
                    PDFKitView(url: fileURL)
                } else {
                    ContentUnavailableView("Cannot Preview", systemImage: "doc.questionmark",
                        description: Text("This file type cannot be previewed."))
                }
            }
            .navigationTitle(file.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if canExtract {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Extract Info", systemImage: "sparkles") {
                            showExtraction = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showExtraction) {
                ExtractionResultSheet(fileURL: fileURL, file: file, pet: pet)
            }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }
    func updateUIView(_ uiView: PDFView, context: Context) {}
}
```

- [ ] **Step 2: Update ExtractionService.swift** — accept URL instead of fileURL from store

The `extract(fileURL:petName:)` signature stays the same — it already accepts a `URL`. Only the call site changes (now passes `store.fileUrl(for:)` which returns a remote URL). No code change needed in `ExtractionService.swift`.

- [ ] **Step 3: Update ExtractionResultSheet.swift** — accept fileURL as parameter

```swift
// Home/Pets/Claude/ExtractionResultSheet.swift
import SwiftUI

struct ExtractionResultSheet: View {
    let fileURL: URL
    let file: PetFile
    let pet: Pet
    @Environment(SupabaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var result: ExtractionResult? = nil
    @State private var error: String? = nil
    @State private var isLoading = false
    @State private var editedDiagnosis = ""
    @State private var editedRecommendations = ""

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Analyzing document with Claude…")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error {
                    ContentUnavailableView(
                        "Extraction Failed",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    ).padding()
                } else if let result {
                    extractionForm(result: result)
                }
            }
            .navigationTitle("Extracted Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                if result != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save to History") { saveToHistory() }
                    }
                }
            }
        }
        .task { await extract() }
    }

    @ViewBuilder
    private func extractionForm(result: ExtractionResult) -> some View {
        Form {
            if let date = result.visitDate {
                Section("Visit Date") {
                    Text(date.formatted(date: .long, time: .omitted))
                }
            }
            Section("Diagnosis / Findings") {
                TextField("Diagnosis", text: $editedDiagnosis, axis: .vertical).lineLimit(2...5)
            }
            if !result.testResults.isEmpty {
                Section("Test Results") {
                    ForEach(Array(result.testResults.keys.sorted()), id: \.self) { key in
                        LabeledContent(key, value: result.testResults[key] ?? "")
                    }
                }
            }
            if !result.medications.isEmpty {
                Section("Medications") {
                    ForEach(result.medications, id: \.self) { med in Text(med) }
                }
            }
            Section("Recommendations") {
                TextField("Recommendations", text: $editedRecommendations, axis: .vertical).lineLimit(2...5)
            }
        }
        .onAppear {
            editedDiagnosis = result.diagnosis
            editedRecommendations = result.recommendations
        }
    }

    private func extract() async {
        isLoading = true
        do {
            result = try await ExtractionService.extract(fileURL: fileURL, petName: pet.name)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func saveToHistory() {
        guard let result else { return }
        let entry = ClinicalEntry(
            petId: pet.id,
            date: result.visitDate ?? .now,
            title: editedDiagnosis.isEmpty ? "Vet Report" : String(editedDiagnosis.prefix(50)),
            description: [editedDiagnosis,
                          result.medications.isEmpty ? "" : "Medications: \(result.medications.joined(separator: ", "))",
                          editedRecommendations].filter { !$0.isEmpty }.joined(separator: "\n\n")
        )
        Task {
            try? await store.addClinicalEntry(entry)
            // Relink file to this entry
            if let i = store.files.firstIndex(where: { $0.id == file.id }) {
                var updated = store.files[i]
                updated.linkedToType = "clinicalEntry"
                updated.linkedToId = entry.id
                try? await store.updateFileLink(updated)
            }
            dismiss()
        }
    }
}
```

- [ ] **Step 4: Build — should be close to compiling**

`Cmd+B`. Expected: most errors resolved. Fix any remaining type mismatches.

- [ ] **Step 5: Commit**

```bash
git add Home/Pets/Files/FilePreviewView.swift \
        Home/Pets/Claude/ExtractionResultSheet.swift
git commit -m "feat: migrate FilePreviewView and ExtractionResultSheet to remote URLs"
```

---

## Task 12: Final Build, Tests, Cleanup

**Files:**
- Delete from pbxproj: `DataStore.swift`, `AppData.swift`, `AuthManager.swift`, `LoginView.swift` (if not already done in Task 5)
- Run all tests

- [ ] **Step 1: Full build — zero errors**

`Cmd+B`. Expected: Build Succeeded with zero errors.

If errors remain:
- `DataStore` reference → replace with `SupabaseStore`
- `store.data.X` → `store.X` (SupabaseStore exposes arrays directly)
- `store.save()` → remove (no-op, Supabase auto-persists)
- `file.filename` → `file.displayName` or `file.storagePath`
- `FileLink` enum → use `linkedToType: String` / `linkedToId: UUID?`

- [ ] **Step 2: Run all tests**

`Cmd+U`. Expected:
- `DataStoreTests` — will fail if DataStore is deleted. Delete `HomeTests/DataStoreTests.swift` (it tested the local store).
- `ExtractionServiceTests` — should still pass (no dependency on DataStore).
- `SupabaseStoreTests` — should pass.

Delete `HomeTests/DataStoreTests.swift` from project and disk.

- [ ] **Step 3: Smoke test on simulator**

`Cmd+R`. Expected: app launches, shows ProgressView briefly, then Home tab. Navigate to Pets — list loads from Supabase.

- [ ] **Step 4: Verify `Config.xcconfig` is not tracked**

```bash
cd "/Users/guillermovelasco/Documents/Projects/Swifts Projects/Home"
git status | grep xcconfig  # should show nothing
cat .gitignore | grep xcconfig  # should show *.xcconfig
```

- [ ] **Step 5: Final commit and push**

```bash
git add -A
git commit -m "feat: complete Supabase online-only integration"
git push
```
