-- Konkursa "Radi nākamo Inbox.lv talismanu" datubāzes shēma
-- Palaid šo VIENU REIZI Supabase panelī: SQL Editor -> New query -> ielīmē -> Run

create extension if not exists "pgcrypto";

-- Administratoru saraksts (kam ir pieeja moderācijas panelim)
create table if not exists public.admins (
  email text primary key
);
insert into public.admins (email) values ('laura.eisaka@co.inbox.lv')
  on conflict (email) do nothing;

-- Iesniegumu tabula
create table if not exists public.submissions (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  display_name text not null,
  email text not null,
  mascot_name text not null,
  story text not null,
  file_path text not null,
  file_type text not null check (file_type in ('image', 'video')),
  is_minor boolean not null default false,
  parent_name text,
  parent_email text,
  consent_rules boolean not null default false,
  consent_rights_transfer boolean not null default false,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected'))
);

-- Uzvarētāju podesta lauki (aizpilda administrators pēc konkursa noslēguma)
alter table public.submissions add column if not exists winner_rank int;
alter table public.submissions add column if not exists prize_label text;

-- Katrs jauns iesniegums vienmēr sākas kā "pending", lai nevarētu apiet moderāciju
create or replace function public.force_pending_status()
returns trigger language plpgsql as $$
begin
  new.status := 'pending';
  return new;
end;
$$;

drop trigger if exists trg_force_pending on public.submissions;
create trigger trg_force_pending
  before insert on public.submissions
  for each row execute function public.force_pending_status();

alter table public.submissions enable row level security;

-- Jebkurš var iesniegt pieteikumu, ja atzīmēti obligātie piekrišanas lauki
drop policy if exists "public can submit" on public.submissions;
create policy "public can submit" on public.submissions
  for insert to anon
  with check (
    consent_rules = true
    and consent_rights_transfer = true
    and (is_minor = false or (parent_name is not null and parent_email is not null))
  );

-- Publiski redzami tikai apstiprinātie darbi (galerijai)
drop policy if exists "public can view approved" on public.submissions;
create policy "public can view approved" on public.submissions
  for select to anon
  using (status = 'approved');

-- Administratori (no admins saraksta) redz un pārvalda visu
drop policy if exists "admins manage all" on public.submissions;
create policy "admins manage all" on public.submissions
  for all to authenticated
  using (auth.jwt() ->> 'email' in (select email from public.admins))
  with check (auth.jwt() ->> 'email' in (select email from public.admins));

alter table public.admins enable row level security;
drop policy if exists "admins can read allow-list" on public.admins;
create policy "admins can read allow-list" on public.admins
  for select to authenticated
  using (auth.jwt() ->> 'email' in (select email from public.admins));

-- Failu krātuve (attēli/video) — privāta, pieeja tikai caur RLS noteikumiem
insert into storage.buckets (id, name, public)
values ('submissions', 'submissions', false)
on conflict (id) do nothing;

drop policy if exists "public can upload submissions" on storage.objects;
create policy "public can upload submissions" on storage.objects
  for insert to anon
  with check (bucket_id = 'submissions');

drop policy if exists "admins can read submissions" on storage.objects;
create policy "admins can read submissions" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'submissions'
    and auth.jwt() ->> 'email' in (select email from public.admins)
  );

drop policy if exists "public can view approved files" on storage.objects;
create policy "public can view approved files" on storage.objects
  for select to anon
  using (
    bucket_id = 'submissions'
    and exists (
      select 1 from public.submissions s
      where s.file_path = storage.objects.name
        and s.status = 'approved'
    )
  );

-- Administratori var dzēst failus (piem., noraidītus vai dzēšanas pieprasījumus)
drop policy if exists "admins can delete submissions" on storage.objects;
create policy "admins can delete submissions" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'submissions'
    and auth.jwt() ->> 'email' in (select email from public.admins)
  );
