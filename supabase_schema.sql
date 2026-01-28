-- Enable necessary extensions
create extension if not exists "uuid-ossp";

-- PROFILES TABLE (Links to auth.users)
create table public.profiles (
  id uuid references auth.users not null primary key,
  display_name text,
  avatar_url text,
  username text unique,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Turn on RLS
alter table public.profiles enable row level security;

-- Profiles Policies
create policy "Public profiles are viewable by everyone."
  on profiles for select
  using ( true );

create policy "Users can insert their own profile."
  on profiles for insert
  with check ( auth.uid() = id );

create policy "Users can update own profile."
  on profiles for update
  using ( auth.uid() = id );

-- Function to handle new user signup automatically
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'avatar_url');
  return new;
end;
$$ language plpgsql security definer;

-- Trigger for new user signup
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();


-- STORIES TABLE
create table public.stories (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references public.profiles(id) not null,
  media_url text not null,
  media_type text not null, -- 'image' or 'video'
  caption text,
  background_color text,
  created_at timestamptz default now(),
  expires_at timestamptz default (now() + interval '24 hours'),
  view_count int default 0,
  viewers text[] default '{}', -- Array of user IDs who viewed
  
  constraint proper_media_type check (media_type in ('image', 'video'))
);

-- Turn on RLS
alter table public.stories enable row level security;

-- Stories Policies
create policy "Stories are viewable by everyone (until expired)."
  on stories for select
  using ( expires_at > now() );

create policy "Users can create stories."
  on stories for insert
  with check ( auth.uid() = user_id );

create policy "Users can delete their own stories."
  on stories for delete
  using ( auth.uid() = user_id );

create policy "Users can update their stories (e.g. view count)."
  on stories for update
  using ( auth.uid() = user_id );


-- STORY VIEWS TABLE (For detailed analytics/tracking)
create table public.story_views (
  id uuid default uuid_generate_v4() primary key,
  story_id uuid references public.stories(id) on delete cascade not null,
  viewer_id uuid references public.profiles(id) not null,
  viewed_at timestamptz default now(),
  unique(story_id, viewer_id) -- Prevent duplicate view records
);

alter table public.story_views enable row level security;

create policy "Users can insert their own views."
  on story_views for insert
  with check ( auth.uid() = viewer_id );

create policy "Users can see who viewed their stories."
  on story_views for select
  using ( 
    auth.uid() = (select user_id from public.stories where id = story_id) 
  );


-- POSTS TABLE
create table public.posts (
  id uuid default uuid_generate_v4() primary key,
  author_id uuid references public.profiles(id) not null,
  content text,
  media_url text,
  media_type text default 'none',
  created_at timestamptz default now(),
  likes_count int default 0,
  comments_count int default 0,
  repost_count int default 0,
  is_verified boolean default false,
  channel_id text default 'general',
  is_anonymous boolean default false,
  poll_data jsonb,   -- Store Map<String, dynamic> as JSON
  repost_data jsonb  -- Store Map<String, dynamic> as JSON
);

alter table public.posts enable row level security;

-- Posts Policies
create policy "Posts are viewable by everyone."
  on posts for select
  using ( true );

create policy "Users can create posts."
  on posts for insert
  with check ( auth.uid() = author_id );

create policy "Users can update their own posts."
  on posts for update
  using ( auth.uid() = author_id );

create policy "Users can delete their own posts."
  on posts for delete
  using ( auth.uid() = author_id );


-- STORAGE BUCKETS (Optional: You might need to run this in the Storage-specific editor, but good to note)
-- insert into storage.buckets (id, name, public) values ('abuad-assets', 'abuad-assets', true);
