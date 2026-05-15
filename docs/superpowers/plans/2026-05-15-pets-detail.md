# Pets Detail Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a full pet detail screen with five tabs (Vet, Appointments, Clinical History, Events, Files), local JSON+file persistence, and Claude API extraction for vet reports.

**Architecture:** `DataStore` (`@Observable`) holds all app data as `AppData` (Codable), persisted to `Documents/AppData.json`. Binary files (images, PDFs) live in `Documents/PetFiles/`. `DataStore` is injected via `.environment` from `ContentView`, matching the existing `AuthManager` pattern.

**Tech Stack:** SwiftUI, `@Observable` (iOS 17+), `Codable`/`JSONEncoder`, `FileManager`, `PhotosPicker`, `UIDocumentPickerViewController`, `VNDocumentCameraViewController` (VisionKit), `PDFKit`, Security framework (Keychain), `URLSession` (Claude API via `claude-sonnet-4-6`).

---

## File Map

**Create:**
```
Home/Pets/Models/Veterinarian.swift
Home/Pets/Models/Appointment.swift
Home/Pets/Models/ClinicalEntry.swift
Home/Pets/Models/PetEvent.swift
Home/Pets/Models/PetFile.swift
Home/Pets/Store/AppData.swift
Home/Pets/Store/DataStore.swift
Home/Pets/Detail/PetDetailView.swift
Home/Pets/Detail/Tabs/VetTabView.swift
Home/Pets/Detail/Tabs/AppointmentsTabView.swift
Home/Pets/Detail/Tabs/ClinicalHistoryTabView.swift
Home/Pets/Detail/Tabs/EventsTabView.swift
Home/Pets/Detail/Tabs/FilesTabView.swift
Home/Pets/Detail/Sheets/VetEditSheet.swift
Home/Pets/Detail/Sheets/AddAppointmentSheet.swift
Home/Pets/Detail/Sheets/AddClinicalEntrySheet.swift
Home/Pets/Detail/Sheets/AddEventSheet.swift
Home/Pets/Detail/Sheets/ClinicalEntryDetailView.swift
Home/Pets/Detail/Sheets/EventDetailView.swift
Home/Pets/Files/FilePickerCoordinator.swift
Home/Pets/Files/FilePreviewView.swift
Home/Pets/Claude/ExtractionService.swift
Home/Pets/Claude/ExtractionResultSheet.swift
Home/Shared/Services/KeychainService.swift
HomeTests/DataStoreTests.swift
HomeTests/ExtractionServiceTests.swift
```

**Modify:**
```
Home/Pets/Pet.swift                  — add photoFilename
Home/Pets/PetsView.swift             — NavigationLink → PetDetailView
Home/ContentView.swift               — instantiate + inject DataStore
Home/Settings/SettingsView.swift     — add API key row
```

---

## Task 1: Data Models

**Files:**
- Create: `Home/Pets/Models/Veterinarian.swift`
- Create: `Home/Pets/Models/Appointment.swift`
- Create: `Home/Pets/Models/ClinicalEntry.swift`
- Create: `Home/Pets/Models/PetEvent.swift`
- Create: `Home/Pets/Models/PetFile.swift`
- Modify: `Home/Pets/Pet.swift`

- [ ] **Step 1: Create Veterinarian model**

```swift
// Home/Pets/Models/Veterinarian.swift
import Foundation

struct Veterinarian: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var clinicName: String
    var phone: String
    var address: String
    var notes: String
}
```

- [ ] **Step 2: Create Appointment model**

```swift
// Home/Pets/Models/Appointment.swift
import Foundation

enum AppointmentStatus: String, Codable, CaseIterable {
    case upcoming, done, cancelled
}

struct Appointment: Codable, Identifiable {
    var id: UUID = UUID()
    var petId: UUID
    var date: Date
    var reason: String
    var notes: String
    var status: AppointmentStatus
}
```

- [ ] **Step 3: Create ClinicalEntry model**

```swift
// Home/Pets/Models/ClinicalEntry.swift
import Foundation

struct ClinicalEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var petId: UUID
    var date: Date
    var title: String
    var description: String
    var fileIds: [UUID]
}
```

- [ ] **Step 4: Create PetEvent model**

```swift
// Home/Pets/Models/PetEvent.swift
import Foundation

enum EventCategory: String, Codable, CaseIterable {
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

struct PetEvent: Codable, Identifiable {
    var id: UUID = UUID()
    var petId: UUID
    var date: Date
    var title: String
    var category: EventCategory
    var notes: String
    var value: String?
    var fileIds: [UUID]
}
```

- [ ] **Step 5: Create PetFile model with FileLink**

```swift
// Home/Pets/Models/PetFile.swift
import Foundation

enum FileSourceType: String, Codable {
    case photo, document, scan
}

enum FileLink: Codable, Equatable {
    case event(UUID)
    case clinicalEntry(UUID)
    case standalone

    private enum CodingKeys: String, CodingKey { case type, id }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "event":         self = .event(try c.decode(UUID.self, forKey: .id))
        case "clinicalEntry": self = .clinicalEntry(try c.decode(UUID.self, forKey: .id))
        default:              self = .standalone
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .event(let id):
            try c.encode("event", forKey: .type)
            try c.encode(id, forKey: .id)
        case .clinicalEntry(let id):
            try c.encode("clinicalEntry", forKey: .type)
            try c.encode(id, forKey: .id)
        case .standalone:
            try c.encode("standalone", forKey: .type)
        }
    }
}

struct PetFile: Codable, Identifiable {
    var id: UUID = UUID()
    var petId: UUID
    var filename: String
    var sourceType: FileSourceType
    var createdAt: Date
    var linkedTo: FileLink
}
```

- [ ] **Step 6: Extend Pet model**

Replace the contents of `Home/Pets/Pet.swift`:

```swift
// Home/Pets/Pet.swift
import Foundation

struct Pet: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var type: String
    var breed: String
    var photoFilename: String? = nil
}
```

- [ ] **Step 7: Add all new files to Xcode project**

In Xcode: File → Add Files to "Home" (or drag into Project Navigator). Add each new `.swift` file under the correct group. Ensure target membership = "Home".

- [ ] **Step 8: Build — verify no compile errors**

`Cmd+B` in Xcode. Expected: Build Succeeded.

