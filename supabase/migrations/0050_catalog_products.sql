-- Herstellermodelle im Gymtavo-Katalog, Spec
-- 2026-10-10-gymtavo-katalog-geraeteeinrichtung-design.md, Abschnitt 6.1.
--
-- Eigene Tabelle statt equipment_models im Gymtavo-Studio (G2): dort waere
-- jedes Herstellermodell fuer jeden heutigen Leser ein Geraetetyp
-- (Bootstrap, Freies Training, Typsuche) und braeuchte ueberall einen Filter.
-- Geschrieben wird nur vom Import mit der Service-Rolle; Pflege im Portal
-- kommt mit Etappe 6 der Katalog-Spec.

create table public.catalog_products (
  id             uuid primary key default gen_random_uuid(),
  catalog_key    text not null
    constraint catalog_products_catalog_key_format check (catalog_key ~ '^[a-z0-9_]+$')
    -- Ein Constraint statt eines Index: PostgREST-Upserts (on_conflict)
    -- brauchen ihn, wie bei 0048.
    constraint catalog_products_catalog_key_unique unique,
  manufacturer   text not null check (length(trim(manufacturer)) > 0),
  series         text check (series is null or length(trim(series)) > 0),
  name           text not null check (length(trim(name)) > 0),
  model_code     text check (model_code is null or length(trim(model_code)) > 0),
  product_url    text check (product_url is null or product_url like 'https://%'),
  note           text check (note is null or length(trim(note)) > 0),
  photo_path     text,
  photo_rights   text not null default 'pending'
    constraint catalog_products_photo_rights_check check (photo_rights in ('pending', 'cleared')),
  load_unit      text check (load_unit is null or load_unit in ('kg', 'watt', 'level', 'kmh', 'pct', 'rpm')),
  load_step      numeric check (load_step is null or load_step > 0),
  load_min       numeric check (load_min is null or load_min >= 0),
  load_max       numeric,
  secondary_unit text check (secondary_unit is null or secondary_unit in ('kg', 'watt', 'level', 'kmh', 'pct', 'rpm')),
  secondary_step numeric check (secondary_step is null or secondary_step > 0),
  secondary_min  numeric check (secondary_min is null or secondary_min >= 0),
  secondary_max  numeric,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),

  -- G3: ein ungeklaertes Foto kann nie angezeigt werden, auch nicht durch
  -- einen Fehler im Code -- es hat schlicht keinen Pfad.
  constraint catalog_products_foto_nur_geklaert
    check (photo_path is null or photo_rights = 'cleared'),
  -- G4: alles oder nichts. Ein Schritt ohne Einheit haette kein Rad, eine
  -- Einheit ohne Grenzen waere nur halb ein Raster.
  constraint catalog_products_load_all_or_none
    check ((load_unit is null) = (load_step is null)
       and (load_unit is null) = (load_min is null)
       and (load_unit is null) = (load_max is null)),
  constraint catalog_products_load_range
    check (load_max is null or load_max >= load_min),
  constraint catalog_products_secondary_all_or_none
    check ((secondary_unit is null) = (secondary_step is null)
       and (secondary_unit is null) = (secondary_min is null)
       and (secondary_unit is null) = (secondary_max is null)),
  constraint catalog_products_secondary_range
    check (secondary_max is null or secondary_max >= secondary_min)
);

create trigger set_updated_at before update on public.catalog_products
  for each row execute function public.set_updated_at();

-- Ein Produkt passt oft zu mehreren Typen (15 von 114 im Erstbestand).
-- restrict am Typ: ein Typ mit Produkten verschwindet nicht still mitsamt
-- ihrer Zuordnung.
create table public.catalog_product_types (
  product_id         uuid not null references public.catalog_products (id) on delete cascade,
  equipment_model_id uuid not null references public.equipment_models (id) on delete restrict,
  primary key (product_id, equipment_model_id)
);

create index on public.catalog_product_types (equipment_model_id);

-- SECURITY DEFINER wie equipment_models_zuordnung_pruefen (0047): das Ziel
-- liegt in einem Studio, das der Aufrufer nicht lesen muss.
create or replace function public.catalog_product_types_typ_pruefen()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1 from public.equipment_models typ
    where typ.id = new.equipment_model_id
      and public.is_catalog_studio(typ.studio_id)
  ) then
    raise exception 'gymtavo_produkttyp_ungueltig';
  end if;
  return new;
end;
$$;

revoke all on function public.catalog_product_types_typ_pruefen() from public, anon, authenticated;

create trigger catalog_product_types_typ_pruefen
  before insert or update on public.catalog_product_types
  for each row execute function public.catalog_product_types_typ_pruefen();

-- Nur Herkunft: die Werte sind kopiert (G1). Ob das Produkt zum
-- zugeordneten Typ passt, prueft der Trigger bewusst nicht -- sonst
-- scheiterte ein spaeterer Typwechsel im StammdatenFormular, und die
-- Spalte wirkt nicht aufs Training. Die Pruefung beim Anlegen macht
-- createEquipmentModel.
alter table public.equipment_models
  add column catalog_product_id uuid
    constraint equipment_models_catalog_product_id_fkey
    references public.catalog_products (id) on delete restrict;

create index on public.equipment_models (catalog_product_id);

create or replace function public.equipment_models_herkunft_pruefen()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.catalog_product_id is not null and public.is_catalog_studio(new.studio_id) then
    raise exception 'gymtavo_herkunft_ungueltig';
  end if;
  return new;
end;
$$;

revoke all on function public.equipment_models_herkunft_pruefen() from public, anon, authenticated;

create trigger equipment_models_herkunft_pruefen
  before insert or update of catalog_product_id, studio_id on public.equipment_models
  for each row execute function public.equipment_models_herkunft_pruefen();

-- Lesen fuer alle Angemeldeten, wie der uebrige Katalog. Keine
-- Schreib-Policies: es schreibt nur die Service-Rolle. Die Grants zum
-- Schreiben fallen zusaetzlich weg, weil RLS ein TRUNCATE nicht aufhaelt.
alter table public.catalog_products enable row level security;
alter table public.catalog_product_types enable row level security;

create policy catalog_products_select on public.catalog_products
  for select to authenticated using (true);
create policy catalog_product_types_select on public.catalog_product_types
  for select to authenticated using (true);

revoke insert, update, delete, truncate on public.catalog_products from anon, authenticated;
revoke insert, update, delete, truncate on public.catalog_product_types from anon, authenticated;
revoke all on public.catalog_products from anon;
revoke all on public.catalog_product_types from anon;

-- Produktfotos liegen unter <Gymtavo-ID>/catalog/products/; media_select
-- aus 0047 (is_catalog_studio) deckt den Pfad schon ab.
