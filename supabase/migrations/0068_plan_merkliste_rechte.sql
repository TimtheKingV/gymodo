-- Rechte der Merkliste auf das Noetige beschraenken (Nachtrag zu 0067).
--
-- Supabase vergibt auf neue Tabellen im Schema public von Haus aus alle Rechte
-- an `authenticated`. 0067 hat nur select, insert, delete dazugegeben, aber
-- die uebrigen Rechte nicht entzogen: update, truncate, references, trigger
-- standen weiter offen. Update blockiert RLS (keine Policy), truncate aber
-- nicht -- RLS gilt dafuer nicht. Ueber die API ist truncate nicht erreichbar,
-- sauber ist es trotzdem nicht. Auf Prod am 28.10. so angewendet.

revoke update, truncate, references, trigger on public.plan_merkliste from authenticated;
