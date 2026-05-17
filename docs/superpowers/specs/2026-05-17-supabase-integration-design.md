# Supabase Integration Design

**Date:** 2026-05-17  
**Status:** Approved

---

## Overview

Replace the local JSON `DataStore` with Supabase (online-only). Two users share a single Supabase project. No auth — anon key embedded via `Config.xcconfig` (excluded from git). Files stored in Supabase Storage.

---

## Credentials Management

**`Config.xcconfig`** — gitignored, manually created on each dev machine:
```
SUPABASE_URL = https://xxxx.supabase.co
SUPABASE_ANON_KEY = eyJh...
```

**`Info.plist`** — reads from xcconfig at build time:
```xml
<key>SUPABASE_URL</key><string>$(SUPABASE_URL)</string>
<key>SUPABASE_ANON_KEY</key><string>$(SUPABASE_ANON_KEY)</string>
```

**`SupabaseConfig.swift`** — reads from bundle (in git, no secrets):
```swift
enum SupabaseConfig {
    static let url    = URL(string: Bundle.main.infoDictionary!["SUPABASE_URL"] as! String)!
    static let anonKey = Bundle.main.infoDictionary!["SUPABASE_ANON_KEY"] as! String
}
```

`.gitignore` must include `*.xcconfig`.

---

## Supabase Schema

RLS disabled — personal app, anon key has full access.

```sql
-- pets
create table pets (
  id uuid primary key,
  name text not null,
  type text not null,
  breed text not null,
  photo_url text
);

-- veterinarian (single shared row, upsert by fixed id)
create table veterinarian (
  id uuid primary key,
  name text not null,
  clinic_name text not null,
  phone text not null,
  address text not null,
  notes text not null
);

-- appointments
create table appointments (
  id uuid primary key,
  pet_id uuid references pets(id) on delete cascade,
  date timestamptz not null,
  reason text not null,
  notes text not null,
  status text not null  -- 'upcoming' | 'done' | 'cancelled'
);

-- clinical_entries
create table clinical_entries (
  id uuid primary key,
  pet_id uuid references pets(id) on delete cascade,
  date timestamptz not null,
  title text not null,
  description text not null
);

-- pet_events
create table pet_events (
  id uuid primary key,
  pet_id uuid references pets(id) on delete cascade,
  date timestamptz not null,
  title text not null,
  category text not null,  -- 'vaccine'|'grooming'|'medication'|'weight'|'other'
  notes text not null,
  value text
);

-- pet_files
create table pet_files (
  id uuid primary key,
  pet_id uuid references pets(id) on delete cascade,
  storage_path text not null,   -- path in Supabase Storage bucket
  source_type text not null,    -- 'photo' | 'document' | 'scan'
  linked_to_type text not null, -- 'event' | 'clinicalEntry' | 'standalone'
  linked_to_id uuid,            -- null when standalone
  created_at timestamptz not null
);
```

**Storage bucket:** `pet-files` (private). Path convention: `{petId}/{fileId}.{ext}`.

Deleting a pet cascades to all related rows. Deleting a file row does NOT auto-delete the Storage object — `SupabaseStore.deleteFile` handles both explicitly.

---

## Swift Models

All models use `CodingKeys` to map camelCase ↔ snake_case. `FileLink` enum replaced by two flat fields.

```swift
// Existing models updated:

struct Pet: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var type: String
    var breed: String
    var photoUrl: String? = nil
    enum CodingKeys: String, CodingKey {
        case id, name, type, breed, photoUrl = "photo_url"
    }
}

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

struct Appointment: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var petId: UUID
    var date: Date
    var reason: String
    var notes: String
    var status: AppointmentStatus
    enum CodingKeys: String, CodingKey {
        case id, date, reason, notes, status, petId = "pet_id"
    }
}

struct ClinicalEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var petId: UUID
    var date: Date
    var title: String
    var description: String
    // fileIds removed — derived via SupabaseStore.files(for:linkedToType:linkedToId:)
    enum CodingKeys: String, CodingKey {
        case id, date, title, description, petId = "pet_id"
    }
}

struct PetEvent: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var petId: UUID
    var date: Date
    var title: String
    var category: EventCategory
    var notes: String
    var value: String?
    // fileIds removed
    enum CodingKeys: String, CodingKey {
        case id, date, title, category, notes, value, petId = "pet_id"
    }
}

struct PetFile: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var petId: UUID
    var storagePath: String       // replaces filename
    var sourceType: FileSourceType
    var linkedToType: String      // replaces FileLink enum
    var linkedToId: UUID?
    var createdAt: Date
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

`FileLink` enum and `AppData` struct are deleted. `FileSourceType` remains.

---

## SupabaseStore

`@Observable final class SupabaseStore` — injected via `.environment` from `ContentView`, same pattern as current `DataStore`.

### State

```swift
var pets: [Pet] = []
var veterinarian: Veterinarian? = nil
var appointments: [Appointment] = []
var clinicalEntries: [ClinicalEntry] = []
var events: [PetEvent] = []
var files: [PetFile] = []
var isLoading: Bool = false
var error: String? = nil
```

### Interface

```swift
// Bootstrap
func loadAll() async throws