- [ ] **Step 9: Commit**

```bash
git add Home/Pets/Models/ Home/Pets/Pet.swift
git commit -m "feat: add pet detail data models"
```

---

## Task 2: AppData + DataStore

**Files:**
- Create: `Home/Pets/Store/AppData.swift`
- Create: `Home/Pets/Store/DataStore.swift`
- Create: `HomeTests/DataStoreTests.swift` (requires adding test target — see Step 1)

- [ ] **Step 1: Add test target (one-time Xcode setup)**

In Xcode: File → New → Target → Unit Testing Bundle. Name it `HomeTests`. When prompted to add to scheme, click Activate. In the new test target, delete the generated placeholder test file.

- [ ] **Step 2: Create AppData**

```swift
// Home/Pets/Store/AppData.swift
import Foundation

struct AppData: Codable {
    var veterinarian: Veterinarian? = nil
    var pets: [Pet] = []
    var appointments: [Appointment] = []
    var clinicalEntries: [ClinicalEntry] = []
    var events: [PetEvent] = []
    var files: [PetFile] = []
}
```

- [ ] **Step 3: Write failing DataStore tests**

```swift
// HomeTests/DataStoreTests.swift
import Testing
import Foundation
@testable import Home

@Suite("DataStore") struct DataStoreTests {

    @Test("saves and reloads AppData from disk")
    func saveAndReload() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = DataStore(directory: dir)
        let pet = Pet(name: "Luna", type: "Dog", breed: "Golden")
        store.data.pets = [pet]
        store.save()

        let reloaded = DataStore(directory: dir)
        #expect(reloaded.data.pets.count == 1)
        #expect(reloaded.data.pets[0].name == "Luna")
    }

    @Test("appointments(for:) filters by petId")
    func appointmentsFilter() {
        let store = DataStore(directory: FileManager.default.temporaryDirectory)
        let petA = UUID()
        let petB = UUID()
        store.data.appointments = [
            Appointment(petId: petA, date: .now, reason: "checkup", notes: "", status: .upcoming),
            Appointment(petId: petB, date: .now, reason: "vaccine", notes: "", status: .upcoming)
        ]
        #expect(store.appointments(for: petA).count == 1)
        #expect(store.appointments(for: petA)[0].reason == "checkup")
    }

    @Test("saveFile writes data to PetFiles directory")
    func saveFile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = DataStore(directory: dir)
        let petId = UUID()
        let data = Data("fake-image".utf8)
        let file = try store.saveFile(data: data, ext: "jpg", petId: petId, linkedTo: .standalone)
        #expect(store.data.files.count == 1)
        let url = store.fileURL(for: file)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test("deleteFile removes from disk and data")
    func deleteFile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = DataStore(directory: dir)
        let petId = UUID()
        let file = try store.saveFile(data: Data("x".utf8), ext: "jpg", petId: petId, linkedTo: .standalone)
        store.deleteFile(file)
        #expect(store.data.files.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: store.fileURL(for: file).path))
    }
}
```

- [ ] **Step 4: Run tests — verify they fail**

In Xcode: `Cmd+U`. Expected: compile error — `DataStore` not yet defined.

- [ ] **Step 5: Create DataStore**

```swift
// Home/Pets/Store/DataStore.swift
import Foundation
import Observation

@Observable
final class DataStore {
    var data: AppData

    private let jsonURL: URL
    private let filesDir: URL

    convenience init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.init(directory: documents)
    }

    init(directory: URL) {
        self.jsonURL = directory.appendingPathComponent("AppData.json")
        self.filesDir = directory.appendingPathComponent("PetFiles")
        if let saved = try? Data(contentsOf: jsonURL),
           let decoded = try? JSONDecoder().decode(AppData.self, from: saved) {
            self.data = decoded
        } else {
            self.data = AppData()
        }
        try? FileManager.default.createDirectory(at: filesDir, withIntermediateDirectories: true)
    }

    func save() {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        try? encoded.write(to: jsonURL, options: .atomic)
    }

    // MARK: - Filtered accessors

    func appointments(for petId: UUID) -> [Appointment] {
        data.appointments.filter { $0.petId == petId }
    }

    func clinicalEntries(for petId: UUID) -> [ClinicalEntry] {
        data.clinicalEntries.filter { $0.petId == petId }.sorted { $0.date > $1.date }
    }

    func events(for petId: UUID) -> [PetEvent] {
        data.events.filter { $0.petId == petId }.sorted { $0.date > $1.date }
    }

    func files(for petId: UUID, linkedTo link: FileLink? = nil) -> [PetFile] {
        data.files.filter { f in
            guard f.petId == petId else { return false }
            guard let link else { return true }
            return f.linkedTo == link
        }
    }

    func fileURL(for file: PetFile) -> URL {
        filesDir.appendingPathComponent(file.filename)
    }

    // MARK: - File operations

    @discardableResult
    func saveFile(data fileData: Data, ext: String, petId: UUID, linkedTo: FileLink) throws -> PetFile {
        let filename = "\(UUID().uuidString).\(ext)"
        let url = filesDir.appendingPathComponent(filename)
        try fileData.write(to: url, options: .atomic)
        let source: FileSourceType = ext == "pdf" ? .document : .photo
        let file = PetFile(petId: petId, filename: filename, sourceType: source, createdAt: .now, linkedTo: linkedTo)
        data.files.append(file)
        save()
        return file
    }

    func deleteFile(_ file: PetFile) {
        try? FileManager.default.removeItem(at: fileURL(for: file))
        data.files.removeAll { $0.id == file.id }
        save()
    }
}
```

- [ ] **Step 6: Run tests — verify they pass**

`Cmd+U`. Expected: all 4 tests pass.

- [ ] **Step 7: Add new files to Xcode project and commit**

Add `AppData.swift`, `DataStore.swift`, `HomeTests/DataStoreTests.swift` to Xcode project (test file in HomeTests target).

```bash
git add Home/Pets/Store/ HomeTests/DataStoreTests.swift
git commit -m "feat: add AppData and DataStore with persistence"
```

---

## Task 3: Wire DataStore into App

**Files:**
- Modify: `Home/ContentView.swift`
- Modify: `Home/Pets/PetsView.swift`

- [ ] **Step 1: Inject DataStore in ContentView**

