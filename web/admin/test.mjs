import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import test from 'node:test';
const source=readFileSync(new URL('./app.js',import.meta.url),'utf8');
class Element {
  constructor(tag='div'){this.tagName=tag;this.children=[];this.listeners={};this.value='';this.hidden=false;this.textContent='';this.disabled=false;this.open=false;}
  addEventListener(name,fn){this.listeners[name]=fn;}
  append(...items){this.children.push(...items);}
  replaceChildren(){this.children=[];this.textContent='';}
  showModal(){this.open=true;} close(){this.open=false;} focus(){}
}
function harness({admin=true,invalid=false}={}){
  const elements=new Map(), calls=[];
  const get=id=>{if(!elements.has(id))elements.set(id,new Element());return elements.get(id);};
  get('workspace').hidden=true;get('email').value='fictional@example.invalid';get('password').value='fictional-test-password';
  const memberships=admin?[{id:'admin',user_id:'user',role:'administrator',active:true}]:[];
  memberships.push({id:'membership',user_id:'subject',role:'clinician',scope_id:'ward',active:true});
  let pending=true;
  const fetch=async(url,options)=>{
    const path=url.replace('https://vqexfcvzoryocjnzjozv.supabase.co','');calls.push({path,...options,body:options.body?JSON.parse(options.body):null});
    let status=200,result=null;
    if(path.startsWith('/auth/v1/token')) {if(invalid)status=400;else result={access_token:'fictional-access',refresh_token:'fictional-refresh',expires_at:Date.now()/1000+3600,user:{id:'user',email:'fictional@example.invalid'}};}
    else if(path.startsWith('/rest/v1/staff_memberships'))result=memberships;
    else if(path.startsWith('/rest/v1/staff_access_requests'))result=[{id:'request',user_id:'subject',scope_id:'ward',display_name:'<img src=x onerror=alert(1)>',status:pending?'pending':'approved'}];
    else if(path.startsWith('/rest/v1/care_scopes'))result=[{id:'ward',name:'Fictional ward',active:true}];
    else if(path.startsWith('/rest/v1/access_audit_events'))result=[];
    else if(path==='/rest/v1/rpc/decide_clinician_access')pending=false;
    return {ok:status===200,status,text:async()=>result===null?'':JSON.stringify(result)};
  };
  vm.runInNewContext(source,{document:{getElementById:get,createElement:tag=>new Element(tag),querySelectorAll:()=>[...elements.values()].filter(e=>e.tagName==='button'),addEventListener(){}},fetch,AbortSignal,Date,Error,JSON});
  const settle=async()=>{for(let i=0;i<15;i++)await new Promise(setImmediate);};
  const submit=async id=>{get(id).listeners.submit({preventDefault(){}});await settle();};
  return {get,calls,settle,submit};
}
test('invalid password stays at sign-in and clears entered password',async()=>{const h=harness({invalid:true});await h.submit('sign-in');assert.equal(h.get('workspace').hidden,true);assert.equal(h.get('password').value,'');assert.match(h.get('status').textContent,/Sign-in failed/);assert.equal(h.calls.length,1);});
test('ordinary clinician cannot load admin requests or audit and session is signed out',async()=>{const h=harness({admin:false});await h.submit('sign-in');assert.equal(h.get('workspace').hidden,true);assert.equal(h.calls.some(c=>c.path.includes('access_audit_events')),false);assert.equal(h.calls.some(c=>c.path==='/auth/v1/logout?scope=local'),true);});
test('admin load is read-only and untrusted names render as text',async()=>{const h=harness();await h.submit('sign-in');assert.equal(h.get('workspace').hidden,false);assert.equal(h.calls.some(c=>c.path.includes('/rpc/')),false);assert.equal(h.get('requests').children[0].children[0].textContent,'<img src=x onerror=alert(1)>');assert.equal(h.calls.find(c=>c.path.includes('access_audit_events')).method,'GET');});
test('decision requires reason and uses scoped audited RPC parameters',async()=>{const h=harness();await h.submit('sign-in');h.get('requests').children[0].children[3].children[0].listeners.click();assert.equal(h.get('decision').open,true);await h.submit('decision-form');assert.equal(h.calls.some(c=>c.path.includes('/rpc/')),false);h.get('reason').value='Fictional test approved';await h.submit('decision-form');const mutation=h.calls.find(c=>c.path.includes('/rpc/'));assert.deepEqual(mutation.body,{request_id:'request',approve:true,decision_reason:'Fictional test approved'});assert.equal(mutation.headers.Authorization,'Bearer fictional-access');assert.equal(h.get('decision').open,false);});
test('sign-out clears rendered staff data',async()=>{const h=harness();await h.submit('sign-in');h.get('logout').listeners.click();await h.settle();assert.equal(h.get('workspace').hidden,true);assert.equal(h.get('requests').children.length,0);assert.equal(h.get('identity').textContent,'');});
