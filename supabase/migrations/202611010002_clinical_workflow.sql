-- Prepared for the connected workflow. Apply after 202611010001_staff_access.sql.
-- No patient identities, medication orders or administrator grants are seeded.
begin;
create table public.patient_admissions (
    id uuid primary key default gen_random_uuid(),
    scope_id uuid not null references public.care_scopes(id),
    patient_alias text not null check (length(trim(patient_alias)) between 1 and 100),
    status text not null default 'active' check (status in ('active','discharged')),
    created_by uuid not null references auth.users(id),
    created_at timestamptz not null default now(),
    discharged_at timestamptz
);
create table public.regimen_versions (
    id uuid primary key default gen_random_uuid(),
    admission_id uuid not null references public.patient_admissions(id),
    version integer not null check (version > 0),
    medications jsonb not null check (jsonb_typeof(medications) = 'array'),
    original_csv text check (octet_length(original_csv) <= 200000),
    confirmed_by uuid not null references auth.users(id),
    confirmed_at timestamptz not null default now(),
    unique(admission_id, version)
);
create table public.clinical_assignments (
    id uuid primary key,
    admission_id uuid not null references public.patient_admissions(id),
    regimen_id uuid not null references public.regimen_versions(id),
    practice boolean not null,
    status text not null default 'assigned' check (status in ('assigned','in_progress','completed','superseded')),
    assigned_by uuid not null references auth.users(id),
    assigned_at timestamptz not null default now()
);
create table public.clinical_audit_events (
    id bigint generated always as identity primary key,
    admission_id uuid not null references public.patient_admissions(id),
    actor_id uuid not null references auth.users(id),
    action text not null,
    detail jsonb not null default '{}',
    at timestamptz not null default now()
);
create index admissions_scope_idx on public.patient_admissions(scope_id);
create index regimens_admission_idx on public.regimen_versions(admission_id);
create index assignments_admission_idx on public.clinical_assignments(admission_id);
create index clinical_audit_admission_idx on public.clinical_audit_events(admission_id);

create function samification_private.can_manage_admission(wanted_admission uuid) returns boolean
language sql stable security definer set search_path = '' as $$
    select exists (select 1 from public.patient_admissions a where a.id = wanted_admission
        and samification_private.is_clinician(a.scope_id));
$$;
create function samification_private.valid_medication_snapshot(medications jsonb) returns boolean
language plpgsql immutable set search_path = '' as $$
declare m jsonb; p jsonb; dose numeric; strength numeric; ratio numeric; ids uuid[] := '{}'; codes text[] := '{}'; names text[] := '{}'; med_id uuid; med_code text; med_name text;
begin
    if jsonb_typeof(medications) is distinct from 'array' then return false; end if;
    if jsonb_array_length(medications) not between 1 and 20 then return false; end if;
    for m in select * from jsonb_array_elements(medications) loop
        if jsonb_typeof(m) is distinct from 'object' or jsonb_typeof(m->'doseMG') is distinct from 'number' or jsonb_typeof(m->'strengthMG') is distinct from 'number'
            or m->'included' is distinct from 'true'::jsonb or m->'confirmed' is distinct from 'true'::jsonb
            or coalesce(m->'exclusionReason', 'null'::jsonb) <> 'null'::jsonb then return false; end if;
        if jsonb_typeof(m->'id') is distinct from 'string' or jsonb_typeof(m->'code') is distinct from 'string'
            or jsonb_typeof(m->'name') is distinct from 'string' or jsonb_typeof(m->'originalName') is distinct from 'string' then return false; end if;
        med_id := (m->>'id')::uuid; med_code := trim(m->>'code'); med_name := lower(trim(m->>'name'));
        if length(med_code) not between 1 and 8 or length(med_name) not between 1 and 200
            or length(trim(m->>'originalName')) not between 1 and 200 then return false; end if;
        if med_id = any(ids) or med_code = any(codes) or med_name = any(names) then return false; end if;
        ids := array_append(ids, med_id); codes := array_append(codes,med_code); names := array_append(names,med_name);
        dose := (m->>'doseMG')::numeric; strength := (m->>'strengthMG')::numeric;
        if dose <= 0 or strength <= 0 then return false; end if;
        ratio := dose / strength;
        if ratio < 1 or ratio > 12 or abs(ratio-round(ratio)) >= 0.00000001 then return false; end if;
        if jsonb_typeof(m->'periods') is distinct from 'array' then return false; end if;
        if jsonb_array_length(m->'periods') not between 1 and 4 then return false; end if;
        for p in select * from jsonb_array_elements(m->'periods') loop
            if p not in ('"morning"'::jsonb,'"afternoon"'::jsonb,'"evening"'::jsonb,'"bedtime"'::jsonb) then return false; end if;
        end loop;
        if (select count(distinct value) from jsonb_array_elements(m->'periods')) <> jsonb_array_length(m->'periods') then return false; end if;
    end loop;
    return true;
