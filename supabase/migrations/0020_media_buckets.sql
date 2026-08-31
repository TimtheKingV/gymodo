-- Zwei private Buckets fuer die Studioinhalte. Beide privat: das
-- Einweisungsvideo zeigt einen Menschen bei der Vorfuehrung, das sind
-- Personendaten des Trainers (Spec 6.8). Ausgeliefert wird ausschliesslich
-- ueber kurzlebige signierte URLs.
--
-- Die Grenzen hier sind die *aeussere* Schranke: der Storage-Dienst prueft
-- den vom Client behaupteten Content-Type und die Bytegroesse. Beides ist
-- faelschbar, deshalb prueft die Domain-Schicht zusaetzlich den tatsaechlichen
-- Inhalt (packages/domain/src/media.ts). Diese Zeilen ersetzen das nicht,
-- sie fangen nur den Grossteil frueh und billig ab.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  -- 10 MiB. Ein Geraetefoto aus dem Trainerhandy liegt weit darunter; mehr
  -- braucht niemand, um ein Geraet wiederzuerkennen.
  ('equipment-photos', 'equipment-photos', false, 10485760,
   array['image/jpeg', 'image/png']),
  -- 50 MiB. 45 Sekunden 720p HEVC vom iPhone landen bei rund 25 MiB; der
  -- Rest ist Reserve fuer H.264-Aufnahmen. Kein Transcoding (Spec 6.8),
  -- also muss die Rohaufnahme hineinpassen.
  ('instruction-videos', 'instruction-videos', false, 52428800,
   array['video/mp4', 'video/quicktime'])
on conflict (id) do update set
  public             = excluded.public,
  file_size_limit    = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Der erste Pfadabschnitt ist die studio_id -- daran haengt die gesamte
-- Mandantentrennung im Storage. Ein direkter Cast waere gefaehrlich: ein
-- Objektname ohne gueltige UUID vorn liesse den Cast scheitern und die Policy
-- mit einem Fehler statt mit einer Ablehnung enden. Diese Funktion liefert
-- stattdessen NULL, und is_studio_member(NULL) ist schlicht falsch.
create or replace function public.storage_studio_id(p_name text)
returns uuid
language sql
immutable
as $$
  select case
    when split_part(p_name, '/', 1)
         ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then split_part(p_name, '/', 1)::uuid
  end;
$$;

-- storage.objects gehoert supabase_storage_admin, nicht der Migrationsrolle.
-- Ein "set local role supabase_storage_admin" scheitert deshalb (postgres ist
-- dort weder Mitglied noch Superuser); die Policies selbst laesst Supabase
-- die Migrationsrolle dagegen anlegen.

-- Lesen darf jedes Mitglied des Studios: das Foto und das Einweisungsvideo
-- sind genau fuer es gemacht. Signierte URLs entstehen ueber diese Policy --
-- createSignedUrl braucht select auf das Objekt.
create policy media_select on storage.objects
  for select to authenticated
  using (
    bucket_id in ('equipment-photos', 'instruction-videos')
    and public.is_studio_member(public.storage_studio_id(name))
  );

-- Schreiben nur Trainer und Owner, und nur in den Ordner des eigenen Studios.
create policy media_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id in ('equipment-photos', 'instruction-videos')
    and public.is_studio_staff(public.storage_studio_id(name))
  );

-- using prueft das alte Objekt, with check das neue: ein Objekt laesst sich
-- weder aus einem fremden Ordner heraus noch in einen fremden hinein
-- umbenennen.
create policy media_update on storage.objects
  for update to authenticated
  using (
    bucket_id in ('equipment-photos', 'instruction-videos')
    and public.is_studio_staff(public.storage_studio_id(name))
  )
  with check (
    bucket_id in ('equipment-photos', 'instruction-videos')
    and public.is_studio_staff(public.storage_studio_id(name))
  );

-- Anders als bei machine_tags gibt es hier einen Loeschpfad: ein
-- verwackeltes Video muss ersetzbar sein, und ein verwaistes Objekt nach
-- einem abgebrochenen Upload muss wieder wegkoennen.
create policy media_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id in ('equipment-photos', 'instruction-videos')
    and public.is_studio_staff(public.storage_studio_id(name))
  );
