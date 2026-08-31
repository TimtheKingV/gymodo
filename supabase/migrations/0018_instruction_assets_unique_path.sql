-- Ein Upload bricht im Studio-WLAN ab und wird wiederholt. Ohne Eindeutigkeit
-- legt der zweite Anlauf eine zweite Zeile auf dasselbe Storage-Objekt an --
-- getTagContext greift auf instruction_assets[0] zu und zoege danach
-- willkuerlich eine der beiden. Der wiederholte Upload muss stattdessen an
-- derselben Zeile landen (upsert on conflict).
alter table public.instruction_assets
  add constraint instruction_assets_link_path_key
    unique (equipment_model_exercise_id, storage_path);
