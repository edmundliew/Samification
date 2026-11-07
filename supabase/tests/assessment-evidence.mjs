// Disposable PostgreSQL test; no connection to Supabase.
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import assert from 'node:assert/strict';
const { PGlite } = await import(pathToFileURL(process.argv[2]).href);
const db = new PGlite();
const admin='00000000-0000-4000-8000-000000000001', nurse='00000000-0000-4000-8000-000000000002', other='00000000-0000-4000-8000-000000000003';
const wardA='00000000-0000-4000-8000-000000000010', wardB='00000000-0000-4000-8000-000000000011';
await db.exec(`create role anon; create role authenticated; create schema auth; create table auth.users(id uuid primary key);
create function auth.jwt() returns jsonb language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb $$;
create function auth.uid() returns uuid language sql stable as $$ select (auth.jwt()->>'sub')::uuid $$;
grant usage on schema auth to authenticated,anon;
insert into auth.users values ('${admin}'),('${nurse}'),('${other}');`);
for (const name of ['202611010001_staff_access.sql','202611010002_clinical_workflow.sql','202611010003_patient_pairing.sql','202611070004_assessment_evidence.sql']) await db.exec(await readFile(new URL('../migrations/'+name,import.meta.url),'utf8'));
await db.query('insert into public.care_scopes(id,name) values ($1,$2),($3,$4)',[wardA,'Fictional A',wardB,'Fictional B']);
await db.query("insert into public.staff_memberships(user_id,role,scope_id) values ($1,'administrator',null),($2,'clinician',$4),($3,'clinician',$5)",[admin,nurse,other,wardA,wardB]);
async function as(user,anonymous=false) { await db.exec('reset role'); await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:user,is_anonymous:anonymous})]); await db.exec('set role authenticated'); }
async function value(sql,args=[]) { return (await db.query(sql,args)).rows[0]; }
let checks=0;
async function deny(sql,args=[]) { await assert.rejects(db.query(sql,args)); checks++; }
function equal(a,b) { assert.deepEqual(a,b); checks++; }
const patient='00000000-0000-4000-8000-000000000050', stranger='00000000-0000-4000-8000-000000000051';
await db.exec('reset role'); await db.query('insert into auth.users values ($1),($2)',[patient,stranger]);
const med={id:'00000000-0000-4000-8000-000000000020',code:'A',name:'Fictional Tablet',originalName:'Private original CSV name',doseMG:10,strengthMG:10,periods:['bedtime'],directions:'Fictional instruction',included:true,confirmed:true,sourceDetails:'Private source details'};
await as(nurse);
const admission=(await value('select public.create_patient_admission($1,$2) id',[wardA,'Fictional pair patient'])).id;
const second=(await value('select public.create_patient_admission($1,$2) id',[wardA,'Other fictional patient'])).id;
const regimen=(await value('select public.confirm_patient_regimen($1,$2::jsonb,$3) id',[admission,JSON.stringify([med]),'PRIVATE CSV MUST NOT REACH PATIENT'])).id;
const assignment='00000000-0000-4000-8000-000000000060';
await db.query('select public.assign_patient_challenge($1,$2,false,$3)',[admission,regimen,assignment]);

