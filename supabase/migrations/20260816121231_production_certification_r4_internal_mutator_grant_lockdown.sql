do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='app_private'
      and p.prosecdef
      and p.provolatile='v'
  loop
    execute format(
      'revoke all on function %s from public, anon, authenticated',
      r.signature
    );
  end loop;
end
$$;
