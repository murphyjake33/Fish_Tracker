-- Run this once in Supabase: SQL Editor > New query > paste > Run
create table public.profiles (id uuid primary key references auth.users on delete cascade, name text, species text[] not null default '{}');
create table public.groups (id uuid primary key default gen_random_uuid(), name text not null, code text unique not null, created_by uuid default auth.uid());
create table public.group_members (group_id uuid references public.groups on delete cascade, user_id uuid references auth.users on delete cascade default auth.uid(), primary key (group_id, user_id));
create table public.trips (
  id uuid primary key default gen_random_uuid(), owner uuid not null default auth.uid() references auth.users on delete cascade,
  group_id uuid references public.groups on delete set null,
  loc text not null, date date not null, start_t time, end_t time, target text,
  air text, wind text, pres text, sky text, water text, tide text, notes text,
  catches jsonb not null default '[]', created_at timestamptz default now());

create function public.is_member(gid uuid) returns boolean language sql security definer stable set search_path=public as
$$ select exists(select 1 from group_members where group_id=gid and user_id=auth.uid()) $$;

create function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as
$$ begin insert into profiles(id,name) values(new.id, coalesce(new.raw_user_meta_data->>'name','')); return new; end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create function public.create_group(gname text) returns public.groups language plpgsql security definer set search_path=public as
$$ declare g public.groups; begin
  insert into groups(name,code,created_by) values(gname, upper(substr(md5(random()::text),1,5)), auth.uid()) returning * into g;
  insert into group_members(group_id,user_id) values(g.id, auth.uid()); return g; end $$;
create function public.join_group(gcode text) returns uuid language plpgsql security definer set search_path=public as
$$ declare gid uuid; begin
  select id into gid from groups where code=upper(gcode);
  if gid is null then raise exception 'not found'; end if;
  insert into group_members(group_id,user_id) values(gid, auth.uid()) on conflict do nothing; return gid; end $$;
revoke all on function public.create_group(text), public.join_group(text) from public, anon;
grant execute on function public.create_group(text), public.join_group(text) to authenticated;

alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.trips enable row level security;

create policy "own or groupmate profile" on profiles for select to authenticated using (id=auth.uid() or exists(select 1 from group_members a join group_members b on a.group_id=b.group_id where a.user_id=auth.uid() and b.user_id=profiles.id));
create policy "insert own profile" on profiles for insert to authenticated with check (id=auth.uid());
create policy "update own profile" on profiles for update to authenticated using (id=auth.uid());
create policy "members see group" on groups for select to authenticated using (public.is_member(id));
create policy "members see members" on group_members for select to authenticated using (user_id=auth.uid() or public.is_member(group_id));
create policy "leave group" on group_members for delete to authenticated using (user_id=auth.uid());
create policy "see own and group trips" on trips for select to authenticated using (owner=auth.uid() or (group_id is not null and public.is_member(group_id)));
create policy "add own trips" on trips for insert to authenticated with check (owner=auth.uid() and (group_id is null or public.is_member(group_id)));
create policy "edit own trips" on trips for update to authenticated using (owner=auth.uid());
create policy "delete own trips" on trips for delete to authenticated using (owner=auth.uid());