// Pets
func addPet(_ pet: Pet) async throws
func deletePet(_ pet: Pet) async throws   // deletes Storage files first, then DB row (cascade handles rest)

// Vet
func upsertVet(_ vet: Veterinarian) async throws

// Appointments
func addAppointment(_ a: Appointment) async throws
func updateAppointmentStatus(_ a: Appointment, status: AppointmentStatus) async throws
func deleteAppointment(_ a: Appointment) async throws

// Clinical entries
func addClinicalEntry(_ entry: ClinicalEntry) async throws
func deleteClinicalEntry(_ entry: ClinicalEntry) async throws  // also deletes linked files

// Events
func addEvent(_ event: PetEvent) async throws
func deleteEvent(_ event: PetEvent) async throws  // also deletes linked files

// Files
func uploadFile(data: Data, ext: String, petId: UUID,
                linkedToType: String, linkedToId: UUID?) async throws -> PetFile
func deleteFile(_ file: PetFile) async throws   // Storage removal + DB row

// In-memory filters (same as DataStore)
func appointments(for petId: UUID) -> [Appointment]
func clinicalEntries(for petId: UUID) -> [ClinicalEntry]
func events(for petId: UUID) -> [PetEvent]
func files(for petId: UUID, linkedToType: String? = nil) -> [PetFile]
func fileUrl(for file: PetFile) -> URL   // signed URL from Supabase Storage
```

### Error handling

`loadAll()` failures: `ContentView` catches, shows `ContentUnavailableView` with retry button.  
Mutation failures: each call site wraps in `do/catch`, shows `.alert` to the user. No silent failures.

---

## ContentView Changes

```swift
struct ContentView: View {
    @State private var store = SupabaseStore()

    var body: some View {
        Group {
            if store.isLoading {
                ProgressView("Loading...")
            } else if let error = store.error {
                ContentUnavailableView("Connection Error",
                    systemImage: "wifi.slash",
                    description: Text(error))
                    // retry button
            } else {
                MainTabView()
            }
        }
        .environment(store)
        .task { try? await store.loadAll() }
    }
}
```

---

## File URL Access

Supabase Storage private bucket — files accessed via signed URLs (1 hour expiry) or public URLs if bucket is set to public. For a personal app, **public bucket** is simplest: `photoUrl` and `storagePath` resolve to a direct CDN URL. `fileUrl(for:)` returns `URL(string: "https://{project}.supabase.co/storage/v1/object/public/pet-files/\(file.storagePath)")!`.

---

## Files to Remove

- `Home/Pets/Store/AppData.swift`
- `Home/Pets/Store/DataStore.swift`
- `Home/Auth/AuthManager.swift` (already unused)
- `Home/Auth/LoginView.swift` (already unused)

---

## Files to Add

- `Home/Shared/Services/SupabaseStore.swift`
- `Home/Shared/Config/SupabaseConfig.swift`
- `Config.xcconfig` (gitignored)

## Files to Modify

- All model files — add `CodingKeys`, remove `fileIds`, `photoFilename` → `photoUrl`
- `PetFile.swift` — replace `FileLink` with flat fields
- `ContentView.swift` — inject `SupabaseStore`, show loading state
- All tab views + sheets — remove `store.save()` calls, make mutations `async`, add error handling
- `FilePickerCoordinator` callers — `uploadFile` replaces `saveFile`
- `FilePreviewView` — `fileUrl(for:)` returns remote URL
- `ExtractionService` — reads from remote URL instead of local path
- `.gitignore` — add `*.xcconfig`

---

## Out of Scope

- Real-time sync (Supabase Realtime)
- Per-user auth
- Push notifications for appointments
- Offline support