```swift
// Home/ContentView.swift
import SwiftUI

struct ContentView: View {
    @State private var authManager = AuthManager()
    @State private var dataStore = DataStore()

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .environment(authManager)
        .environment(dataStore)
    }
}

#Preview {
    ContentView()
}
```

- [ ] **Step 2: Add NavigationLink to PetsView**

```swift
// Home/Pets/PetsView.swift
import SwiftUI

struct PetsView: View {
    @Environment(DataStore.self) private var store
    @State private var showAddPet = false

    var body: some View {
        NavigationStack {
            List(store.data.pets) { pet in
                NavigationLink(value: pet) {
                    PetRow(pet: pet)
                }
            }
            .navigationTitle("My Pets")
            .navigationDestination(for: Pet.self) { pet in
                PetDetailView(pet: pet)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Pet", systemImage: "plus") {
                        showAddPet = true
                    }
                }
            }
        }
    }
}

#Preview {
    PetsView()
        .environment(DataStore())
}
```

- [ ] **Step 3: Seed sample data for development**

In `DataStore.init(directory:)`, after `self.data = AppData()`, add seeding only when data is empty:

```swift
// Inside DataStore.init, after: self.data = AppData()
if self.data.pets.isEmpty {
    self.data.pets = [
        Pet(name: "Luna", type: "Dog", breed: "Golden Retriever"),
        Pet(name: "Whiskers", type: "Cat", breed: "Persian"),
        Pet(name: "Buddy", type: "Dog", breed: "Labrador")
    ]
}
```

- [ ] **Step 4: Build and run — verify pets list appears**

`Cmd+R`. Open Pets tab. List of 3 pets should appear. Tapping a pet crashes (no `PetDetailView` yet) — expected.

- [ ] **Step 5: Commit**

```bash
git add Home/ContentView.swift Home/Pets/PetsView.swift Home/Pets/Store/DataStore.swift
git commit -m "feat: inject DataStore into environment, wire pet list navigation"
```

---

## Task 4: PetDetailView Shell

**Files:**
- Create: `Home/Pets/Detail/PetDetailView.swift`

- [ ] **Step 1: Create PetDetailView with tab structure**

```swift
// Home/Pets/Detail/PetDetailView.swift
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
```

- [ ] **Step 2: Create stub tab views so it compiles**

Create each file with a minimal stub. Replace in subsequent tasks.

```swift
// Home/Pets/Detail/Tabs/VetTabView.swift
import SwiftUI
struct VetTabView: View {
    let pet: Pet
    var body: some View { Text("Vet").frame(maxWidth: .infinity, maxHeight: .infinity) }
}

// Home/Pets/Detail/Tabs/AppointmentsTabView.swift
import SwiftUI
struct AppointmentsTabView: View {
    let pet: Pet
    var body: some View { Text("Appointments").frame(maxWidth: .infinity, maxHeight: .infinity) }
}

// Home/Pets/Detail/Tabs/ClinicalHistoryTabView.swift
import SwiftUI
struct ClinicalHistoryTabView: View {
    let pet: Pet
    var body: some View { Text("History").frame(maxWidth: .infinity, maxHeight: .infinity) }
}

// Home/Pets/Detail/Tabs/EventsTabView.swift
import SwiftUI
struct EventsTabView: View {
    let pet: Pet
    var body: some View { Text("Events").frame(maxWidth: .infinity, maxHeight: .infinity) }
}

// Home/Pets/Detail/Tabs/FilesTabView.swift
import SwiftUI
struct FilesTabView: View {
    let pet: Pet
    var body: some View { Text("Files").frame(maxWidth: .infinity, maxHeight: .infinity) }
}
```

- [ ] **Step 3: Add all files to Xcode project, build and run**

Tap a pet — `PetDetailView` appears with header and 5-tab picker. Each tab shows placeholder text.

- [ ] **Step 4: Commit**

```bash
git add Home/Pets/Detail/
git commit -m "feat: add PetDetailView shell with tab navigation"
```

---

## Task 5: VetTabView + VetEditSheet

**Files:**
- Modify: `Home/Pets/Detail/Tabs/VetTabView.swift`
- Create: `Home/Pets/Detail/Sheets/VetEditSheet.swift`

- [ ] **Step 1: Replace VetTabView stub**

```swift
// Home/Pets/Detail/Tabs/VetTabView.swift
import SwiftUI

struct VetTabView: View {
    let pet: Pet
    @Environment(DataStore.self) private var store
    @State private var showEdit = false

    var body: some View {
        ScrollView {
            if let vet = store.data.veterinarian {
                VetCard(vet: vet)
                    .padding()
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
                Button(store.data.veterinarian == nil ? "Add Vet" : "Edit") {
                    showEdit = true
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            VetEditSheet(existing: store.data.veterinarian)
        }
    }
}

private struct VetCard: View {
    let vet: Veterinarian

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(vet.name, systemImage: "person.fill")
                .font(.headline)
            Label(vet.clinicName, systemImage: "building.2.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
                Text(vet.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
```

- [ ] **Step 2: Create VetEditSheet**

```swift
// Home/Pets/Detail/Sheets/VetEditSheet.swift
import SwiftUI

struct VetEditSheet: View {
    let existing: Veterinarian?
    @Environment(DataStore.self) private var store
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
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Address", text: $address)
                }
                Section("Notes") {
                    TextField("Specialty, hours...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(existing == nil ? "Add Vet" : "Edit Vet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
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

    private func save() {
        let vet = Veterinarian(
            id: existing?.id ?? UUID(),
            name: name, clinicName: clinicName,
            phone: phone, address: address, notes: notes
        )
        store.data.veterinarian = vet
        store.save()
        dismiss()
    }
}
```

- [ ] **Step 3: Build, run, test Vet tab manually**

Tap Vet tab → "No Veterinarian" empty state. Tap Add Vet → sheet. Fill in and save → vet card appears with phone/maps links.

- [ ] **Step 4: Commit**

```bash
git add Home/Pets/Detail/Tabs/VetTabView.swift Home/Pets/Detail/Sheets/VetEditSheet.swift
git commit -m "feat: add VetTabView with vet card and edit sheet"
```

---

## Task 6: AppointmentsTabView + AddAppointmentSheet

**Files:**
- Modify: `Home/Pets/Detail/Tabs/AppointmentsTabView.swift`
- Create: `Home/Pets/Detail/Sheets/AddAppointmentSheet.swift`

