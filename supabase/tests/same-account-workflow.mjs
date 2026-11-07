import {readFile} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import assert from 'node:assert/strict';
const {PGlite}=await import(pathToFileURL(process.argv[2]).href);const db=new PGlite();
const id='00000000-0000-4000-8000-000000000001';
await db.exec(`create role anon;create role authenticated;create schema auth;
create table auth.users(id uuid primary key,is_anonymous boolean default false,email_confirmed_at timestamptz,last_sign_in_at timestamptz);
create function auth.jwt() returns jsonb language sql stable as $$select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb$$;
create function auth.uid() returns uuid language sql stable as $$select (auth.jwt()->>'sub')::uuid$$;
grant usage on schema auth to authenticated,anon;`);
for(const file of ['202611010001_staff_access.sql','202611010002_clinical_workflow.sql','202611010003_patient_pairing.sql','202611070004_assessment_evidence.sql'])await db.exec(await readFile(new URL('../migrations/'+file,import.meta.url),'utf8'));
const provision=await readFile(new URL('../admin/provision-same-account-test-clinician.sql',import.meta.url),'utf8');
const walkthrough=await readFile(new URL('../admin/rollback-workflow-walkthrough.sql',import.meta.url),'utf8');
let checks=0;async function deny(){await assert.rejects(db.exec(provision));await db.exec('rollback');checks++;}
await deny();await db.query("select set_config('samification.test_staff_id',$1,false)",[id]);await deny();
await db.query('insert into auth.users(id,email_confirmed_at,last_sign_in_at) values($1,now(),now())',[id]);await deny();
await db.query("insert into public.staff_memberships(user_id,role) values($1,'administrator')",[id]);
await db.exec(provision);
assert.equal((await db.query("select count(*)::int n from public.staff_memberships where user_id=$1 and role='clinician' and active",[id])).rows[0].n,1);checks++;
assert.equal((await db.query("select count(*)::int n from public.access_audit_events where action='clinician_approved'")).rows[0].n,1);checks++;
await db.exec(provision);assert.equal((await db.query('select count(*)::int n from public.care_scopes')).rows[0].n,1);checks++;
const result=await db.exec(walkthrough);const report=result.find(x=>x.rows?.[0]?.step);
assert.equal(report.rows.length,9);for(const row of report.rows){assert.equal(row.passed,true,row.step);checks++;}
for(const table of ['patient_admissions','regimen_versions','clinical_assignments','challenge_runs','challenge_actions','challenge_reviews','patient_sessions']) {assert.equal((await db.query(`select count(*)::int n from public.${table}`)).rows[0].n,0);checks++;}
assert.equal((await db.query('select count(*)::int n from auth.users')).rows[0].n,1);checks++;
await db.exec("update public.staff_memberships set active=false where role='clinician'");await deny();
await db.close();console.log(`${checks} same-account workflow checks passed locally. No live roles or data changed.`);
