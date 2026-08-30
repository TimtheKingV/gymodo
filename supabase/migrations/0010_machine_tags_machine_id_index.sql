-- Spec 7.5 verlangt einen Index auf jeder Fremdschluesselspalte. machine_id
-- bekam in 0008 einen Fremdschluessel (on delete restrict), aber keinen
-- Index -- ohne ihn scannt jedes "delete from machines" machine_tags
-- sequenziell, um zu pruefen, ob die Zeile referenziert wird.
create index on public.machine_tags (machine_id);
