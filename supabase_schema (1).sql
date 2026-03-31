-- Supabase Schema & Storage Configuration

-- 1. Create a Storage Bucket for App Media
-- The app uses a single bucket named 'abuad' for all media (avatars, posts, stories, etc.)
insert into storage.buckets (id, name, public)
values ('abuad', 'abuad', true)
on conflict (id) do nothing;

-- 2. Storage Policies (Row Level Security)

-- Policy: Allow public read access to all files in the 'abuad' bucket
-- This is required so that anyone (including unauthenticated users viewings posts) can see images.
create policy "Public Access"
on storage.objects for select
using ( bucket_id = 'abuad' );

-- Policy: Allow authenticated users to upload files
-- This permits any signed-in user to upload avatars, post images, story videos, etc.
create policy "Authenticated Users can Upload"
on storage.objects for insert
with check (
  bucket_id = 'abuad' 
  and auth.role() = 'authenticated'
);

-- Policy: Allow users to update/delete their own files
-- We assume files are stored with paths that might not strictly contain the UID in a way RLS can easily verify solely by path structure 
-- without strict naming conventions. 
-- However, a common secure pattern is to store files under folders named after the user ID (e.g., `uid/filename`).
-- If your app follows `uid/...` structure, use the following:
-- create policy "Users can update own files"
-- on storage.objects for update
-- using ( bucket_id = 'abuad' and auth.uid()::text = (storage.foldername(name))[1] );

-- Ideally, for a simple permission set where users just need to upload:
-- The INSERT policy above is sufficient for uploading.
-- For DELETING (e.g. deleting a post deleting its image), we can allow owners to delete.
-- Note: This requires the file path to contain the user ID or metadata to match.
-- As a fallback for broader access if paths vary:
create policy "Authenticated Users can Update/Delete"
on storage.objects for all
using (
    bucket_id = 'abuad' 
    and auth.role() = 'authenticated' 
    and (storage.foldername(name))[1] = auth.uid()::text 
);


-- 3. (Optional) Database Tables
-- If you plan to move user data or other collections to Supabase SQL in the future, 
-- here is an example structure mirroring your Firestore 'users' collection.

/*
create table public.users (
  id uuid references auth.users not null primary key,
  email text,
  display_name text,
  username text unique,
  avatar_url text,
  is_admin boolean default false,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS
alter table public.users enable row level security;

-- Policies
create policy "Public profiles are viewable by everyone."
  on public.users for select
  using ( true );

create policy "Users can insert their own profile."
  on public.users for insert
  with check ( auth.uid() = id );

create policy "Users can update own profile."
  on public.users for update
  using ( auth.uid() = id );
*/