exception when invalid_text_representation or numeric_value_out_of_range then return false;
end;
$$;

alter table public.patient_admissions enable row level security;
alter table public.regimen_versions enable row level security;
alter table public.clinical_assignments enable row level security;
alter table public.clinical_audit_events enable row level security;
revoke all on public.patient_admissions, public.regimen_versions, public.clinical_assignments, public.clinical_audit_events from public, anon, authenticated;
grant select on public.patient_admissions, public.regimen_versions, public.clinical_assignments, public.clinical_audit_events to authenticated;
create policy admissions_clinician_read on public.patient_admissions for select to authenticated using (samification_private.is_clinician(scope_id));
create policy regimens_clinician_read on public.regimen_versions for select to authenticated using (samification_private.can_manage_admission(admission_id));
create policy assignments_clinician_read on public.clinical_assignments for select to authenticated using (samification_private.can_manage_admission(admission_id));
create policy clinical_audit_clinician_read on public.clinical_audit_events for select to authenticated using (samification_private.can_manage_admission(admission_id));

create function public.create_patient_admission(wanted_scope uuid, patient_alias text, request_id uuid default gen_random_uuid()) returns uuid
language plpgsql security definer set search_path = '' as $$
declare new_id uuid; existing public.patient_admissions;
begin
    if not samification_private.is_clinician(wanted_scope) then raise exception 'Scoped clinician required' using errcode='42501'; end if;
    if patient_alias is null or length(trim(patient_alias)) not between 1 and 100 then raise exception 'Patient alias required'; end if;
    if request_id is null then raise exception 'Request ID required'; end if;
    insert into public.patient_admissions(id, scope_id, patient_alias, created_by) values (request_id, wanted_scope, trim(patient_alias), auth.uid())
    on conflict (id) do nothing returning id into new_id;
    if new_id is null then
        select * into existing from public.patient_admissions where id=request_id;
        if existing.scope_id=wanted_scope and existing.patient_alias=trim(patient_alias) and existing.created_by=auth.uid() then return existing.id; end if;
        raise exception 'Request ID already used with different admission details';
    end if;
    insert into public.clinical_audit_events(admission_id, actor_id, action) values (new_id, auth.uid(), 'admission_created');
    return new_id;
