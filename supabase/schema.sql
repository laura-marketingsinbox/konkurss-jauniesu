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

-- Drošības pārbaude: servera puses garuma limiti (klienta maxlength ir apejams tieši caur API)
alter table public.submissions drop constraint if exists submissions_display_name_len;
alter table public.submissions add constraint submissions_display_name_len check (char_length(display_name) <= 120);
alter table public.submissions drop constraint if exists submissions_email_len;
alter table public.submissions add constraint submissions_email_len check (char_length(email) <= 255);
alter table public.submissions drop constraint if exists submissions_mascot_name_len;
alter table public.submissions add constraint submissions_mascot_name_len check (char_length(mascot_name) <= 120);
alter table public.submissions drop constraint if exists submissions_story_len;
alter table public.submissions add constraint submissions_story_len check (char_length(story) <= 3000);
alter table public.submissions drop constraint if exists submissions_parent_name_len;
alter table public.submissions add constraint submissions_parent_name_len check (parent_name is null or char_length(parent_name) <= 120);
alter table public.submissions drop constraint if exists submissions_parent_email_len;
alter table public.submissions add constraint submissions_parent_email_len check (parent_email is null or char_length(parent_email) <= 255);
alter table public.submissions drop constraint if exists submissions_prize_label_len;
alter table public.submissions add constraint submissions_prize_label_len check (prize_label is null or char_length(prize_label) <= 200);

-- Lapas sadaļu ieslēgšana/izslēgšana (TOP 5 un uzvarētāju podests) — pārvalda admin panelī
create table if not exists public.site_settings (
  key text primary key,
  value boolean not null default false
);
insert into public.site_settings (key, value) values
  ('show_top5', false),
  ('show_winners', false)
on conflict (key) do nothing;

-- Katrs jauns iesniegums vienmēr sākas kā "pending", un TOP5/uzvarētāja lauki vienmēr
-- sākas tukši — tos drīkst iestatīt TIKAI administrators (ar UPDATE, ne INSERT laikā).
-- Bez šī uzbrucējs varētu jau iesniegšanas brīdī pats sevi atzīmēt par uzvarētāju.
create or replace function public.force_pending_status()
returns trigger language plpgsql as $$
begin
  new.status := 'pending';
  new.is_finalist := false;
  new.winner_rank := null;
  new.prize_label := null;
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

-- ===================== FAILU KRĀTUVE =====================
-- Divu krātuvju modelis drošības labad:
--   "submissions"    — privāta, šeit nonāk VISI augšupielādētie faili (arī neapstiprinātie).
--                       Tikai administrators var tos lasīt/dzēst. Nekad anon nevar lasīt/uzskaitīt.
--   "approved-media" — publiska, šeit administrators PĀRKOPĒ failu tikai tad, kad apstiprina
--                       iesniegumu. Tas ir vienīgais veids, kā fails kļūst publiski redzams.
-- Iemesls: Supabase krātuves "list"/"sign" darbības neievēro rindas līmeņa RLS noteikumus
-- tā, kā to dara parastie datu pieprasījumi — pārbaudot atklājās, ka jebkurš varēja uzskaitīt
-- un lejupielādēt VISUS failus (arī neapstiprinātos) neatkarīgi no smalkiem RLS nosacījumiem.
-- Publiska/privāta krātuve ir vienkāršāks un uzticamāks nodalījums, kas no šīs problēmas nav atkarīgs.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('submissions', 'submissions', false, 52428800, array['image/jpeg','image/png','image/webp','image/gif','image/heic','video/mp4','video/quicktime','video/webm'])
on conflict (id) do update set
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('approved-media', 'approved-media', true, 52428800, array['image/jpeg','image/png','image/webp','image/gif','image/heic','video/mp4','video/quicktime','video/webm'])
on conflict (id) do update set
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Ietver arī "authenticated" lomu: ja pārlūkā ir aktīva admin sesija (no admin.html),
-- tā pati lapa publiskajai formai izmantos to pašu sesiju, nevis anon lomu.
drop policy if exists "public can upload submissions" on storage.objects;
create policy "public can upload submissions" on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'submissions');

drop policy if exists "admins can read submissions" on storage.objects;
create policy "admins can read submissions" on storage.objects
  for select to authenticated
  using (bucket_id = 'submissions' and public.is_admin());

-- SVARĪGI: anon vairs NAV nekādas SELECT/list tiesības uz "submissions" krātuvi.
-- (Iepriekšējais noteikums ar "exists (... status='approved')" izrādījās neefektīvs,
-- jo krātuves list/sign darbības to neievēroja pareizi.)
drop policy if exists "public can view approved files" on storage.objects;

-- Administratori var dzēst failus (piem., noraidītus vai dzēšanas pieprasījumus)
drop policy if exists "admins can delete submissions" on storage.objects;
create policy "admins can delete submissions" on storage.objects
  for delete to authenticated
  using (bucket_id = 'submissions' and public.is_admin());

-- "approved-media" ir publiska krātuve (public=true), tāpēc jebkurš var LASĪT no tās
-- bez RLS noteikuma — tas ir paredzēts un droši, jo šeit nonāk tikai apstiprināti darbi.
-- Rakstīt (kopēt apstiprinātu failu) drīkst tikai administrators.
drop policy if exists "admins can write approved media" on storage.objects;
create policy "admins can write approved media" on storage.objects
  for all to authenticated
  using (bucket_id = 'approved-media' and public.is_admin())
  with check (bucket_id = 'approved-media' and public.is_admin());

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