- [ ] **Step 1: Replace AppointmentsTabView stub**

```swift
// Home/Pets/Detail/Tabs/AppointmentsTabView.swift
import SwiftUI

struct AppointmentsTabView: View {
    let pet: Pet
    @Environment(DataStore.self) private var store
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
                                Button("Cancel", role: .destructive) { setStatus(appt, .cancelled) }
                                Button("Done") { setStatus(appt, .done) }.tint(.green)
                            }
                    }
                }
            }
            if !past.isEmpty {
                Section("Past") {
                    ForEach(past) { appt in
                        AppointmentRow(appointment: appt)
                            .swipeActions { Button("Delete", role: .destructive) { delete(appt) } }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add", systemImage: "plus") { showAdd = true }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddAppointmentSheet(petId: pet.id)
        }
    }

    private func setStatus(_ appt: Appointment, _ status: AppointmentStatus) {
        guard let i = store.data.appointments.firstIndex(where: { $0.id == appt.id }) else { return }
        store.data.appointments[i].status = status
        store.save()
    }

    private func delete(_ appt: Appointment) {
        store.data.appointments.removeAll { $0.id == appt.id }
        store.save()
    }
}

private struct AppointmentRow: View {
    let appointment: Appointment

    private var statusColor: Color {
        switch appointment.status {
        case .upcoming:   return .blue
        case .done:       return .green
        case .cancelled:  return .red
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

- [ ] **Step 2: Create AddAppointmentSheet**

```swift
// Home/Pets/Detail/Sheets/AddAppointmentSheet.swift
import SwiftUI

struct AddAppointmentSheet: View {
    let petId: UUID
    @Environment(DataStore.self) private var store
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
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("New Appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }.disabled(reason.isEmpty)
                }
            }
        }
    }

    private func save() {
        let appt = Appointment(petId: petId, date: date, reason: reason, notes: notes, status: .upcoming)
        store.data.appointments.append(appt)
        store.save()
        dismiss()
    }
}
```

- [ ] **Step 3: Build, run, test appointments tab**

Add an appointment → appears in Upcoming. Swipe right → mark Done → moves to Past. Swipe → Delete removes it.

- [ ] **Step 4: Commit**

```bash
git add Home/Pets/Detail/Tabs/AppointmentsTabView.swift Home/Pets/Detail/Sheets/AddAppointmentSheet.swift
git commit -m "feat: add AppointmentsTabView with add, status update, delete"
```

---

## Task 7: ClinicalHistoryTabView

**Files:**
- Modify: `Home/Pets/Detail/Tabs/ClinicalHistoryTabView.swift`
- Create: `Home/Pets/Detail/Sheets/AddClinicalEntrySheet.swift`
- Create: `Home/Pets/Detail/Sheets/ClinicalEntryDetailView.swift`

- [ ] **Step 1: Replace ClinicalHistoryTabView stub**

```swift
// Home/Pets/Detail/Tabs/ClinicalHistoryTabView.swift
import SwiftUI

struct ClinicalHistoryTabView: View {
    let pet: Pet
    @Environment(DataStore.self) private var store
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
                Button { selectedEntry = entry } label: {
                    ClinicalEntryRow(entry: entry, fileCount: store.files(for: pet.id, linkedTo: .clinicalEntry(entry.id)).count)
                }
                .buttonStyle(.plain)
                .swipeActions { Button("Delete", role: .destructive) { delete(entry) } }
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

    private func delete(_ entry: ClinicalEntry) {
        let linked = store.files(for: pet.id, linkedTo: .clinicalEntry(entry.id))
        linked.forEach { store.deleteFile($0) }
        store.data.clinicalEntries.removeAll { $0.id == entry.id }
        store.save()
    }
}

private struct ClinicalEntryRow: View {
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
            }
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
        }
    }
}
```

- [ ] **Step 2: Create AddClinicalEntrySheet**

```swift
// Home/Pets/Detail/Sheets/AddClinicalEntrySheet.swift
import SwiftUI

struct AddClinicalEntrySheet: View {
    let petId: UUID
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date = .now
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var showFilePicker = false
    @State private var attachedFiles: [PetFile] = []

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                Section("Entry") {
                    TextField("Title (e.g. Annual checkup)", text: $title)
                    TextField("Diagnosis / findings", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("Files") {
                    Button { showFilePicker = true } label: {
                        Label("Attach file", systemImage: "plus.circle")
                    }
                    ForEach(attachedFiles) { file in
                        Label(file.filename, systemImage: file.sourceType == .document ? "doc.fill" : "photo.fill")
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
                    if let f = try? store.saveFile(data: data, ext: ext, petId: petId, linkedTo: .standalone) {
                        attachedFiles.append(f)
                    }
                }
            }
        }
    }

    private func save() {
        var entry = ClinicalEntry(petId: petId, date: date, title: title, description: description, fileIds: [])
        // Relink files to this entry
        for file in attachedFiles {
            guard let i = store.data.files.firstIndex(where: { $0.id == file.id }) else { continue }
            store.data.files[i].linkedTo = .clinicalEntry(entry.id)
            entry.fileIds.append(file.id)
        }
        store.data.clinicalEntries.append(entry)
        store.save()
        dismiss()
    }
}
```

- [ ] **Step 3: Create ClinicalEntryDetailView**

```swift
// Home/Pets/Detail/Sheets/ClinicalEntryDetailView.swift
import SwiftUI

struct ClinicalEntryDetailView: View {
    let entry: ClinicalEntry
    let pet: Pet
    @Environment(DataStore.self) private var store
    @State private var showFilePicker = false
    @State private var selectedFile: PetFile? = nil

