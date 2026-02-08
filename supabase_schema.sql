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
-- Policy: Allow authenticated users to upload files
-- This permits any signed-in user to upload avatars, post images, story videos, etc.
create policy "Authenticated Users can Upload"
on storage.objects for insert
with check (
  bucket_id = 'abuad' 
  and auth.role() = 'authenticated'
);

-- ============================================================================
-- Granular Folder Policies (Matches Firestore Rules Logic)
-- ============================================================================

-- 1. USER PROFILES (avatars, covers)
-- Path: users/{userId}/*
create policy "Users can update/delete own profile media"
on storage.objects for all
using (
    bucket_id = 'abuad' 
    and (storage.foldername(name))[1] = 'users'
    and (storage.foldername(name))[2] = auth.uid()::text
);

-- 2. POSTS MEDIA
-- Path: posts/{userId}/* (Files organized by uploader ID)
create policy "Users can manage their post media"
on storage.objects for all
using (
    bucket_id = 'abuad' 
    and (storage.foldername(name))[1] = 'posts'
    and (storage.foldername(name))[2] = auth.uid()::text
);

-- 3. CHAT MEDIA
-- Path: chat/{channelId}/{userId}/*
create policy "Users can upload to chat"
on storage.objects for insert
with check (
    bucket_id = 'abuad'
    and (storage.foldername(name))[1] = 'chat'
    and auth.role() = 'authenticated'
);

-- 4. STORIES (Ephemeral)
-- Path: stories/{userId}/*
create policy "Users manage own stories"
on storage.objects for all
using (
    bucket_id = 'abuad'
    and (storage.foldername(name))[1] = 'stories'
    and (storage.foldername(name))[2] = auth.uid()::text
);

-- Fallback: Allow Admins Full Access
-- Assuming admin users have a distinct role or metadata claim. 
-- For Supabase, often handled via service_role key, but RLS can check claims:
-- create policy "Admins have full access"
-- on storage.objects for all
-- using ( bucket_id = 'abuad' and auth.jwt() ->> 'role' = 'admin' );


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
