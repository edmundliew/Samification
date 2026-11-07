-- Owner-only, explicit approval required for this scoped clinician grant.
-- Same-account testing only: target must already be a verified active administrator.
-- Supply samification.test_staff_id with the approved Auth UUID after BEGIN, in the same execution.
-- The role persists until explicitly suspended; it is scoped only to the fictional ward below.
begin;
do $$
declare wanted uuid; scope uuid; request uuid; matches integer;
begin
 if current_user not in ('postgres','supabase_admin') then raise exception 'Project-owner SQL session required'; end if;
 wanted:=nullif(current_setting('samification.test_staff_id',true),'')::uuid;
 if wanted is null or not exists(select 1 from auth.users where id=wanted and is_anonymous=false and email_confirmed_at is not null and last_sign_in_at is not null)
  or not exists(select 1 from public.staff_memberships where user_id=wanted and role='administrator' and active) then
  raise exception 'Verified, explicitly approved administrator identity required';
 end if;
 lock table public.care_scopes in share row exclusive mode;
 select count(*), min(id::text)::uuid into matches,scope from public.care_scopes where name='Samification Test Ward (fictional)';
 if matches>1 then raise exception 'Ambiguous test ward'; end if;
 if scope is null then insert into public.care_scopes(name) values('Samification Test Ward (fictional)') returning id into scope; end if;
 if not exists(select 1 from public.care_scopes where id=scope and active) then raise exception 'Test ward is inactive'; end if;
 if exists(select 1 from public.staff_memberships where user_id=wanted and role='clinician' and scope_id=scope and active) then return; end if;
 if exists(select 1 from public.staff_memberships where user_id=wanted and role='clinician' and scope_id=scope) then raise exception 'Existing suspended membership requires explicit resumption'; end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',wanted,'is_anonymous',false)::text,true);
 select id into request from public.staff_access_requests where user_id=wanted and scope_id=scope and status='pending';
 if request is null then request:=public.request_clinician_access(scope,'Pilot test clinician'); end if;
 perform public.decide_clinician_access(request,true,'Explicit account-owner approval for same-account testing in the fictional ward only');
end;
$$;
commit;
