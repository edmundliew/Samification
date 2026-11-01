-- Staff access foundation. No clinical records or initial administrators are seeded.
begin;
create schema if not exists samification_private;
revoke all on schema samification_private from public, anon;
grant usage on schema samification_private to authenticated;

create table public.care_scopes (
    id uuid primary key default gen_random_uuid(),
    name text not null check (length(trim(name)) between 1 and 100),
    active boolean not null default true
);
create table public.staff_memberships (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id),
    role text not null check (role in ('administrator', 'clinician')),
    scope_id uuid references public.care_scopes(id),
    active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint membership_scope check ((role = 'administrator' and scope_id is null) or (role = 'clinician' and scope_id is not null)),
    unique nulls not distinct (user_id, role, scope_id)
);
create table public.staff_access_requests (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id),
    scope_id uuid not null references public.care_scopes(id),
    display_name text not null check (length(trim(display_name)) between 1 and 100),
    status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
    requested_at timestamptz not null default now(),
    decided_at timestamptz,
    decided_by uuid references auth.users(id),
    reason text check (length(reason) <= 500),
    unique (user_id, scope_id)
);
create table public.access_audit_events (
    id bigint generated always as identity primary key,
    actor_id uuid not null references auth.users(id),
    subject_id uuid not null references auth.users(id),
    action text not null,
    scope_id uuid references public.care_scopes(id),
    reason text,
    at timestamptz not null default now()
);
create index memberships_user_idx on public.staff_memberships(user_id);
create index requests_user_idx on public.staff_access_requests(user_id);
create index access_audit_subject_idx on public.access_audit_events(subject_id);

create function samification_private.permanent_user() returns boolean
language sql stable set search_path = '' as $$
    select auth.uid() is not null and coalesce(auth.jwt()->>'is_anonymous', 'false') = 'false';
$$;
create function samification_private.is_administrator() returns boolean
language sql stable security definer set search_path = '' as $$
    select samification_private.permanent_user() and exists (
        select 1 from public.staff_memberships where user_id = auth.uid() and role = 'administrator' and active
    );
$$;
create function samification_private.is_clinician(wanted_scope uuid) returns boolean
language sql stable security definer set search_path = '' as $$
    select samification_private.permanent_user() and exists (
        select 1 from public.staff_memberships m join public.care_scopes s on s.id = m.scope_id
        where m.user_id = auth.uid() and m.role = 'clinician' and m.active and s.active and m.scope_id = wanted_scope
    );
$$;

alter table public.care_scopes enable row level security;
alter table public.staff_memberships enable row level security;
alter table public.staff_access_requests enable row level security;
alter table public.access_audit_events enable row level security;
revoke all on public.care_scopes, public.staff_memberships, public.staff_access_requests, public.access_audit_events from public, anon, authenticated;
grant select on public.care_scopes, public.staff_memberships, public.staff_access_requests, public.access_audit_events to authenticated;
create policy scopes_read on public.care_scopes for select to authenticated
using (samification_private.permanent_user() and (active or samification_private.is_administrator()));
create policy memberships_read on public.staff_memberships for select to authenticated
using (samification_private.permanent_user() and (user_id = auth.uid() or samification_private.is_administrator()));
create policy requests_read on public.staff_access_requests for select to authenticated
using (samification_private.permanent_user() and (user_id = auth.uid() or samification_private.is_administrator()));
create policy access_audit_read on public.access_audit_events for select to authenticated
using (samification_private.permanent_user() and (subject_id = auth.uid() or samification_private.is_administrator()));

