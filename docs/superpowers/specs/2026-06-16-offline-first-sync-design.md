# Offline-First Sync Engine — Design

**Date:** 2026-06-16
**Branch:** feature/home-widget (sync work may warrant its own branch)
**Status:** Approved direction, pending spec review

## Problem

`SupabaseStore` is online-only. Every mutation runs `await client…execute()` **then**
updates the in-memory array. With no connection the remote call throws, the array is
never updated, and the edit is silently lost (e.g. editing stock in a supermarket with
no signal). On launch `loadAll()` fetches everything fresh — no data is available offline.

The widget reads a JSON snapshot from the App Group, written by `WidgetSnapshotWriter`
from `SupabaseStore`. With no in-memory data offline, the widget falls back to the
placeholder.

## Goals

- Offline-first for all data **except binary files** (`pet-files` storage stays online-only).
- Edits made offline persist locally and apply immediately (optimistic).
- A sync engine flushes local changes to Supabase when connectivity returns.
- Multi-device, single account: **last-write-wins (LWW)** by `updated_at`.
- Deletes propagate across devices via **soft-delete tombstones** (`deleted_at`).
- View layer and widget snapshot path stay essentially unchanged.

## Non-Goals

- Per-field merge / CRDTs / real-time concurrent collaboration (single account only).
- Offline binary file uploads (`uploadFile`, `updatePetPhoto`, storage removes stay online;
  they no-op gracefully offline and surface a "needs connection" state).
- Background sync while the app is suspended (sync runs on launch, foreground, and
  reconnect while running; widget-triggered background refresh is out of scope).

## Entities In Scope

9 entities (all except `pet_files`):
`pets`, `veterinarian`, `appointments`, `clinical_entries`, `pet_events`,
`household_tasks`, `task_sections`, `stock_products`, `meals`, `meal_products`.

All use **client-generated UUID primary keys** — confirmed in the schema — so offline
inserts need no server round-trip for IDs.

## Architecture

```
Views (SwiftUI, unchanged)
        │ read arrays / call mutation methods
        ▼
SupabaseStore  (@Observable facade, MainActor)
        │ hydrate on launch / write on mutate
        ▼
LocalStore  (SQLite, source of truth)  ──►  Outbox table (pending ops)
        ▲                                          │
        │ reconcile (LWW)                          │ drain
        │                                          ▼
SyncEngine  ◄──── Reachability (NWPathMonitor) ──► SupabaseClient (remote)
```

- **SupabaseStore stays the `@Observable` facade.** Its typed arrays remain the single
  thing views observe. On launch it **hydrates arrays from `LocalStore`** instead of from
  the network. The `client` and remote calls move behind `SyncEngine`.
- **LocalStore** is the durable on-disk source of truth (SQLite via system `libsqlite3`,
  no third-party dep). One table per entity plus an `outbox` table.
- **Mutations become optimistic and transactional.** A single SQLite transaction writes
  the entity row (with bumped `updated_at`, or sets `deleted_at` for deletes) **and**
  appends an outbox row. Then the in-memory array updates. Atomic and crash-safe.
- **SyncEngine** owns connectivity and reconciliation. On reconnect / launch / foreground:
  1. **Push:** drain outbox in order → apply to Supabase. On success, delete the outbox row.
  2. **Pull:** fetch rows changed since last sync cursor → reconcile into LocalStore by LWW.
  3. Re-hydrate `SupabaseStore` arrays from LocalStore, then write the widget snapshot.

### Why this shape

- Durable, transactional, indexed, incremental — scales past JSON snapshots.
- View layer and `WidgetSnapshotWriter` barely move (they still read store arrays).
- All offline complexity is isolated behind `LocalStore` / `SyncEngine` boundaries and
  is unit-testable without a simulator or network.

## Components

### LocalStore (new, `Home/Shared/Persistence/`)
- Owns the SQLite connection. Schema bootstrap + lightweight internal migrations
  (a `schema_version` pragma).
- One table per in-scope entity, columns mirroring the Codable model + `updated_at`,
  `deleted_at` (nullable). Row payload stored as the entity's JSON blob plus the few
  columns needed for querying/sync (`id`, `updated_at`, `deleted_at`); keeps the mapping
  between Swift structs and rows trivial and resilient to model changes.
- API: `fetchAll<T>(_:) -> [T]` (excludes tombstoned rows), `upsert<T>(_:)`,
  `softDelete(table:id:at:)`, and the outbox ops below. All `nonisolated`/actor-isolated
  off the main actor; callers `await`.
- Concurrency: implemented as an `actor` (or a serial executor) so SQLite access is
  single-threaded and `Sendable`-safe under Swift 6 strict concurrency.

### Outbox (table inside LocalStore)
- Columns: `seq` (autoincrement, ordering), `op` (`insert|update|delete`), `table_name`,
  `entity_id`, `payload` (JSON), `updated_at`, `attempts`, `last_error`.
