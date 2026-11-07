-- Immutable, server-scored evidence. All mutations use scoped RPCs.
begin;
create table public.challenge_runs (
 id uuid primary key references public.clinical_assignments(id),
 admission_id uuid not null references public.patient_admissions(id),
 patient_user_id uuid not null references auth.users(id),
 started_at timestamptz not null default clock_timestamp(),
 prior_exposure boolean not null,
 finished_at timestamptz
);
create table public.challenge_actions (
 id uuid primary key,
 run_id uuid not null references public.challenge_runs(id),
 sequence integer not null,
 actor_id uuid not null references auth.users(id),
 recorded_at timestamptz not null default clock_timestamp(),
 kind text not null check(kind in ('start','submit','hint','reference','finish')),
 payload jsonb not null,
 result jsonb not null,
 unique(run_id,sequence)
);
create table public.challenge_reviews (
 id uuid primary key,
 run_id uuid not null references public.challenge_runs(id),
 clinician_id uuid not null references auth.users(id),
 recorded_at timestamptz not null default clock_timestamp(),
 decision text not null check(decision in ('education_required','supervised_assessment','reviewed')),
 note text not null check(length(note) between 1 and 4000)
);
create index challenge_runs_admission_idx on public.challenge_runs(admission_id);
create index challenge_actions_run_idx on public.challenge_actions(run_id,sequence);
alter table public.challenge_runs enable row level security;
alter table public.challenge_actions enable row level security;
alter table public.challenge_reviews enable row level security;
revoke all on public.challenge_runs,public.challenge_actions,public.challenge_reviews from public,anon,authenticated;
grant select on public.challenge_runs,public.challenge_actions,public.challenge_reviews to authenticated;
create policy runs_read on public.challenge_runs for select to authenticated using(samification_private.can_manage_admission(admission_id));
create policy actions_read on public.challenge_actions for select to authenticated using(exists(select 1 from public.challenge_runs r where r.id=run_id and samification_private.can_manage_admission(r.admission_id)));
create policy reviews_read on public.challenge_reviews for select to authenticated using(exists(select 1 from public.challenge_runs r where r.id=run_id and samification_private.can_manage_admission(r.admission_id)));

