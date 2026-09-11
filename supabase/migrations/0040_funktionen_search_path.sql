-- Der Supabase-Linter meldet fuer vier Funktionen ein veraenderliches
-- search_path (0011_function_search_path_mutable). Ohne festes search_path
-- entscheidet der AUFRUFER, in welchem Schema ein unqualifizierter Name
-- gesucht wird -- wer ein Schema vor public haengen darf, kann eine eigene
-- Funktion oder einen eigenen Operator unterschieben und laeuft im Kontext
-- des Aufrufs mit.
--
-- Keine dieser vier ist SECURITY DEFINER, der Hebel ist also kleiner als bei
-- den RPCs. Er ist trotzdem da, und bei storage_studio_id am deutlichsten:
-- die Funktion entscheidet in vier RLS-Policies auf storage.objects
-- (media_select/insert/update/delete), zu welchem Studio ein Objekt gehoert,
-- und wird mit dem search_path der Storage-API ausgewertet. Dasselbe gilt
-- abgeschwaecht fuer is_valid_setting_choices (CHECK-Constraint auf
-- equipment_setting_definitions) und set_updated_at (Trigger auf fuenf
-- Tabellen).
--
-- `set search_path = ''` statt einer Liste mit public: die vier Rumpfe
-- referenzieren AUSSCHLIESSLICH Eingebautes -- now(), cardinality(),
-- unnest(), length(), trim(), count(), split_part(), substr(), floor(),
-- random() sowie die Typen text/uuid/boolean und der Operator ~*. pg_catalog
-- wird laut Postgres-Doku immer implizit durchsucht, auch bei leerem
-- search_path; ein Verweis auf public gibt es in keiner der vier, also
-- braucht keine davon public im Pfad. Leer ist damit die engste Fassung,
-- die noch funktioniert.
--
-- ALTER statt CREATE OR REPLACE: die Rumpfe bleiben Byte fuer Byte gleich.
-- Ein neu getippter Rumpf waere die Gelegenheit, versehentlich Verhalten zu
-- aendern -- an einer Funktion, die in RLS-Policies und einem
-- CHECK-Constraint haengt, ist das die teuerste Art von Fluechtigkeitsfehler.
alter function public.set_updated_at() set search_path = '';
alter function public.is_valid_setting_choices(text[]) set search_path = '';
alter function public.storage_studio_id(text) set search_path = '';
alter function public.generate_join_code() set search_path = '';
