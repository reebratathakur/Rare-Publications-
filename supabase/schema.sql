
-- RARE PUBLICATIONS DATABASE

create extension if not exists pgcrypto;

create table if not exists public.profiles(
 id uuid primary key references auth.users(id) on delete cascade,
 username text unique not null,
 display_name text not null,
 department text not null default 'Both'
  check(department in ('Writer','Filmmaker','Both')),
 organisation_role text not null default 'Member'
  check(organisation_role in ('Member','Project Leader','Moderator','Head')),
 account_status text not null default 'Pending'
  check(account_status in ('Pending','Approved','Rejected','Suspended')),
 bio text default '',
 created_at timestamptz not null default now()
);

create table if not exists public.projects(
 id uuid primary key default gen_random_uuid(),
 name text not null,
 description text default '',
 department text not null default 'Both',
 status text not null default 'Active',
 created_by uuid not null references auth.users(id),
 deadline date,
 progress int not null default 0 check(progress between 0 and 100),
 created_at timestamptz default now()
);

create table if not exists public.notes(
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 title text not null,
 content text not null,
 created_at timestamptz default now(),
 updated_at timestamptz default now()
);

create table if not exists public.conversations(
 id uuid primary key default gen_random_uuid(),
 conversation_type text not null default 'group',
 conversation_name text,
 created_by uuid references auth.users(id),
 created_at timestamptz default now()
);

create table if not exists public.conversation_members(
 conversation_id uuid references public.conversations(id) on delete cascade,
 user_id uuid references auth.users(id) on delete cascade,
 joined_at timestamptz default now(),
 last_read_at timestamptz,
 primary key(conversation_id,user_id)
);

create table if not exists public.messages(
 id uuid primary key default gen_random_uuid(),
 conversation_id uuid not null references public.conversations(id) on delete cascade,
 sender_id uuid not null references auth.users(id),
 message_text text not null,
 created_at timestamptz default now(),
 edited_at timestamptz,
 deleted_at timestamptz
);

create table if not exists public.library_items(
 id uuid primary key default gen_random_uuid(),
 creator_id uuid not null references auth.users(id),
 title text not null,
 description text default '',
 category text default '',
 department text default 'Both',
 cover_url text,
 status text not null default 'Pending',
 rejection_reason text,
 public_display boolean not null default false,
 created_at timestamptz default now(),
 updated_at timestamptz default now()
);

-- Automatically create pending profiles on registration.

create or replace function public.rp_handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
 v_username text;
 v_department text;
begin
 v_username := lower(trim(coalesce(
  new.raw_user_meta_data->>'username',
  split_part(new.email, '@', 1)
 )));

 v_department := coalesce(
  new.raw_user_meta_data->>'department',
  'Both'
 );

 if v_department not in ('Writer','Filmmaker','Both') then
  v_department := 'Both';
 end if;

 insert into public.profiles(
  id, username, display_name, department, account_status
 )
 values(
  new.id,
  v_username,
  coalesce(
   nullif(trim(new.raw_user_meta_data->>'display_name'),''),
   v_username
  ),
  v_department,
  'Pending'
 );

 return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.rp_handle_new_user();

-- Permission helper functions

create or replace function public.rp_is_approved()
returns boolean
language sql stable security definer set search_path=public
as $$
 select exists(
  select 1 from profiles
  where id=auth.uid() and account_status='Approved'
 )
$$;

create or replace function public.rp_is_head()
returns boolean
language sql stable security definer set search_path=public
as $$
 select exists(
  select 1 from profiles
  where id=auth.uid()
  and account_status='Approved'
  and organisation_role='Head'
 )
$$;

create or replace function public.rp_is_chat_member(cid uuid)
returns boolean
language sql stable security definer set search_path=public
as $$
 select exists(
  select 1 from conversation_members
  where conversation_id=cid and user_id=auth.uid()
 )
$$;

-- Enable security

alter table profiles enable row level security;
alter table projects enable row level security;
alter table notes enable row level security;
alter table conversations enable row level security;
alter table conversation_members enable row level security;
alter table messages enable row level security;
alter table library_items enable row level security;

-- Profile policies

create policy "profile self read"
on profiles for select to authenticated
using(id=auth.uid());

create policy "approved directory"
on profiles for select to authenticated
using(rp_is_approved() and account_status='Approved');

create policy "head read all profiles"
on profiles for select to authenticated
using(rp_is_head());

create policy "head review profiles"
on profiles for update to authenticated
using(rp_is_head()) with check(rp_is_head());

-- Project policies

create policy "project visible to approved"
on projects for select to authenticated
using(rp_is_approved());

create policy "approved create projects"
on projects for insert to authenticated
with check(rp_is_approved() and created_by=auth.uid());

create policy "creator or head update projects"
on projects for update to authenticated
using(created_by=auth.uid() or rp_is_head())
with check(created_by=auth.uid() or rp_is_head());

-- Notes

create policy "own notes"
on notes for all to authenticated
using(user_id=auth.uid() and rp_is_approved())
with check(user_id=auth.uid() and rp_is_approved());

-- Chat policies

create policy "conversation visible to member"
on conversations for select to authenticated
using(rp_is_chat_member(id));

create policy "chat membership visible to self"
on conversation_members for select to authenticated
using(user_id=auth.uid() or rp_is_head());

create policy "chat messages visible to members"
on messages for select to authenticated
using(rp_is_chat_member(conversation_id));

create policy "approved members send"
on messages for insert to authenticated
with check(
 sender_id=auth.uid()
 and rp_is_approved()
 and rp_is_chat_member(conversation_id)
);

create policy "own message edit"
on messages for update to authenticated
using(sender_id=auth.uid() and rp_is_chat_member(conversation_id))
with check(sender_id=auth.uid());

-- Library policies

create policy "own work or public work"
on library_items for select to authenticated
using(
 creator_id=auth.uid()
 or (status='Approved' and public_display=true)
 or rp_is_head()
);

create policy "public approved works"
on library_items for select to anon
using(status='Approved' and public_display=true);

create policy "approved submit work"
on library_items for insert to authenticated
with check(
 creator_id=auth.uid()
 and rp_is_approved()
 and status='Pending'
);

create policy "head moderate works"
on library_items for update to authenticated
using(rp_is_head()) with check(rp_is_head());

-- Application review function

create or replace function public.rp_review_application(
 target_user uuid,
 new_status text
)
returns void
language plpgsql security definer set search_path=public
as $$
begin
 if not public.rp_is_head() then
  raise exception 'Head access required';
 end if;

 if new_status not in ('Approved','Rejected','Suspended') then
  raise exception 'Invalid status';
 end if;

 update profiles
 set account_status=new_status
 where id=target_user;
end;
$$;

revoke all on function public.rp_review_application(uuid,text) from public;
grant execute on function public.rp_review_application(uuid,text) to authenticated;