const code=(await value('select public.issue_patient_pairing($1) result',[admission])).result;
await as(patient,true); const session=(await value('select public.claim_patient_pairing($1) id',[code.token])).id;
let serial=100;
const next=()=>`00000000-0000-4000-8000-${String(serial++).padStart(12,'0')}`;
async function action(kind,payload={},id=next(),target=assignment) { const h=(await value('select public.patient_challenge_history($1) result',[target])).result; return (await value('select public.patient_challenge_action($1,$2,$3,$4::jsonb,$5) result',[target,id,kind,JSON.stringify(payload),h.length])).result; }
const tray={bedtime:{[med.id]:1}};
await deny('select public.patient_challenge_action($1,$2,$3,$4::jsonb,(select jsonb_array_length(public.patient_challenge_history($1))))',[assignment,next(),'submit',JSON.stringify(tray)]);
const startID=next(); const start=await action('start',{},startID); equal(start.priorExposure,false);
equal(await action('start',{},startID),start);
await deny('select public.patient_challenge_action($1,$2,$3,$4::jsonb,0)',[assignment,next(),'submit',JSON.stringify(tray)]);
await deny('select public.patient_challenge_action($1,$2,$3,$4::jsonb,(select jsonb_array_length(public.patient_challenge_history($1))))',[assignment,startID,'reference','{}']);
await deny('select public.patient_challenge_action($1,$2,$3,$4::jsonb,(select jsonb_array_length(public.patient_challenge_history($1))))',[assignment,next(),'hint','{}']);
await deny('select public.patient_challenge_action($1,$2,$3,$4::jsonb,(select jsonb_array_length(public.patient_challenge_history($1))))',[assignment,next(),'finish',JSON.stringify(tray)]);
for (const bad of [{night:{}},{morning:{[med.id]:13}},{morning:{[med.id]:-1}},{morning:{[med.id]:1.5}},{morning:{[next()]:1}},[],{morning:null},{morning:{[med.id]:'1'}}]) {
 await deny('select public.patient_challenge_action($1,$2,$3,$4::jsonb,(select jsonb_array_length(public.patient_challenge_history($1))))',[assignment,next(),'submit',JSON.stringify(bad)]);
}
const wrong=await action('submit',{});equal(wrong.attempt,1); equal(wrong.score.missingTablets,1);equal(wrong.score.omissions,1);equal(wrong.score.findings.length,1);
equal((await action('hint')).hints,1);equal((await action('reference')).references,1);
const extra=await action('submit',{bedtime:{[med.id]:1},morning:{[med.id]:1}});
equal(extra.score.exactQuantities,1);equal(extra.score.presentAdministrations,1);equal(extra.score.unexpectedPlacements,1);equal(extra.score.extraTablets,1);equal(extra.score.findings.length,1);
const submitID=next();const right=await action('submit',tray,submitID);equal(right.attempt,3);equal(right.score.findings,[]);equal(right.hintsBefore,1);equal(right.referencesBefore,1);equal(right.feedbackBefore,2);
equal(await action('submit',tray,submitID),right);
await deny('select public.patient_challenge_action($1,$2,$3,$4::jsonb,(select jsonb_array_length(public.patient_challenge_history($1))))',[assignment,next(),'hint','{}']);
await deny('select public.patient_challenge_action($1,$2,$3,$4::jsonb,(select jsonb_array_length(public.patient_challenge_history($1))))',[assignment,next(),'finish','{}']);
const finishedID=next();const finished=await action('finish',tray,finishedID);equal(finished.completed,true);equal(finished.retries,2);equal(finished.firstAttemptCorrect,false);equal(finished.firstCorrectAttempt,3);
equal(await action('finish',tray,finishedID),finished);
await deny('select public.patient_challenge_action($1,$2,$3,$4::jsonb,(select jsonb_array_length(public.patient_challenge_history($1))))',[assignment,next(),'submit',JSON.stringify(tray)]);
await deny('select public.patient_challenge_action($1,$2,$3,$4::jsonb,0)',[assignment,next(),'submit',JSON.stringify(tray)]);
const history=(await value('select public.patient_challenge_history($1) result',[assignment])).result;
equal(history.length,7);equal(history.map(x=>x.result.sequence),[1,2,3,4,5,6,7]);
equal((await value('select count(*)::int n from public.challenge_actions')).n,0);
await deny("update public.challenge_actions set payload='{}'");
await deny('insert into public.challenge_runs(id,admission_id,patient_user_id,prior_exposure) values ($1,$2,$3,false)',[next(),admission,patient]);
await deny('select public.review_challenge($1,$2,$3,$4)',[assignment,next(),'reviewed','Patient cannot review']);
await as(stranger,true);equal((await value('select public.patient_challenge_history($1) result',[assignment])).result,[]);
await deny('select public.patient_challenge_action($1,$2,$3,$4::jsonb,(select jsonb_array_length(public.patient_challenge_history($1))))',[assignment,next(),'start','{}']);
await as(admin);equal((await value('select count(*)::int n from public.challenge_runs')).n,0);
await deny('select public.review_challenge($1,$2,$3,$4)',[assignment,next(),'reviewed','Admin alone cannot review']);
await as(other);equal((await value('select count(*)::int n from public.challenge_actions')).n,0);
await deny('select public.review_challenge($1,$2,$3,$4)',[assignment,next(),'reviewed','Wrong ward']);
await as(nurse);equal((await value('select count(*)::int n from public.challenge_actions')).n,7);
const reviewID=next();await db.query('select public.review_challenge($1,$2,$3,$4)',[assignment,reviewID,'education_required','Fictional education plan']);
equal((await value('select public.review_challenge($1,$2,$3,$4) id',[assignment,reviewID,'education_required','Fictional education plan'])).id,reviewID);
await deny('select public.review_challenge($1,$2,$3,$4)',[assignment,reviewID,'reviewed','Changed payload']);
await deny('select public.review_challenge($1,$2,$3,$4)',[assignment,next(),'qualified','Unsupported automatic approval']);
await deny('delete from public.challenge_reviews');
const secondAssignment=next();await db.query('select public.assign_patient_challenge($1,$2,true,$3)',[admission,regimen,secondAssignment]);
await as(patient,true);equal((await action('start',{},next(),secondAssignment)).priorExposure,true);
await action('submit',{},next(),secondAssignment);
const incomplete=await action('finish',{},next(),secondAssignment);equal(incomplete.firstAttemptCorrect,false);equal(incomplete.firstCorrectAttempt,null);equal(incomplete.latestCorrect,false);
await as(nurse);const firstTry=next();await db.query('select public.assign_patient_challenge($1,$2,false,$3)',[admission,regimen,firstTry]);
await as(patient,true);await action('start',{},next(),firstTry);await action('submit',tray,next(),firstTry);
const firstFinish=await action('finish',tray,next(),firstTry);equal(firstFinish.firstAttemptCorrect,true);equal(firstFinish.firstCorrectAttempt,1);equal(firstFinish.retries,0);
await as(nurse);const superseded=next();await db.query('select public.assign_patient_challenge($1,$2,false,$3)',[admission,regimen,superseded]);
await as(patient,true);await action('start',{},next(),superseded);
await as(nurse);await db.query('select public.confirm_patient_regimen($1,$2::jsonb,$3)',[admission,JSON.stringify([med]),'New version']);
await as(patient,true);await deny('select public.patient_challenge_action($1,$2,$3,$4::jsonb,(select jsonb_array_length(public.patient_challenge_history($1))))',[superseded,next(),'submit',JSON.stringify(tray)]);
await db.exec('reset role');await db.query("update public.patient_sessions set expires_at=now()-interval '1 minute' where id=$1",[session]);
await as(patient,true);equal((await value('select public.patient_challenge_history($1) result',[assignment])).result,[]);
await deny('select public.patient_challenge_action($1,$2,$3,$4::jsonb,0)',[superseded,next(),'reference','{}']);
await db.exec('reset role');await db.query("update public.patient_sessions set expires_at=now()+interval '1 hour' where id=$1",[session]);
await as(nurse);await db.query('select public.revoke_patient_session($1)',[session]);
await as(patient,true);equal((await value('select public.patient_challenge_history($1) result',[assignment])).result,[]);
await deny('select public.patient_challenge_action($1,$2,$3,$4::jsonb,(select jsonb_array_length(public.patient_challenge_history($1))))',[assignment,finishedID,'finish',JSON.stringify(tray)]);
await db.exec('reset role; set role anon');await deny('select public.patient_challenge_history($1)',[assignment]);

await db.exec('reset role');
const fixtures=JSON.parse(await readFile(new URL('../../Tests/Fixtures/scoring-parity.json',import.meta.url),'utf8'));
for(const fixture of fixtures) {
 const score=(await value('select samification_private.score_tray($1::jsonb,$2::jsonb) result',[JSON.stringify(fixture.medications),JSON.stringify(fixture.tray)])).result;
 for(const [key,expected] of Object.entries(fixture.expected)) equal(score[key],expected);
}
await db.close();console.log(`${checks} PostgreSQL assessment evidence checks passed. Remote project unchanged.`);