    var files: [PetFile] { store.files(for: pet.id, linkedTo: .clinicalEntry(entry.id)) }

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
                            Label(file.filename, systemImage: file.sourceType == .document ? "doc.fill" : "photo.fill")
                        }
                        .swipeActions { Button("Delete", role: .destructive) { store.deleteFile(file) } }
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
                    guard let i = store.data.clinicalEntries.firstIndex(where: { $0.id == entry.id }) else { return }
                    if let f = try? store.saveFile(data: data, ext: ext, petId: pet.id, linkedTo: .clinicalEntry(entry.id)) {
                        store.data.clinicalEntries[i].fileIds.append(f.id)
                        store.save()
                    }
                }
            }
            .sheet(item: $selectedFile) { file in
                FilePreviewView(file: file, pet: pet)
            }
        }
    }
}
```

- [ ] **Step 4: Build — expect compile errors on FilePickerCoordinator/FilePreviewView (stubs needed)**

Create minimal stubs so it compiles:

```swift
// Home/Pets/Files/FilePickerCoordinator.swift  (stub — replaced in Task 10)
import SwiftUI
struct FilePickerCoordinator: View {
    var onPick: (Data, String) -> Void
    var body: some View { Text("File picker coming soon") }
}

// Home/Pets/Files/FilePreviewView.swift  (stub — replaced in Task 11)
import SwiftUI
struct FilePreviewView: View {
    let file: PetFile
    let pet: Pet
    var body: some View { Text(file.filename).navigationTitle("Preview") }
}
```

- [ ] **Step 5: Build and run — verify clinical history tab works end to end**

Add entry → appears in list. Tap entry → detail with files section. Swipe delete removes entry and its files.

- [ ] **Step 6: Commit**

```bash
git add Home/Pets/Detail/Tabs/ClinicalHistoryTabView.swift \
        Home/Pets/Detail/Sheets/AddClinicalEntrySheet.swift \
        Home/Pets/Detail/Sheets/ClinicalEntryDetailView.swift \
        Home/Pets/Files/
git commit -m "feat: add ClinicalHistoryTabView with entries and file attachments"
```

---

## Task 8: EventsTabView

**Files:**
- Modify: `Home/Pets/Detail/Tabs/EventsTabView.swift`
- Create: `Home/Pets/Detail/Sheets/AddEventSheet.swift`
- Create: `Home/Pets/Detail/Sheets/EventDetailView.swift`

- [ ] **Step 1: Replace EventsTabView stub**

```swift
// Home/Pets/Detail/Tabs/EventsTabView.swift
import SwiftUI

struct EventsTabView: View {
    let pet: Pet
    @Environment(DataStore.self) private var store
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
                    .swipeActions { Button("Delete", role: .destructive) { delete(event) } }
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

    private func delete(_ event: PetEvent) {
        store.files(for: pet.id, linkedTo: .event(event.id)).forEach { store.deleteFile($0) }
        store.data.events.removeAll { $0.id == event.id }
        store.save()
    }
}

private struct EventRow: View {
    let event: PetEvent
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.category.icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title).font(.headline)
                HStack(spacing: 6) {
                    Text(event.date.formatted(date: .abbreviated, time: .omitted))
                    if let v = event.value { Text("·"); Text(v) }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}
```

- [ ] **Step 2: Create AddEventSheet**

```swift
// Home/Pets/Detail/Sheets/AddEventSheet.swift
import SwiftUI

struct AddEventSheet: View {
    let petId: UUID
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date = .now
    @State private var title: String = ""
    @State private var category: EventCategory = .other
    @State private var notes: String = ""
    @State private var value: String = ""
    @State private var showFilePicker = false
    @State private var attachedFiles: [PetFile] = []

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
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("Files") {
                    Button { showFilePicker = true } label: {
                        Label("Attach file", systemImage: "plus.circle")
                    }
                    ForEach(attachedFiles) { file in
                        Label(file.filename, systemImage: file.sourceType == .document ? "doc.fill" : "photo.fill")
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
                    if let f = try? store.saveFile(data: data, ext: ext, petId: petId, linkedTo: .standalone) {
                        attachedFiles.append(f)
                    }
                }
            }
        }
    }

    private func save() {
        var event = PetEvent(
            petId: petId, date: date, title: title, category: category,
            notes: notes, value: value.isEmpty ? nil : value, fileIds: []
        )
        for file in attachedFiles {
            guard let i = store.data.files.firstIndex(where: { $0.id == file.id }) else { continue }
            store.data.files[i].linkedTo = .event(event.id)
            event.fileIds.append(file.id)
        }
        store.data.events.append(event)
        store.save()
        dismiss()
    }
}
```

- [ ] **Step 3: Create EventDetailView**

```swift
// Home/Pets/Detail/Sheets/EventDetailView.swift
import SwiftUI

struct EventDetailView: View {
    let event: PetEvent
    let pet: Pet
    @Environment(DataStore.self) private var store
    @State private var showFilePicker = false
    @State private var selectedFile: PetFile? = nil

    var files: [PetFile] { store.files(for: pet.id, linkedTo: .event(event.id)) }

    var body: some View {
        List {
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
                            Label(file.filename, systemImage: file.sourceType == .document ? "doc.fill" : "photo.fill")
                        }
                        .swipeActions { Button("Delete", role: .destructive) { store.deleteFile(file) } }
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
                    guard let i = store.data.events.firstIndex(where: { $0.id == event.id }) else { return }
                    if let f = try? store.saveFile(data: data, ext: ext, petId: pet.id, linkedTo: .event(event.id)) {
                        store.data.events[i].fileIds.append(f.id)
                        store.save()
                    }
                }
            }
            .sheet(item: $selectedFile) { file in FilePreviewView(file: file, pet: pet) }
        }
    }
}
```

- [ ] **Step 4: Build, run, test events tab**

Add vaccine event → appears with syringe icon. Add weight with "4.2 kg" → value shown in row. Tap → detail.

- [ ] **Step 5: Commit**

```bash
git add Home/Pets/Detail/Tabs/EventsTabView.swift \
        Home/Pets/Detail/Sheets/AddEventSheet.swift \
        Home/Pets/Detail/Sheets/EventDetailView.swift
git commit -m "feat: add EventsTabView with general event log"
```

---

## Task 9: FilesTabView

**Files:**
- Modify: `Home/Pets/Detail/Tabs/FilesTabView.swift`

- [ ] **Step 1: Replace FilesTabView stub**

```swift
// Home/Pets/Detail/Tabs/FilesTabView.swift
import SwiftUI