-- Clients cannot directly mutate memberships, request status or audit rows.
create function public.request_clinician_access(wanted_scope uuid, requested_name text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare request_id uuid;
begin
    if not samification_private.permanent_user() then raise exception 'Permanent staff sign-in required' using errcode = '42501'; end if;
    if requested_name is null or length(trim(requested_name)) not between 1 and 100 then raise exception 'Name must be 1–100 characters'; end if;
    if not exists (select 1 from public.care_scopes where id = wanted_scope and active) then raise exception 'Scope unavailable'; end if;
    if exists (select 1 from public.staff_memberships where user_id = auth.uid() and role = 'clinician' and scope_id = wanted_scope) then
        raise exception 'An existing membership must be managed by an administrator';
    end if;
    insert into public.staff_access_requests(user_id, scope_id, display_name)
    values (auth.uid(), wanted_scope, trim(requested_name))
    on conflict (user_id, scope_id) do update set status = 'pending', display_name = excluded.display_name,
        requested_at = now(), decided_at = null, decided_by = null, reason = null
    where staff_access_requests.status = 'rejected'
    returning id into request_id;
    if request_id is null then raise exception 'A request is already pending or approved'; end if;
    insert into public.access_audit_events(actor_id, subject_id, action, scope_id) values (auth.uid(), auth.uid(), 'access_requested', wanted_scope);
    return request_id;
end;
$$;
create function public.decide_clinician_access(request_id uuid, approve boolean, decision_reason text) returns void
language plpgsql security definer set search_path = '' as $$
declare r public.staff_access_requests;
begin
    if not samification_private.is_administrator() then raise exception 'Administrator required' using errcode = '42501'; end if;
    if approve is null or decision_reason is null or length(trim(decision_reason)) not between 1 and 500 then raise exception 'Decision and reason required'; end if;
    select * into r from public.staff_access_requests where id = request_id for update;
    if not found or r.status <> 'pending' then raise exception 'Pending request unavailable'; end if;
    if not exists (select 1 from public.care_scopes where id = r.scope_id and active) then raise exception 'Scope unavailable'; end if;
    if approve then
        insert into public.staff_memberships(user_id, role, scope_id) values (r.user_id, 'clinician', r.scope_id);
    end if;
    update public.staff_access_requests set status = case when approve then 'approved' else 'rejected' end,
        decided_at = now(), decided_by = auth.uid(), reason = trim(decision_reason) where id = request_id;
    insert into public.access_audit_events(actor_id, subject_id, action, scope_id, reason)
    values (auth.uid(), r.user_id, case when approve then 'clinician_approved' else 'request_rejected' end, r.scope_id, trim(decision_reason));
end;
$$;
create function public.set_clinician_access(membership_id uuid, enabled boolean, change_reason text) returns void
language plpgsql security definer set search_path = '' as $$
declare m public.staff_memberships;
begin
    if not samification_private.is_administrator() then raise exception 'Administrator required' using errcode = '42501'; end if;
    if enabled is null or change_reason is null or length(trim(change_reason)) not between 1 and 500 then raise exception 'Status and reason required'; end if;
    select * into m from public.staff_memberships where id = membership_id and role = 'clinician' for update;
    if not found then raise exception 'Clinician membership unavailable'; end if;
    if enabled and not exists (select 1 from public.care_scopes where id = m.scope_id and active) then raise exception 'Scope unavailable'; end if;
    update public.staff_memberships set active = enabled, updated_at = now() where id = membership_id;
    insert into public.access_audit_events(actor_id, subject_id, action, scope_id, reason)
    values (auth.uid(), m.user_id, case when enabled then 'clinician_resumed' else 'clinician_suspended' end, m.scope_id, trim(change_reason));
end;
$$;
revoke all on function samification_private.permanent_user(), samification_private.is_administrator(), samification_private.is_clinician(uuid) from public, anon;
grant execute on function samification_private.permanent_user(), samification_private.is_administrator(), samification_private.is_clinician(uuid) to authenticated;
revoke all on function public.request_clinician_access(uuid,text), public.decide_clinician_access(uuid,boolean,text), public.set_clinician_access(uuid,boolean,text) from public, anon;
grant execute on function public.request_clinician_access(uuid,text), public.decide_clinician_access(uuid,boolean,text), public.set_clinician_access(uuid,boolean,text) to authenticated;
commit;
