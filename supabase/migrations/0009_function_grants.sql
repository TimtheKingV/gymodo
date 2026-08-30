-- revoke all ... from public entfernt nur das PUBLIC-Default-Recht. Supabase
-- gewaehrt EXECUTE auf neue public-Funktionen zusaetzlich per ALTER DEFAULT
-- PRIVILEGES an anon, authenticated und service_role -- diese Grants muessen
-- explizit entzogen werden, sonst ist jede SECURITY DEFINER-Funktion faktisch
-- fuer alle drei Rollen aufrufbar.
revoke all on function public.is_studio_member(uuid) from public, anon, authenticated, service_role;
grant execute on function public.is_studio_member(uuid) to authenticated;

revoke all on function public.is_studio_staff(uuid) from public, anon, authenticated, service_role;
grant execute on function public.is_studio_staff(uuid) to authenticated;

revoke all on function public.resolve_tag_fallback(text) from public, anon, authenticated, service_role;
grant execute on function public.resolve_tag_fallback(text) to anon;
