-- Owner-only bootstrap, NOT an application migration or an automatic deployment step.
-- First verify the intended Auth user's email and successful sign-in in the live project.
-- Obtain explicit approval immediately before granting the administrator role.
-- In the SAME SQL execution, add after BEGIN:
-- select set_config('samification.bootstrap_user_id','VERIFIED_AUTH_USER_UUID',true);
-- Never fill the UUID from client metadata or an unverified registration.
begin;
do $$
declare wanted uuid; target auth.users;
begin
 if current_user not in ('postgres','supabase_admin') then raise exception 'Project-owner SQL session required'; end if;
 wanted := nullif(current_setting('samification.bootstrap_user_id',true),'')::uuid;
 if wanted is null then raise exception 'Verified Auth UUID must be explicitly supplied'; end if;
 lock table public.staff_memberships in share row exclusive mode;
 if exists(select 1 from public.staff_memberships where role='administrator') then raise exception 'Initial administrator already provisioned; use a reviewed access-management procedure'; end if;
 select * into target from auth.users where id=wanted for update;
 if not found or target.is_anonymous is distinct from false or target.email is null
  or target.email_confirmed_at is null or target.last_sign_in_at is null then
  raise exception 'A verified permanent email identity with successful sign-in is required';
 end if;
 insert into public.staff_memberships(user_id,role,scope_id) values(wanted,'administrator',null);
 insert into public.access_audit_events(actor_id,subject_id,action,reason)
 values(wanted,wanted,'initial_administrator_bootstrapped','Explicit identity-owner approval; executed in project-owner SQL session, not an authenticated application RPC.');
end;
$$;
commit;
