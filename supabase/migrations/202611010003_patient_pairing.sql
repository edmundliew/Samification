-- Patient admission pairing. Requires clinical workflow migration 002.
-- Auth anonymous sign-ins must be configured separately before live use.
begin;
create table samification_private.patient_pairing_tokens (
    id uuid primary key default gen_random_uuid(),
    admission_id uuid not null references public.patient_admissions(id),
    token_hash text not null unique,
    issued_by uuid not null references auth.users(id),
    expires_at timestamptz not null,
    claimed_by uuid references auth.users(id),
    revoked_at timestamptz
);
create table public.patient_sessions (
    id uuid primary key default gen_random_uuid(),
    admission_id uuid not null references public.patient_admissions(id),
    user_id uuid not null unique references auth.users(id),
    paired_at timestamptz not null default now(),
    expires_at timestamptz not null default (now()+interval '24 hours'),
    revoked_at timestamptz
);
create index pairing_admission_idx on samification_private.patient_pairing_tokens(admission_id);
create index patient_sessions_admission_idx on public.patient_sessions(admission_id);
alter table samification_private.patient_pairing_tokens enable row level security;
alter table public.patient_sessions enable row level security;
revoke all on samification_private.patient_pairing_tokens from public,anon,authenticated;
revoke all on public.patient_sessions from public,anon,authenticated;
grant select on public.patient_sessions to authenticated;

create function samification_private.has_patient_session(wanted_admission uuid) returns boolean
language sql stable security definer set search_path='' as $$
    select auth.uid() is not null and coalesce(auth.jwt()->>'is_anonymous','false')='true' and exists (
        select 1 from public.patient_sessions s join public.patient_admissions a on a.id=s.admission_id
        join public.care_scopes c on c.id=a.scope_id
        where s.user_id=auth.uid() and s.admission_id=wanted_admission and s.revoked_at is null and s.expires_at>now()
        and a.status='active' and c.active
    );
$$;
create policy patient_sessions_read on public.patient_sessions for select to authenticated using (
    samification_private.can_manage_admission(admission_id)
    or (user_id=auth.uid() and samification_private.has_patient_session(admission_id))
);

