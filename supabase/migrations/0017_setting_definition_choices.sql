-- kind = 'enum' stand seit 0004 im Check-Constraint, war aber unbenutzbar:
-- es gab keine Spalte fuer die erlaubten Werte. "Sitzposition = A|B|C" liess
-- sich nicht ausdruecken, und ein Einstellparameter-Editor haette eine
-- Auswahl anbieten muessen, die nirgends steht.

-- Ein Check-Constraint darf keine Unterabfrage enthalten, die Pruefung auf
-- Duplikate und Leerwerte braucht aber eine Aggregation ueber unnest. Deshalb
-- eine immutable Hilfsfunktion. Sie liest keine Tabelle und gibt nur einen
-- Boolean zurueck -- anders als is_studio_member/is_studio_staff braucht sie
-- daher weder SECURITY DEFINER noch eine eigene Rechtevergabe.
create or replace function public.is_valid_setting_choices(p_values text[])
returns boolean
language sql
immutable
as $$
  select p_values is not null
     and cardinality(p_values) >= 2
     and not exists (
       select 1 from unnest(p_values) v
       where v is null or length(trim(v)) = 0
     )
     and cardinality(p_values) = (
       select count(distinct v) from unnest(p_values) v
     );
$$;

alter table public.equipment_setting_definitions
  add column allowed_values text[];

-- Mindestens zwei verschiedene, nicht leere Werte: eine Auswahl mit einem
-- einzigen Eintrag ist keine Auswahl, sondern ein fester Wert -- das Mitglied
-- bekaeme ein Auswahlfeld ohne Alternative.
alter table public.equipment_setting_definitions
  add constraint equipment_setting_definitions_enum_needs_choices
    check (kind <> 'enum' or public.is_valid_setting_choices(allowed_values));

-- Umgekehrt darf ein Zahlenparameter keine Werteliste tragen. Sonst stuenden
-- min/max/step und eine Auswahl nebeneinander und es waere offen, welches
-- von beiden die Eingabe validiert.
alter table public.equipment_setting_definitions
  add constraint equipment_setting_definitions_number_has_no_choices
    check (kind <> 'number' or allowed_values is null);
