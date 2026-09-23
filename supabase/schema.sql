-- Konkursa "Radi nākamo Inbox.lv talismanu" datubāzes shēma
-- Palaid šo VIENU REIZI Supabase panelī: SQL Editor -> New query -> ielīmē -> Run
-- (Šo failu var palaist atkārtoti bez riska — tas katru reizi pārraksta noteikumus, nevis dublē tos.)

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

-- TOP 5 finālista atzīme (balsošanas posmam)
alter table public.submissions add column if not exists is_finalist boolean not null default false;

-- Lapas sadaļu ieslēgšana/izslēgšana (TOP 5 un uzvarētāju podests) — pārvalda admin panelī
create table if not exists public.site_settings (
  key text primary key,
  value boolean not null default false
);
insert into public.site_settings (key, value) values
  ('show_top5', false),
  ('show_winners', false)
on conflict (key) do nothing;

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

-- Palīgfunkcija, kas pārbauda, vai pieteikušais lietotājs ir administrators.
-- "security definer" ir svarīgs: tas ļauj funkcijai pašai izlasīt admins tabulu,
-- neizraisot bezgalīgu ciklu ar admins tabulas pašas RLS noteikumu.
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.admins where email = auth.jwt() ->> 'email'
  );
$$;

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

-- Administratori redz un pārvalda visu
drop policy if exists "admins manage all" on public.submissions;
create policy "admins manage all" on public.submissions
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

alter table public.admins enable row level security;
drop policy if exists "admins can read allow-list" on public.admins;
create policy "admins can read allow-list" on public.admins
  for select to authenticated
  using (public.is_admin());

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
  using (bucket_id = 'submissions' and public.is_admin());

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
  using (bucket_id = 'submissions' and public.is_admin());

-- Lapas sadaļu ieslēgšanas/izslēgšanas iestatījumi: visi var lasīt, tikai admin var mainīt
alter table public.site_settings enable row level security;

drop policy if exists "anyone can read settings" on public.site_settings;
create policy "anyone can read settings" on public.site_settings
  for select
  using (true);

drop policy if exists "admins can update settings" on public.site_settings;
create policy "admins can update settings" on public.site_settings
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());