create function public.issue_patient_pairing(wanted_admission uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a public.patient_admissions; pairing_token text; expiration timestamptz;
begin
    if not samification_private.can_manage_admission(wanted_admission) then raise exception 'Scoped clinician required' using errcode='42501'; end if;
    select * into a from public.patient_admissions where id=wanted_admission for update;
    if a.status <> 'active' then raise exception 'Admission is closed'; end if;
    update samification_private.patient_pairing_tokens set revoked_at=now() where admission_id=wanted_admission and claimed_by is null and revoked_at is null;
    pairing_token := gen_random_uuid()::text;
    expiration := now()+interval '15 minutes';
    insert into samification_private.patient_pairing_tokens(admission_id,token_hash,issued_by,expires_at)
    values (wanted_admission,encode(sha256(convert_to(pairing_token,'UTF8')),'hex'),auth.uid(),expiration);
    insert into public.clinical_audit_events(admission_id,actor_id,action) values (wanted_admission,auth.uid(),'pairing_issued');
    return jsonb_build_object('token',pairing_token,'expires_at',expiration);
end;
$$;
create function public.claim_patient_pairing(pairing_token text) returns uuid
language plpgsql security definer set search_path='' as $$
declare t samification_private.patient_pairing_tokens; a public.patient_admissions; session_id uuid;
begin
    if auth.uid() is null or coalesce(auth.jwt()->>'is_anonymous','false') <> 'true' then raise exception 'Temporary patient sign-in required' using errcode='42501'; end if;
    if pairing_token is null or length(trim(pairing_token))<>36 then raise exception 'Pairing code unavailable'; end if;
    -- Lock the admission before the token to use the same lock order as issue/revoke/discharge.
    select admission_id into session_id from samification_private.patient_pairing_tokens
    where token_hash=encode(sha256(convert_to(trim(pairing_token),'UTF8')),'hex');
    if not found then raise exception 'Pairing code unavailable'; end if;
    select * into a from public.patient_admissions where id=session_id for update;
    select * into t from samification_private.patient_pairing_tokens where token_hash=encode(sha256(convert_to(trim(pairing_token),'UTF8')),'hex') for update;
    if a.status<>'active' or not exists (select 1 from public.care_scopes where id=a.scope_id and active)
       or t.revoked_at is not null then raise exception 'Pairing code unavailable'; end if;
    if t.claimed_by=auth.uid() then
        select id into session_id from public.patient_sessions where user_id=auth.uid() and admission_id=a.id and revoked_at is null and expires_at>now();
        if found then return session_id; end if;
    end if;
    if t.claimed_by is not null or t.expires_at<=now() then raise exception 'Pairing code unavailable'; end if;
    if not exists (select 1 from public.staff_memberships where user_id=t.issued_by and role='clinician' and scope_id=a.scope_id and active) then raise exception 'Pairing code unavailable'; end if;
    if exists (select 1 from public.patient_sessions where user_id=auth.uid()) then raise exception 'This temporary identity has already been paired'; end if;
    insert into public.patient_sessions(admission_id,user_id) values (a.id,auth.uid()) returning id into session_id;
    update samification_private.patient_pairing_tokens set claimed_by=auth.uid() where id=t.id;
    insert into public.clinical_audit_events(admission_id,actor_id,action,detail) values (a.id,auth.uid(),'patient_paired',jsonb_build_object('session_id',session_id));
    return session_id;
end;
$$;
create function public.revoke_patient_session(wanted_session uuid) returns void
language plpgsql security definer set search_path='' as $$
declare s public.patient_sessions;
begin
    select * into s from public.patient_sessions where id=wanted_session;
    if not found or not samification_private.can_manage_admission(s.admission_id) then raise exception 'Scoped clinician required' using errcode='42501'; end if;
    perform 1 from public.patient_admissions where id=s.admission_id for update;
    update public.patient_sessions set revoked_at=now() where id=wanted_session and revoked_at is null;
    if found then insert into public.clinical_audit_events(admission_id,actor_id,action,detail) values (s.admission_id,auth.uid(),'patient_session_revoked',jsonb_build_object('session_id',s.id)); end if;
end;
$$;
create function public.end_patient_session() returns void
language plpgsql security definer set search_path='' as $$
declare s public.patient_sessions;
begin
    if auth.uid() is null or coalesce(auth.jwt()->>'is_anonymous','false') <> 'true' then raise exception 'Temporary patient sign-in required' using errcode='42501'; end if;
    select * into s from public.patient_sessions where user_id=auth.uid();
    if not found then return; end if;
    perform 1 from public.patient_admissions where id=s.admission_id for update;
    update public.patient_sessions set revoked_at=now() where id=s.id and revoked_at is null;
    if found then insert into public.clinical_audit_events(admission_id,actor_id,action,detail) values (s.admission_id,auth.uid(),'patient_session_ended',jsonb_build_object('session_id',s.id)); end if;
end;
$$;
-- Patients never SELECT raw regimen/import tables. This RPC returns only their assigned reference data.
create function public.patient_challenge_inbox() returns jsonb
language sql stable security definer set search_path='' as $$
    select coalesce(jsonb_agg(jsonb_build_object(
        'id',c.id,'admission_id',a.id,'patient_alias',a.patient_alias,'regimen_version',r.version,
        'practice',c.practice,'status',c.status,
        'medications',(select jsonb_agg(jsonb_build_object('id',m->'id','code',m->'code','name',m->'name',
            'doseMG',m->'doseMG','strengthMG',m->'strengthMG','periods',m->'periods','directions',coalesce(m->'directions','""'::jsonb)))
            from jsonb_array_elements(r.medications) m)
    ) order by c.assigned_at desc),'[]'::jsonb)
    from public.clinical_assignments c join public.patient_admissions a on a.id=c.admission_id
    join public.regimen_versions r on r.id=c.regimen_id
    where samification_private.has_patient_session(a.id) and c.status in ('assigned','in_progress','completed');
$$;
revoke all on function samification_private.has_patient_session(uuid) from public,anon;
grant execute on function samification_private.has_patient_session(uuid) to authenticated;
revoke all on function public.issue_patient_pairing(uuid),public.claim_patient_pairing(text),public.revoke_patient_session(uuid),public.patient_challenge_inbox(),public.end_patient_session() from public,anon;
grant execute on function public.issue_patient_pairing(uuid),public.claim_patient_pairing(text),public.revoke_patient_session(uuid),public.patient_challenge_inbox(),public.end_patient_session() to authenticated;
commit;
