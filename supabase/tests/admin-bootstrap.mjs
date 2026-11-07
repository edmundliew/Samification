// Disposable owner-bootstrap guard checks. Never connects to Supabase.
import {readFile} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import assert from 'node:assert/strict';
const {PGlite}=await import(pathToFileURL(process.argv[2]).href);
const db=new PGlite();
await db.exec(`create role anon; create role authenticated; create schema auth;
create table auth.users(id uuid primary key,email text,is_anonymous boolean,email_confirmed_at timestamptz,last_sign_in_at timestamptz);
create function auth.uid() returns uuid language sql stable as $$ select null::uuid $$;
create function auth.jwt() returns jsonb language sql stable as $$ select '{}'::jsonb $$;`);
await db.exec(await readFile(new URL('../migrations/202611010001_staff_access.sql',import.meta.url),'utf8'));
const source=await readFile(new URL('../admin/bootstrap-first-administrator.sql',import.meta.url),'utf8');
const id='00000000-0000-4000-8000-000000000001';let checks=0;
async function reject() {await assert.rejects(db.exec(source));await db.exec('rollback');checks++;}
await reject();
await db.query("select set_config('samification.bootstrap_user_id',$1,false)",[id]);await reject();
await db.query('insert into auth.users(id,email,is_anonymous) values($1,$2,true)',[id,'fictional@example.invalid']);await reject();
await db.query('update auth.users set is_anonymous=false where id=$1',[id]);await reject();
await db.query('update auth.users set email_confirmed_at=now() where id=$1',[id]);await reject();
await db.query('update auth.users set last_sign_in_at=now() where id=$1',[id]);
await db.exec('set role authenticated');await reject();await db.exec('reset role');
await db.exec(source);
assert.equal((await db.query("select count(*)::int n from public.staff_memberships where role='administrator' and scope_id is null and active")).rows[0].n,1);checks++;
assert.equal((await db.query("select count(*)::int n from public.staff_memberships where role='clinician'")).rows[0].n,0);checks++;
assert.equal((await db.query("select count(*)::int n from public.access_audit_events where action='initial_administrator_bootstrapped'")).rows[0].n,1);checks++;
await reject();
await db.close();console.log(`${checks} isolated administrator bootstrap checks passed. No live roles granted.`);