end;
$$;
create function public.confirm_patient_regimen(wanted_admission uuid, medication_snapshot jsonb, source_csv text, request_id uuid default gen_random_uuid()) returns uuid
language plpgsql security definer set search_path = '' as $$
declare a public.patient_admissions; next_version integer; new_id uuid; existing public.regimen_versions;
begin
    if not samification_private.can_manage_admission(wanted_admission) then raise exception 'Scoped clinician required' using errcode='42501'; end if;
    select * into a from public.patient_admissions where id=wanted_admission for update;
    if a.status <> 'active' then raise exception 'Admission is closed'; end if;
    if not samification_private.valid_medication_snapshot(medication_snapshot) then raise exception 'Invalid confirmed medication snapshot'; end if;
    if source_csv is not null and octet_length(source_csv)>200000 then raise exception 'CSV exceeds 200 KB'; end if;
    if request_id is null then raise exception 'Request ID required'; end if;
    select * into existing from public.regimen_versions where id=request_id;
    if found then
        if existing.admission_id=wanted_admission and existing.medications=medication_snapshot and existing.original_csv is not distinct from source_csv and existing.confirmed_by=auth.uid() then return existing.id; end if;
        raise exception 'Request ID already used with different regimen details';
    end if;
    select coalesce(max(version),0)+1 into next_version from public.regimen_versions where admission_id=wanted_admission;
    insert into public.regimen_versions(id,admission_id,version,medications,original_csv,confirmed_by)
    values (request_id,wanted_admission,next_version,medication_snapshot,source_csv,auth.uid()) returning id into new_id;
    update public.clinical_assignments set status='superseded' where admission_id=wanted_admission and status in ('assigned','in_progress');
    insert into public.clinical_audit_events(admission_id,actor_id,action,detail)
    values (wanted_admission,auth.uid(),'regimen_confirmed',jsonb_build_object('regimen_id',new_id,'version',next_version));
    return new_id;
end;
$$;
create function public.assign_patient_challenge(wanted_admission uuid, wanted_regimen uuid, practice_mode boolean, assignment_id uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare a public.patient_admissions; r public.regimen_versions; existing public.clinical_assignments;
begin
    if not samification_private.can_manage_admission(wanted_admission) then raise exception 'Scoped clinician required' using errcode='42501'; end if;
    if assignment_id is null or practice_mode is null then raise exception 'Assignment ID and mode required'; end if;
    select * into a from public.patient_admissions where id=wanted_admission for update;
    if a.status <> 'active' then raise exception 'Admission is closed'; end if;
    select * into existing from public.clinical_assignments where id=assignment_id;
    if found then
        if existing.admission_id=wanted_admission and existing.regimen_id=wanted_regimen and existing.practice=practice_mode and existing.assigned_by=auth.uid() then return existing.id; end if;
        raise exception 'Assignment ID already used';
    end if;
    select * into r from public.regimen_versions where admission_id=wanted_admission order by version desc limit 1;
    if not found or r.id <> wanted_regimen then raise exception 'Only the current confirmed regimen can be assigned'; end if;
    insert into public.clinical_assignments(id,admission_id,regimen_id,practice,assigned_by) values (assignment_id,wanted_admission,wanted_regimen,practice_mode,auth.uid());
    insert into public.clinical_audit_events(admission_id,actor_id,action,detail) values (wanted_admission,auth.uid(),'challenge_assigned',jsonb_build_object('assignment_id',assignment_id,'regimen_id',wanted_regimen,'practice',practice_mode));
    return assignment_id;
end;
$$;
create function public.discharge_patient_admission(wanted_admission uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare a public.patient_admissions;
begin
    if not samification_private.can_manage_admission(wanted_admission) then raise exception 'Scoped clinician required' using errcode='42501'; end if;
    select * into a from public.patient_admissions where id=wanted_admission for update;
    if a.status='discharged' then return; end if;
    update public.patient_admissions set status='discharged', discharged_at=now() where id=wanted_admission;
    update public.clinical_assignments set status='superseded' where admission_id=wanted_admission and status in ('assigned','in_progress');
    insert into public.clinical_audit_events(admission_id,actor_id,action) values (wanted_admission,auth.uid(),'admission_discharged');
end;
$$;
revoke all on function samification_private.can_manage_admission(uuid), samification_private.valid_medication_snapshot(jsonb) from public, anon;
grant execute on function samification_private.can_manage_admission(uuid) to authenticated;
revoke all on function public.create_patient_admission(uuid,text,uuid), public.confirm_patient_regimen(uuid,jsonb,text,uuid), public.assign_patient_challenge(uuid,uuid,boolean,uuid), public.discharge_patient_admission(uuid) from public, anon;
grant execute on function public.create_patient_admission(uuid,text,uuid), public.confirm_patient_regimen(uuid,jsonb,text,uuid), public.assign_patient_challenge(uuid,uuid,boolean,uuid), public.discharge_patient_admission(uuid) to authenticated;
commit;