- Drained in `seq` order. Coalescing: a new op for an `entity_id` that already has a
  pending op may replace it (last local state wins) to avoid redundant network calls.

### Reachability (new)
- Thin wrapper over `NWPathMonitor`, exposes an `AsyncStream<Bool>` of online state.
- `MainActor`-published `isOnline` for UI affordances ("offline — changes will sync").

### SyncEngine (new)
- Holds the `SupabaseClient`, `LocalStore`, `Reachability`.
- `sync()` = push then pull, guarded by a single-flight flag (no overlapping syncs).
- **Push:** for each outbox op, map to the existing Supabase call (`insert`/`update`/
  `delete`). Delete = remote update setting `deleted_at` (soft) so other devices see it.
- **Pull:** `select().gt("updated_at", cursor)` per table; reconcile each row: if
  remote `updated_at` >= local, upsert locally; tombstones (`deleted_at != null`) remove
  from the visible set. Advance the per-table cursor (persisted in LocalStore).
- Triggers: app launch, `scenePhase` → `.active`, and Reachability `false → true`.

### SupabaseStore (modified, facade)
- `init` builds the `LocalStore` + `SyncEngine`.
- `loadAll()` → `hydrate()` from LocalStore (instant, offline-capable), then kick a
  background `syncEngine.sync()`.
- Every mutation method changes from "remote then array" to
  "`localStore` transaction (row + outbox) → update array → fire-and-forget `sync()`".
  Public method signatures are unchanged, so callers/views don't change.
- File methods (`uploadFile`, `updatePetPhoto`, storage removes) stay online-only and
  throw a clear `offline` error when there's no connection.

### Widget
- No data-flow change: `WidgetSnapshotWriter.write(from:)` still reads store arrays, which
  are now always populated from LocalStore — so the widget shows real data offline too.
- Remaining widget work is the **App Group entitlement finish** (separate small follow-up,
  already partly staged).

## Data Model Changes (Supabase migration)

New migration adding to all 9 in-scope tables:
- `updated_at timestamptz not null default now()`
- `deleted_at timestamptz` (nullable)
- A trigger (or app-set value) to bump `updated_at` on update.
- RLS policies updated so soft-deleted rows are still selectable for sync (filter in app,
  not by hard RLS exclusion), and `deleted_at` is writable.
- Index on `updated_at` per table for efficient incremental pull.

Swift models gain `updatedAt: Date` and `deletedAt: Date?` with matching `CodingKeys`.

## Error Handling

- **Offline mutation:** succeeds locally; outbox holds the op; UI shows a subtle
  "pending sync" / offline indicator. No error thrown to the user.
- **Push failure (per op):** increment `attempts`, store `last_error`, keep the op,
  retry on next sync with backoff. Poison ops (repeated failures) surface in a
  diagnostics view but never block the queue head indefinitely (skip-after-N with a flag).
- **Pull failure:** abort pull, keep last cursor, retry next trigger. Local data remains
  usable.
- **Conflict:** LWW by `updated_at`; the losing write is overwritten (acceptable per
  multi-device single-account scope).
- **File ops offline:** throw `SyncError.requiresConnection`; caller shows a retry prompt.

## Testing

- **LocalStore:** unit tests for upsert/fetch/soft-delete, transaction atomicity
  (row + outbox committed together; rollback on failure), schema migration.
- **Outbox:** ordering, coalescing, attempts/backoff bookkeeping.
- **SyncEngine push:** outbox → correct Supabase calls (against a mock/fake client
  boundary), success clears op, failure retains + records error.
- **SyncEngine pull/reconcile:** LWW resolution both directions, tombstone removal,
  cursor advancement. Pure reconcile function tested in isolation.
- **Reachability:** state-transition stream (injected path monitor).
- **Existing `WidgetSnapshotWriter` tests** stay green (unchanged input shape).

## Rollout / Sequencing

This spec yields independent implementation chunks (each its own plan step, testable):
1. Migration + model fields (`updated_at`, `deleted_at`).
2. `LocalStore` (SQLite, schema, CRUD, tests).
3. `Outbox` (table + ops + coalescing, tests).
4. `Reachability` (NWPathMonitor stream).
5. `SyncEngine` push (drain outbox → Supabase).
6. `SyncEngine` pull + reconcile (LWW, cursor, tombstones).
7. Rewire `SupabaseStore` to facade (hydrate + optimistic mutations).
8. Triggers (launch / foreground / reconnect) + offline UI indicator.
9. Widget App Group entitlement finish (small, can land independently).

## Open Questions

- Outbox payload: store full-row JSON (simple, chosen) vs. field-level diffs (smaller,
  more complex). Chosen: full-row — simplest, LWW makes diffs unnecessary.
- Tombstone purge policy: when to hard-delete soft-deleted rows server-side
  (e.g. a scheduled Supabase job after N days). Deferred — not needed for correctness.