struct FilesTabView: View {
    let pet: Pet
    @Environment(DataStore.self) private var store
    @State private var showFilePicker = false
    @State private var selectedFile: PetFile? = nil

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]
    var standaloneFiles: [PetFile] { store.files(for: pet.id, linkedTo: .standalone) }

    var body: some View {
        ScrollView {
            if standaloneFiles.isEmpty {
                ContentUnavailableView("No Files", systemImage: "folder",
                    description: Text("Add vet reports, photos, and other documents."))
                    .padding(.top, 60)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(standaloneFiles) { file in
                        FileGridCell(file: file, fileURL: store.fileURL(for: file))
                            .onTapGesture { selectedFile = file }
                            .contextMenu {
                                Button("Delete", role: .destructive) { store.deleteFile(file) }
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
                _ = try? store.saveFile(data: data, ext: ext, petId: pet.id, linkedTo: .standalone)
            }
        }
        .sheet(item: $selectedFile) { file in FilePreviewView(file: file, pet: pet) }
    }
}

private struct FileGridCell: View {
    let file: PetFile
    let fileURL: URL

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(.regularMaterial)
            .frame(height: 100)
            .overlay {
                if file.sourceType == .document || file.sourceType == .scan {
                    Image(systemName: "doc.fill")
                        .font(.largeTitle).foregroundStyle(.secondary)
                } else if let image = loadImage() {
                    Image(uiImage: image).resizable().scaledToFill().clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary)
                }
            }
    }

    private func loadImage() -> UIImage? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
}
```

- [ ] **Step 2: Build and run — verify Files tab shows grid**

Files added in Events/ClinicalHistory won't appear here (standalone only). Use + to add standalone files (shows stub picker for now).

- [ ] **Step 3: Commit**

```bash
git add Home/Pets/Detail/Tabs/FilesTabView.swift
git commit -m "feat: add FilesTabView with standalone file grid"
```

---

## Task 10: FilePickerCoordinator (real implementation)

**Files:**
- Modify: `Home/Pets/Files/FilePickerCoordinator.swift`

- [ ] **Step 1: Replace stub with real implementation**

```swift
// Home/Pets/Files/FilePickerCoordinator.swift
import SwiftUI
import PhotosUI
import VisionKit

struct FilePickerCoordinator: View {
    var onPick: (Data, String) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var source: PickerSource? = nil
    @State private var photoPickerItem: PhotosPickerItem? = nil
    @State private var showCamera = false
    @State private var showDocPicker = false
    @State private var showScanner = false

    enum PickerSource: Identifiable {
        case photo, camera, document, scan
        var id: Self { self }
    }

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
                    try? onPick(data, "jpg")
                    await MainActor.run { dismiss() }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                if let data = image.jpegData(compressionQuality: 0.8) {
                    try? onPick(data, "jpg")
                }
                dismiss()
            }
        }
        .sheet(isPresented: $showDocPicker) {
            DocumentPicker { data in
                try? onPick(data, "pdf")
                dismiss()
            }
        }
        .sheet(isPresented: $showScanner) {
            ScannerView { pdfData in
                try? onPick(pdfData, "pdf")
                dismiss()
            }
        }
    }
}

// MARK: - Camera

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
    }
}

// MARK: - Document Picker

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
            guard let url = urls.first,
                  url.startAccessingSecurityScopedResource(),
                  let data = try? Data(contentsOf: url) else { return }
            url.stopAccessingSecurityScopedResource()
            onPick(data)
        }
    }
}

// MARK: - Scanner

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

- [ ] **Step 2: Add camera usage description to Info.plist**

In Xcode, select the Home target → Info tab → add key `NSCameraUsageDescription` with value `"To take photos of your pet and capture vet documents."`. Also add `NSPhotoLibraryUsageDescription` with value `"To attach photos to your pet's records."`.

- [ ] **Step 3: Build and run — test all four file sources**

Tap + in Files tab → bottom sheet with 4 options. Test each source type.

- [ ] **Step 4: Commit**

```bash
git add Home/Pets/Files/FilePickerCoordinator.swift
git commit -m "feat: implement FilePickerCoordinator with photo, camera, doc, scan sources"
```

---

## Task 11: FilePreviewView (real implementation)

**Files:**
- Modify: `Home/Pets/Files/FilePreviewView.swift`

- [ ] **Step 1: Replace stub with real implementation**

```swift
// Home/Pets/Files/FilePreviewView.swift
import SwiftUI
import PDFKit

struct FilePreviewView: View {
    let file: PetFile
    let pet: Pet
    @Environment(DataStore.self) private var store
    @State private var showExtraction = false

    private var fileURL: URL { store.fileURL(for: file) }
    private var canExtract: Bool { file.sourceType == .document || file.sourceType == .scan }

    var body: some View {
        NavigationStack {
            Group {
                if file.sourceType == .photo, let image = loadImage() {
                    ScrollView([.horizontal, .vertical]) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding()
                    }
                } else if file.sourceType == .document || file.sourceType == .scan {
                    PDFKitView(url: fileURL)
                } else {
                    ContentUnavailableView("Cannot Preview", systemImage: "doc.questionmark",
                        description: Text("This file type cannot be previewed."))
                }
            }
            .navigationTitle(file.filename)
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
                ExtractionResultSheet(file: file, pet: pet)
            }
        }
    }

    private func loadImage() -> UIImage? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
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

- [ ] **Step 2: Create ExtractionResultSheet stub (replaced in Task 12)**

```swift
// Home/Pets/Claude/ExtractionResultSheet.swift  (stub)
import SwiftUI
struct ExtractionResultSheet: View {
    let file: PetFile
    let pet: Pet
    var body: some View { Text("Extraction coming soon").padding() }
}
```

- [ ] **Step 3: Add PDFKit framework to target**

In Xcode → Home target → General → Frameworks, Libraries, and Embedded Content → + → add `PDFKit.framework`.

- [ ] **Step 4: Build, run, test file preview**

Tap a photo file → image viewer. Tap a PDF/scan → PDF viewer. "Extract Info" button only appears on documents/scans.

- [ ] **Step 5: Commit**

```bash
git add Home/Pets/Files/FilePreviewView.swift Home/Pets/Claude/ExtractionResultSheet.swift
git commit -m "feat: add FilePreviewView with image and PDF support"
```

---

## Task 12: KeychainService + Settings API Key Row

**Files:**
- Create: `Home/Shared/Services/KeychainService.swift`
- Modify: `Home/Settings/SettingsView.swift`

- [ ] **Step 1: Create KeychainService**

```swift
// Home/Shared/Services/KeychainService.swift
import Foundation
import Security

