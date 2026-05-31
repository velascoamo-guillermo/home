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
  schedule text not null default '',
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