-- Canonical tray shape: {morning:{medicationUUID:count},...}. Empty compartments may be omitted.
create function samification_private.score_tray(medications jsonb,tray jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
declare m jsonb; p text; k text; v jsonb; actual integer; needed integer; total integer:=0; exact integer:=0;
 present integer:=0; unexpected integer:=0; omissions integer:=0; extra integer:=0; missing integer:=0; findings jsonb:='[]';
begin
 if not samification_private.valid_medication_snapshot(medications) then raise exception 'Invalid confirmed regimen'; end if;
 if tray is null or jsonb_typeof(tray)<>'object' or octet_length(tray::text)>20000 then raise exception 'Invalid tray'; end if;
 for p,v in select * from jsonb_each(tray) loop
  if p not in ('morning','afternoon','evening','bedtime') or jsonb_typeof(v)<>'object' then raise exception 'Invalid compartment'; end if;
  for k,m in select * from jsonb_each(v) loop
   if not exists(select 1 from jsonb_array_elements(medications) x where lower(x->>'id')=k)
    or jsonb_typeof(m)<>'number' or m::text !~ '^(0|[1-9]|1[0-2])$' then raise exception 'Invalid tablet count or medication'; end if;
  end loop;
 end loop;
 for m in select * from jsonb_array_elements(medications) loop
  foreach p in array array['morning','afternoon','evening','bedtime'] loop
   needed:=case when (m->'periods') ? p then round((m->>'doseMG')::numeric/(m->>'strengthMG')::numeric)::integer else 0 end;
   actual:=coalesce((tray->p->>lower(m->>'id'))::integer,0);
   if needed>0 then total:=total+1; if actual=needed then exact:=exact+1; end if;
    if actual>0 then present:=present+1; else omissions:=omissions+1; end if;
   elsif actual>0 then unexpected:=unexpected+1; end if;
   extra:=extra+greatest(0,actual-needed); missing:=missing+greatest(0,needed-actual);
   if actual<>needed then findings:=findings||jsonb_build_array(jsonb_build_object('medicationID',m->>'id','period',p,'expected',needed,'actual',actual)); end if;
  end loop;
 end loop;
 return jsonb_build_object('validRegimen',true,'expectedAdministrations',total,'exactQuantities',exact,'presentAdministrations',present,
 'unexpectedPlacements',unexpected,'omissions',omissions,'extraTablets',extra,'missingTablets',missing,'findings',findings);
end;
$$;

create function public.patient_challenge_action(wanted_assignment uuid,request_id uuid,action_kind text,action_payload jsonb,expected_previous integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c public.clinical_assignments; r public.challenge_runs; previous public.challenge_actions; last_submission public.challenge_actions;
 snapshot jsonb; result jsonb; n integer; submissions integer; hints integer; refs integer; first_correct integer; correct boolean;
begin
 if request_id is null or action_kind is null or action_kind not in ('start','submit','hint','reference','finish')
  or action_payload is null or jsonb_typeof(action_payload)<>'object' or octet_length(action_payload::text)>20000 then raise exception 'Invalid action'; end if;
 select * into c from public.clinical_assignments where id=wanted_assignment;
 if not found then raise exception 'Patient challenge unavailable' using errcode='42501'; end if;
 -- Same admission-first lock order as discharge, supersession and session revocation.
 perform 1 from public.patient_admissions where id=c.admission_id for update;
 if not samification_private.has_patient_session(c.admission_id) then raise exception 'Active patient pairing required' using errcode='42501'; end if;
 select * into c from public.clinical_assignments where id=wanted_assignment for update;
 select * into r from public.challenge_runs where id=c.id;
 if found and r.patient_user_id<>auth.uid() then raise exception 'Challenge belongs to another patient session' using errcode='42501'; end if;
 select * into previous from public.challenge_actions where id=request_id;
 if found then
  if previous.run_id<>c.id or previous.actor_id<>auth.uid() or previous.kind<>action_kind or previous.payload<>action_payload then raise exception 'Request identifier already used'; end if;
  return previous.result;
 end if;
 if expected_previous is null or expected_previous<>(select count(*) from public.challenge_actions where run_id=c.id) then raise exception 'Stale action sequence; reload challenge'; end if;
 if c.status not in ('assigned','in_progress') or r.finished_at is not null then raise exception 'Challenge is closed or superseded'; end if;
 select medications into snapshot from public.regimen_versions where id=c.regimen_id;
 if action_kind='start' then
  if r.id is not null or action_payload<>'{}'::jsonb then raise exception 'Challenge already started'; end if;
  insert into public.challenge_runs(id,admission_id,patient_user_id,prior_exposure)
  values(c.id,c.admission_id,auth.uid(),exists(select 1 from public.challenge_runs x join public.clinical_assignments y on y.id=x.id where x.admission_id=c.admission_id and y.regimen_id=c.regimen_id)) returning * into r;
  update public.clinical_assignments set status='in_progress' where id=c.id;
 elsif r.id is null then raise exception 'Start the challenge first'; end if;
 select count(*)::integer+1 into n from public.challenge_actions where run_id=c.id;
 select count(*)::integer into submissions from public.challenge_actions where run_id=c.id and kind='submit';
 select count(*)::integer into hints from public.challenge_actions where run_id=c.id and kind='hint';
 select count(*)::integer into refs from public.challenge_actions where run_id=c.id and kind='reference';
 select * into last_submission from public.challenge_actions where run_id=c.id and kind='submit' order by sequence desc limit 1;
 result:=jsonb_build_object('sequence',n,'kind',action_kind,'priorExposure',r.prior_exposure,'submissions',submissions,'hints',hints,'references',refs,'scoringVersion','TRAY-0.1-PROPOSED');
 if action_kind='submit' then
  result:=result||jsonb_build_object('score',samification_private.score_tray(snapshot,action_payload),'attempt',submissions+1,'hintsBefore',hints,'feedbackBefore',submissions,'referencesBefore',refs,'submissions',submissions+1);
 elsif action_kind='hint' then
  if action_payload<>'{}'::jsonb or last_submission.id is null or last_submission.result->'score'->'findings'='[]'::jsonb then raise exception 'Hint requires an incorrect submission'; end if;
  result:=result||jsonb_build_object('hints',hints+1);
 elsif action_kind='finish' then
  if last_submission.id is null or action_payload<>last_submission.payload then raise exception 'Submit the current tray before finishing'; end if;
  select min((a.result->>'attempt')::integer) into first_correct from public.challenge_actions a where run_id=c.id and kind='submit' and a.result->'score'->'findings'='[]'::jsonb;
  correct:=last_submission.result->'score'->'findings'='[]'::jsonb;
  result:=result||jsonb_build_object('score',last_submission.result->'score','firstAttemptCorrect',coalesce(first_correct=1,false),'firstCorrectAttempt',first_correct,'retries',greatest(0,submissions-1),'latestCorrect',correct,'completed',true);
  update public.challenge_runs set finished_at=clock_timestamp() where id=c.id;
  update public.clinical_assignments set status='completed' where id=c.id;
 elsif action_kind in ('start','reference') and action_payload<>'{}'::jsonb then raise exception 'Invalid action payload';
 elsif action_kind='reference' then result:=result||jsonb_build_object('references',refs+1);
 end if;
 insert into public.challenge_actions(id,run_id,sequence,actor_id,kind,payload,result) values(request_id,c.id,n,auth.uid(),action_kind,action_payload,result);
 return result;
end;
$$;

create function public.patient_challenge_history(wanted_assignment uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'recorded_at',a.recorded_at,'kind',a.kind,'payload',a.payload,'result',a.result) order by a.sequence),'[]'::jsonb)
 from public.challenge_actions a join public.challenge_runs r on r.id=a.run_id
 where r.id=wanted_assignment and r.patient_user_id=auth.uid() and samification_private.has_patient_session(r.admission_id);