enum KeychainService {
    static let claudeApiKeyAccount = "claude_api_key"
    private static let service = Bundle.main.bundleIdentifier ?? "com.home.app"

    static func save(key: String, account: String) {
        let data = Data(key.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
        var attrs = query
        attrs[kSecValueData] = data
        SecItemAdd(attrs as CFDictionary, nil)
    }

    static func load(account: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(account: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

- [ ] **Step 2: Add API key row to SettingsView**

```swift
// Home/Settings/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var showApiKeySheet = false
    @State private var hasApiKey: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    SettingsRow(icon: "person.circle", title: "Profile", subtitle: "Manage your account")
                    SettingsRow(icon: "bell", title: "Notifications", subtitle: "Pet reminders & alerts")
                    SettingsRow(icon: "shield", title: "Privacy", subtitle: "Data & security settings")
                }

                Section("Integrations") {
                    Button { showApiKeySheet = true } label: {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.purple)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Claude API Key")
                                    .foregroundStyle(.primary)
                                Text(hasApiKey ? "Configured" : "Not configured")
                                    .font(.caption)
                                    .foregroundStyle(hasApiKey ? .green : .secondary)
                            }
                        }
                    }
                }

                Section {
                    SettingsRow(icon: "questionmark.circle", title: "Help & Support", subtitle: "Get assistance")
                    SettingsRow(icon: "info.circle", title: "About", subtitle: "App version & info")
                }

                Section {
                    Button {
                        authManager.signOut()
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right").foregroundStyle(.red)
                            Text("Sign Out").foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear { hasApiKey = KeychainService.load(account: KeychainService.claudeApiKeyAccount) != nil }
            .sheet(isPresented: $showApiKeySheet, onDismiss: {
                hasApiKey = KeychainService.load(account: KeychainService.claudeApiKeyAccount) != nil
            }) {
                ApiKeySheet()
            }
        }
    }
}

private struct ApiKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var key: String = ""
    @State private var isSecure: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        if isSecure {
                            SecureField("sk-ant-...", text: $key)
                        } else {
                            TextField("sk-ant-...", text: $key)
                        }
                        Button { isSecure.toggle() } label: {
                            Image(systemName: isSecure ? "eye" : "eye.slash")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Claude API Key")
                } footer: {
                    Text("Used to extract information from vet documents. Stored securely in Keychain.")
                }
                if KeychainService.load(account: KeychainService.claudeApiKeyAccount) != nil {
                    Section {
                        Button("Remove Key", role: .destructive) {
                            KeychainService.delete(account: KeychainService.claudeApiKeyAccount)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        KeychainService.save(key: key.trimmingCharacters(in: .whitespaces),
                                            account: KeychainService.claudeApiKeyAccount)
                        dismiss()
                    }
                    .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                key = KeychainService.load(account: KeychainService.claudeApiKeyAccount) ?? ""
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(AuthManager())
}
```

- [ ] **Step 3: Build, run, test Settings → API key flow**

Settings → Claude API Key row → sheet. Enter key → save → row shows "Configured". Re-open → key pre-filled. Remove → row shows "Not configured".

- [ ] **Step 4: Commit**

```bash
git add Home/Shared/Services/KeychainService.swift Home/Settings/SettingsView.swift
git commit -m "feat: add KeychainService and Claude API key management in Settings"
```

---

## Task 13: ExtractionService + ExtractionResultSheet

**Files:**
- Create: `Home/Pets/Claude/ExtractionService.swift`
- Modify: `Home/Pets/Claude/ExtractionResultSheet.swift`
- Create: `HomeTests/ExtractionServiceTests.swift`

- [ ] **Step 1: Write failing tests for ExtractionService parsing**

```swift
// HomeTests/ExtractionServiceTests.swift
import Testing
import Foundation
@testable import Home

@Suite("ExtractionService") struct ExtractionServiceTests {

    @Test("parses well-formed Claude JSON response")
    func parseWellFormed() throws {
        let json = """
        {
          "visitDate": "2025-03-15",
          "diagnosis": "Mild otitis externa",
          "testResults": {"WBC": "6.5 K/uL", "RBC": "7.2 M/uL"},
          "medications": ["Otomax otic suspension", "Apoquel 16mg"],
          "recommendations": "Follow up in 2 weeks if no improvement."
        }
        """
        let result = try ExtractionService.parseResponse(json)
        #expect(result.diagnosis == "Mild otitis externa")
        #expect(result.medications.count == 2)
        #expect(result.testResults["WBC"] == "6.5 K/uL")
        #expect(result.recommendations == "Follow up in 2 weeks if no improvement.")
    }

    @Test("returns nil visitDate when missing from response")
    func missingDate() throws {
        let json = """
        {
          "visitDate": null,
          "diagnosis": "Healthy",
          "testResults": {},
          "medications": [],
          "recommendations": ""
        }
        """
        let result = try ExtractionService.parseResponse(json)
        #expect(result.visitDate == nil)
    }

    @Test("buildPrompt includes pet name")
    func promptIncludesPetName() {
        let prompt = ExtractionService.buildPrompt(petName: "Luna")
        #expect(prompt.contains("Luna"))
    }
}
```

- [ ] **Step 2: Run tests — verify they fail**

`Cmd+U`. Expected: compile error — `ExtractionService` not yet defined.

- [ ] **Step 3: Create ExtractionService**

```swift
// Home/Pets/Claude/ExtractionService.swift
import Foundation

struct ExtractionResult {
    var visitDate: Date?
    var diagnosis: String
    var testResults: [String: String]
    var medications: [String]
    var recommendations: String
}

enum ExtractionError: LocalizedError {
    case noApiKey
    case networkError(Error)
    case invalidResponse(Int)
    case parseError

    var errorDescription: String? {
        switch self {
        case .noApiKey:               return "No Claude API key configured. Add one in Settings."
        case .networkError(let e):    return "Network error: \(e.localizedDescription)"
        case .invalidResponse(let c): return "API error (status \(c)). Check your API key."
        case .parseError:             return "Could not parse the document. Try a clearer scan."
        }
    }
}

enum ExtractionService {

    static func buildPrompt(petName: String) -> String {
        """
        You are a veterinary records assistant. Analyze the attached document for \(petName) and extract the following information. Respond with ONLY valid JSON matching this exact schema — no markdown, no extra text:

        {
          "visitDate": "YYYY-MM-DD or null",
          "diagnosis": "string",
          "testResults": {"test name": "value"},
          "medications": ["string"],
          "recommendations": "string"
        }

        If a field is not present in the document, use null for dates and empty string/array for others.
        """
    }

    static func parseResponse(_ json: String) throws -> ExtractionResult {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ExtractionError.parseError
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        var visitDate: Date? = nil
        if let dateStr = obj["visitDate"] as? String { visitDate = dateFormatter.date(from: dateStr) }
        let diagnosis = obj["diagnosis"] as? String ?? ""
        let testResults = obj["testResults"] as? [String: String] ?? [:]
        let medications = obj["medications"] as? [String] ?? []
        let recommendations = obj["recommendations"] as? String ?? ""
        return ExtractionResult(visitDate: visitDate, diagnosis: diagnosis,
                                testResults: testResults, medications: medications,
                                recommendations: recommendations)
    }

    static func extract(fileURL: URL, petName: String) async throws -> ExtractionResult {
        guard let apiKey = KeychainService.load(account: KeychainService.claudeApiKeyAccount),
              !apiKey.isEmpty else { throw ExtractionError.noApiKey }

        let fileData = try Data(contentsOf: fileURL)
        let base64 = fileData.base64EncodedString()
        let ext = fileURL.pathExtension.lowercased()
        let mediaType = ext == "pdf" ? "application/pdf" : "image/jpeg"
        let contentType = ext == "pdf" ? "document" : "image"

        let contentBlock: [String: Any] = [
            "type": contentType,
            "source": [
                "type": "base64",
                "media_type": mediaType,
                "data": base64
            ]
        ]

        let body: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 1024,
            "messages": [[
                "role": "user",
                "content": [
                    contentBlock,
                    ["type": "text", "text": buildPrompt(petName: petName)]
                ]
            ]]
        ]

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ExtractionError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw ExtractionError.invalidResponse(code)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = (json["content"] as? [[String: Any]])?.first,
              let text = content["text"] as? String else {
            throw ExtractionError.parseError
        }

        return try parseResponse(text)
    }
}
```

- [ ] **Step 4: Run tests — verify they pass**

`Cmd+U`. Expected: 3 tests pass.

- [ ] **Step 5: Replace ExtractionResultSheet stub**

```swift
// Home/Pets/Claude/ExtractionResultSheet.swift
import SwiftUI

struct ExtractionResultSheet: View {
    let file: PetFile
    let pet: Pet
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var result: ExtractionResult? = nil
    @State private var error: String? = nil
    @State private var isLoading = false
    @State private var editedDiagnosis = ""
    @State private var editedRecommendations = ""
    @State private var savedSuccessfully = false

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
                    )
                    .padding()
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
                TextField("Diagnosis", text: $editedDiagnosis, axis: .vertical)
                    .lineLimit(2...5)
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
                TextField("Recommendations", text: $editedRecommendations, axis: .vertical)
                    .lineLimit(2...5)
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
            result = try await ExtractionService.extract(fileURL: store.fileURL(for: file), petName: pet.name)
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
                          editedRecommendations].filter { !$0.isEmpty }.joined(separator: "\n\n"),
            fileIds: [file.id]
        )
        // Relink file to this clinical entry
        if let i = store.data.files.firstIndex(where: { $0.id == file.id }) {
            store.data.files[i].linkedTo = .clinicalEntry(entry.id)
        }
        store.data.clinicalEntries.append(entry)
        store.save()
        dismiss()
    }
}
```

- [ ] **Step 6: Add `NSAppTransportSecurity` exception if needed**

The Anthropic API uses HTTPS so no ATS exception is needed. Verify by building.

- [ ] **Step 7: Build and run — test full extraction flow end-to-end**

1. Settings → add Claude API key
2. Files tab → add a PDF vet report
3. Tap file → FilePreviewView → "Extract Info"
4. Sheet appears, loading spinner, then structured results
5. Edit if needed → "Save to History" → entry appears in History tab

- [ ] **Step 8: Commit**

```bash
git add Home/Pets/Claude/ HomeTests/ExtractionServiceTests.swift
git commit -m "feat: add ExtractionService with Claude API integration and result sheet"
```

---

## Task 14: Final Polish + Remove Sample Data Seeding

**Files:**
- Modify: `Home/Pets/Store/DataStore.swift`

- [ ] **Step 1: Remove hardcoded sample pets from DataStore**

Remove the seed block added in Task 3 Step 3 from `DataStore.init`. The app should start with an empty list.

```swift
// Remove these lines from DataStore.init(directory:):
// if self.data.pets.isEmpty {
//     self.data.pets = [...]
// }
```

- [ ] **Step 2: Add "Add Pet" functionality to PetsView**

The toolbar button already exists with a TODO. Wire it to a minimal add-pet sheet:

```swift
// Add this sheet struct to PetsView.swift (same file):
private struct AddPetSheet: View {
    @Environment(DataStore.self) private var store
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
                        store.data.pets.append(Pet(name: name, type: type, breed: breed))
                        store.save()
                        dismiss()
                    }
                    .disabled(name.isEmpty || breed.isEmpty)
                }
            }
        }
    }
}
```

Update `PetsView` to present `AddPetSheet`:

```swift
// In PetsView.body, update the toolbar button:
Button("Add Pet", systemImage: "plus") { showAddPet = true }

// Add sheet modifier after .navigationDestination:
.sheet(isPresented: $showAddPet) { AddPetSheet() }
```

- [ ] **Step 3: Run all tests**

`Cmd+U`. Expected: all tests pass.

- [ ] **Step 4: Final build and smoke test**

`Cmd+R`. Full user journey:
1. Add a pet
2. Open pet → Vet tab → add vet info
3. Appointments → add appointment → mark done
4. History → add clinical entry with file
5. Events → add vaccine event
6. Files → add standalone photo
7. Tap photo → preview
8. Settings → add Claude API key
9. Files → tap PDF → Extract Info → save to history

- [ ] **Step 5: Final commit**

```bash
git add Home/Pets/ Home/Settings/ Home/Shared/
git commit -m "feat: complete pets detail feature — vet, appointments, history, events, files, Claude extraction"
```
