-- Prepared owner-only App Review setup. NOT a migration; do not auto-run.
-- Requires action-time approval for the scoped persistent clinician grant.
-- Create app-review@samification.example through Auth first; its password is never in this script.
begin;
do $$
declare reviewer uuid; owner_id uuid := '6b0bd18a-4a55-4843-95b6-ee02f507074a'; ward uuid; request uuid; admission uuid; regimen uuid; matches integer; meds jsonb;
begin
 if current_user not in ('postgres','supabase_admin') then raise exception 'Project-owner session required'; end if;
 select id into reviewer from auth.users where lower(email)='app-review@samification.example' and not is_anonymous and email_confirmed_at is not null;
 if reviewer is null then raise exception 'Create and verify the dedicated reviewer identity first'; end if;
 if not exists(select 1 from public.staff_memberships where user_id=owner_id and role='administrator' and active) then raise exception 'Approved owner administrator required'; end if;
 if exists(select 1 from public.staff_memberships where user_id=reviewer and role='administrator') then raise exception 'Reviewer must never be an administrator'; end if;
 lock table public.care_scopes in share row exclusive mode;
 select count(*),min(id::text)::uuid into matches,ward from public.care_scopes where name='App Review Ward (fictional only)';
 if matches>1 then raise exception 'Ambiguous review ward'; end if;
 if ward is null then insert into public.care_scopes(name) values('App Review Ward (fictional only)') returning id into ward; end if;
 if not exists(select 1 from public.care_scopes where id=ward and active) then raise exception 'Review ward inactive'; end if;
 if exists(select 1 from public.staff_memberships where user_id=reviewer and scope_id is distinct from ward) then raise exception 'Reviewer already has access outside review ward'; end if;
 if not exists(select 1 from public.staff_memberships where user_id=reviewer and scope_id=ward and role='clinician' and active) then
   if exists(select 1 from public.staff_memberships where user_id=reviewer and scope_id=ward) then raise exception 'Suspended reviewer needs explicit resumption'; end if;
   perform set_config('request.jwt.claims',jsonb_build_object('sub',reviewer,'is_anonymous',false)::text,true);
   select id into request from public.staff_access_requests where user_id=reviewer and scope_id=ward and status='pending';
   if request is null then request:=public.request_clinician_access(ward,'Apple App Review · Fictional data only'); end if;
   perform set_config('request.jwt.claims',jsonb_build_object('sub',owner_id,'is_anonymous',false)::text,true);
   perform public.decide_clinician_access(request,true,'Owner-approved Apple App Review account; clinician access limited to fictional review ward; no administrator access');
 end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',reviewer,'is_anonymous',false)::text,true);
 admission:=public.create_patient_admission(ward,'APPLE-REVIEW-001 · Fictional patient','a447ba2e-78fd-4c1b-9a61-8f21a395d001');
 meds:='[
 {"id":"a447ba2e-78fd-4c1b-9a61-8f21a395d101","code":"A","name":"Rosuvastatin Tablet","originalName":"Rosuvastatin Tablet","doseMG":10,"strengthMG":10,"periods":["bedtime"],"included":true,"confirmed":true},
 {"id":"a447ba2e-78fd-4c1b-9a61-8f21a395d102","code":"B","name":"Empagliflozin Tablet","originalName":"Empagliflozin Tablet","doseMG":25,"strengthMG":25,"periods":["morning"],"included":true,"confirmed":true},
 {"id":"a447ba2e-78fd-4c1b-9a61-8f21a395d103","code":"C","name":"Vericiguat Tablet","originalName":"Vericiguat Tablet","doseMG":5,"strengthMG":5,"periods":["morning"],"included":true,"confirmed":true},
 {"id":"a447ba2e-78fd-4c1b-9a61-8f21a395d104","code":"D","name":"Allopurinol Tablet","originalName":"Allopurinol Tablet","doseMG":100,"strengthMG":100,"periods":["morning"],"included":true,"confirmed":true}
 ]'::jsonb;
 regimen:=public.confirm_patient_regimen(admission,meds,'App Review fictional fixture only; never a real prescription','a447ba2e-78fd-4c1b-9a61-8f21a395d002');
 perform public.assign_patient_challenge(admission,regimen,true,'a447ba2e-78fd-4c1b-9a61-8f21a395d003');
 if exists(select 1 from public.staff_memberships where user_id=reviewer and (role<>'clinician' or scope_id is distinct from ward)) then raise exception 'Unexpected reviewer access'; end if;
end;
$$;
select u.email,m.role,c.name as ward,m.active from public.staff_memberships m join auth.users u on u.id=m.user_id join public.care_scopes c on c.id=m.scope_id where u.email='app-review@samification.example';
commit;
