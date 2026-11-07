-- Owner-only integration test. Entire transaction is ROLLED BACK.
-- Requires the approved same-account test clinician role and samification.test_staff_id.
-- This simulates database JWT claims; it does NOT create usable Auth sessions or test email delivery.
-- Fixture Auth rows, patient records, actions and reviews never commit. Sequence gaps may occur.
begin;
create temporary table samification_walkthrough_results(step text, passed boolean);
do $$
declare staff uuid; patient uuid:=gen_random_uuid(); scope uuid; admission uuid; regimen uuid; assignment uuid:=gen_random_uuid(); pairing jsonb; result jsonb; med_a uuid:=gen_random_uuid(); med_b uuid:=gen_random_uuid(); meds jsonb; right_tray jsonb; request uuid:=gen_random_uuid(); review uuid:=gen_random_uuid(); session uuid;
begin
 if current_user not in ('postgres','supabase_admin') then raise exception 'Project-owner SQL session required'; end if;
 staff:=nullif(current_setting('samification.test_staff_id',true),'')::uuid;
 select c.id into scope from public.care_scopes c join public.staff_memberships m on m.scope_id=c.id
 where c.name='Samification Test Ward (fictional)' and c.active and m.user_id=staff and m.role='clinician' and m.active;
 if scope is null then raise exception 'Approved fictional-ward clinician required'; end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',staff,'is_anonymous',false)::text,true);
 admission:=public.create_patient_admission(scope,'ROLLBACK-ONLY fictional patient',gen_random_uuid());
 meds:=jsonb_build_array(
 jsonb_build_object('id',med_a,'code','A','name','Fictional Tablet A','originalName','Fictional Tablet A','doseMG',20,'strengthMG',10,'periods',jsonb_build_array('morning','bedtime'),'included',true,'confirmed',true),
 jsonb_build_object('id',med_b,'code','B','name','Fictional Tablet B','originalName','Fictional Tablet B','doseMG',5,'strengthMG',5,'periods',jsonb_build_array('afternoon'),'included',true,'confirmed',true));
 regimen:=public.confirm_patient_regimen(admission,meds,'Fictional test CSV only',gen_random_uuid());
 perform public.assign_patient_challenge(admission,regimen,false,assignment);
 pairing:=public.issue_patient_pairing(admission);
 insert into samification_walkthrough_results values('1. Clinician created and assigned confirmed regimen',regimen is not null);
 -- This fixture is uncommitted and has no password or issued Auth token.
 insert into auth.users(id,is_anonymous) values(patient,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',patient,'is_anonymous',true)::text,true);
 session:=public.claim_patient_pairing(pairing->>'token');
 insert into samification_walkthrough_results values('2. Patient paired to own admission',session is not null);
 insert into samification_walkthrough_results values('3. Patient received assigned challenge',jsonb_array_length(public.patient_challenge_inbox())=1);
 perform public.patient_challenge_action(assignment,gen_random_uuid(),'start','{}',0);
 result:=public.patient_challenge_action(assignment,request,'submit',jsonb_build_object('morning',jsonb_build_object(med_a::text,1)),1);
 insert into samification_walkthrough_results values('4. Incorrect first tray scored by server',result->'score'->>'missingTablets'='4' and result->'score'->>'presentAdministrations'='1' and result->'score'->>'exactQuantities'='0');
 perform public.patient_challenge_action(assignment,request,'submit',jsonb_build_object('morning',jsonb_build_object(med_a::text,1)),1);
 insert into samification_walkthrough_results values('5. Duplicate request did not add an attempt',jsonb_array_length(public.patient_challenge_history(assignment))=2);
 perform public.patient_challenge_action(assignment,gen_random_uuid(),'hint','{}',2);
 right_tray:=jsonb_build_object('morning',jsonb_build_object(med_a::text,2),'bedtime',jsonb_build_object(med_a::text,2),'afternoon',jsonb_build_object(med_b::text,1));
 result:=public.patient_challenge_action(assignment,gen_random_uuid(),'submit',right_tray,3);
 insert into samification_walkthrough_results values('6. Correct retry retained hint and attempt counts',result->>'attempt'='2' and result->>'hintsBefore'='1' and result->'score'->'findings'='[]'::jsonb);
 result:=public.patient_challenge_action(assignment,gen_random_uuid(),'finish',right_tray,4);
 insert into samification_walkthrough_results values('7. Final evidence preserves first error and retry',result->>'firstAttemptCorrect'='false' and result->>'firstCorrectAttempt'='2' and result->>'retries'='1');
 perform set_config('request.jwt.claims',jsonb_build_object('sub',staff,'is_anonymous',false)::text,true);
 perform public.review_challenge(assignment,review,'supervised_assessment','Fictional test review; not a self-administration approval');
 insert into samification_walkthrough_results values('8. Clinician review saved separately',exists(select 1 from public.challenge_reviews where id=review));
 perform public.revoke_patient_session(session);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',patient,'is_anonymous',true)::text,true);
 insert into samification_walkthrough_results values('9. Revoked patient session lost inbox access',public.patient_challenge_inbox()='[]'::jsonb);
 if exists(select 1 from samification_walkthrough_results where passed is distinct from true) then raise exception 'Workflow assertion failed'; end if;
end;
$$;
select * from samification_walkthrough_results order by step;
rollback;