$$;
create function public.review_challenge(wanted_run uuid,request_id uuid,review_decision text,review_note text) returns uuid
language plpgsql security definer set search_path='' as $$
declare r public.challenge_runs; old public.challenge_reviews;
begin
 if request_id is null or review_decision is null or review_decision not in ('education_required','supervised_assessment','reviewed') or review_note is null or length(trim(review_note)) not between 1 and 4000 then raise exception 'Invalid clinical review'; end if;
 select * into r from public.challenge_runs where id=wanted_run;
 if not found or not samification_private.can_manage_admission(r.admission_id) then raise exception 'Scoped clinician required' using errcode='42501'; end if;
 perform 1 from public.patient_admissions where id=r.admission_id for update;
 if not samification_private.can_manage_admission(r.admission_id) then raise exception 'Scoped clinician required' using errcode='42501'; end if;
 if r.finished_at is null then raise exception 'Finish the challenge before review'; end if;
 select * into old from public.challenge_reviews where id=request_id;
 if found then
  if old.run_id<>wanted_run or old.clinician_id<>auth.uid() or old.decision<>review_decision or old.note<>review_note then raise exception 'Request identifier already used'; end if;
  return old.id;
 end if;
 insert into public.challenge_reviews(id,run_id,clinician_id,decision,note) values(request_id,wanted_run,auth.uid(),review_decision,review_note);
 return request_id;
end;
$$;
revoke all on function samification_private.score_tray(jsonb,jsonb) from public,anon,authenticated;
revoke all on function public.patient_challenge_action(uuid,uuid,text,jsonb,integer),public.patient_challenge_history(uuid),public.review_challenge(uuid,uuid,text,text) from public,anon;
grant execute on function public.patient_challenge_action(uuid,uuid,text,jsonb,integer),public.patient_challenge_history(uuid),public.review_challenge(uuid,uuid,text,text) to authenticated;
commit;
