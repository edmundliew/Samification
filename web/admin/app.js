const origin = 'https://vqexfcvzoryocjnzjozv.supabase.co';
const publicKey = 'sb_publishable_yq9lHLgQLzPqCEMfcD52sA_e61dce5g';
const $ = id => document.getElementById(id);
let session = null, data = null, pending = null, busy = false;
const status = message => { $('status').textContent = message; };
function lock(value) { busy = value; document.querySelectorAll('button').forEach(b => { b.disabled = value; }); }
function clear() { session = null; data = null; pending = null; $('password').value = ''; $('workspace').hidden = true; $('login').hidden = false; for (const id of ['identity','requests','memberships','wards','audit']) $(id).replaceChildren(); if ($('decision').open) $('decision').close(); }
async function api(path, {method = 'GET', body, token = session?.access_token} = {}) {
  const response = await fetch(origin + path, {method, credentials:'omit', cache:'no-store', redirect:'error', headers:{apikey:publicKey, 'Content-Type':'application/json', ...(token ? {Authorization:`Bearer ${token}`} : {})}, ...(body ? {body:JSON.stringify(body)} : {}), signal:AbortSignal.timeout(20000)});
  if (!response.ok) {
    if (response.status === 401 && token) { clear(); throw Error('Your session has expired. Sign in again.'); }
    if (response.status === 403) throw Error('The server denied this action. Refresh to check your access.');
    if (path.startsWith('/auth/')) throw Error(response.status === 429 ? 'Too many sign-in attempts. Please wait before trying again.' : 'Sign-in failed. Check your email and password. First-time accounts need email verification and password setup in the app.');
    throw Error('The server could not complete the request. Refresh to check the latest state before retrying.');
  }
  const text = await response.text(); return text ? JSON.parse(text) : null;
}
function isAdmin(rows) { return rows.some(m => m.user_id === session?.user?.id && m.role === 'administrator' && m.active); }
async function renew() {
  if (!session) throw Error('Sign in again.');
  if (session.expires_at > Date.now()/1000 + 60) return;
  const previous = session;
  const next = await api('/auth/v1/token?grant_type=refresh_token', {method:'POST', body:{refresh_token:previous.refresh_token}, token:null});
  if (next.user?.id !== previous.user.id) { clear(); throw Error('Sign in again.'); }
  session = next;
}
async function load() {
  await renew();
  const memberships = await api('/rest/v1/staff_memberships?select=id,user_id,role,scope_id,active&order=created_at.desc');
  if (!isAdmin(memberships)) { const token=session.access_token; clear(); await api('/auth/v1/logout?scope=local',{method:'POST',token}).catch(()=>{}); throw Error('This account has no active administrator access. Use the clinician app or contact the project owner.'); }
  const [requests, scopes, audit] = await Promise.all([
    api('/rest/v1/staff_access_requests?select=id,user_id,scope_id,display_name,status&order=requested_at.desc'),
    api('/rest/v1/care_scopes?select=id,name,active&order=name'),
    api('/rest/v1/access_audit_events?select=id,at,actor_id,subject_id,action,scope_id,reason&order=at.desc,id.desc&limit=100')
  ]);
  data = {memberships, requests, scopes, audit}; render();
}
function text(tag, value) { const el = document.createElement(tag); el.textContent = value; return el; }
const scope = id => data.scopes.find(s => s.id === id)?.name ?? (id ? 'Unknown ward' : 'All staff access');
const person = id => data.requests.find(r => r.user_id === id)?.display_name ?? id;
function action(label, decision) { const b = text('button', label); b.type = 'button'; b.className = 'secondary'; b.addEventListener('click', () => { if (busy) return; pending = decision; $('decision-title').textContent = label; $('decision-description').textContent = decision.description; $('reason').value = ''; $('decision').showModal(); $('reason').focus(); }); return b; }
function render() {
  $('login').hidden = true; $('workspace').hidden = false; $('identity').textContent = session.user.email;
  for (const id of ['requests','memberships','wards','audit']) $(id).replaceChildren();
  for (const r of data.requests.filter(r => r.status === 'pending')) {
    const card = document.createElement('div'); card.className='record'; card.append(text('strong', r.display_name), text('p', scope(r.scope_id)), text('p', `User ID: ${r.user_id}`));
    const actions = document.createElement('div'); actions.className='actions';
    for (const approve of [true,false]) actions.append(action(approve?'Approve clinician':'Reject request', {path:'/rest/v1/rpc/decide_clinician_access', body:{request_id:r.id, approve}, description:`${r.display_name} · ${scope(r.scope_id)} · ${approve?'Grant clinician access to this ward only.':'Reject this access request.'}`}));
    card.append(actions); $('requests').append(card);
  }
  if (!$('requests').children.length) $('requests').append(text('p','No pending requests.'));
  for (const m of data.memberships.filter(m => m.role === 'clinician')) {
    const card = document.createElement('div'); card.className='record'; card.append(text('strong',person(m.user_id)),text('p',`${scope(m.scope_id)} · ${m.active?'Active':'Suspended'}`),text('p',`User ID: ${m.user_id}`),action(m.active?'Suspend access':'Resume access',{path:'/rest/v1/rpc/set_clinician_access',body:{membership_id:m.id,enabled:!m.active},description:`${person(m.user_id)} · ${scope(m.scope_id)} · ${m.active?'Suspend':'Restore'} clinician access to this ward.`})); $('memberships').append(card);
  }
  if (!$('memberships').children.length) $('memberships').append(text('p','No clinician memberships.'));
  for (const s of data.scopes) $('wards').append(text('p',`${s.name} · ${s.active?'Active':'Inactive'}`));
  for (const a of data.audit) { const row = document.createElement('tr'); for (const value of [new Date(a.at).toLocaleString(),a.action,person(a.subject_id),scope(a.scope_id),person(a.actor_id),a.reason??'—']) row.append(text('td',value)); $('audit').append(row); }
}
async function run(work) { if (busy) return; lock(true); status('Working…'); try { await work(); } catch(error) { status(error instanceof Error ? error.message : 'Unable to connect. Try again.'); } finally { lock(false); } }
$('sign-in').addEventListener('submit', event => { event.preventDefault(); const password = $('password').value; $('password').value=''; void run(async () => { session = await api('/auth/v1/token?grant_type=password',{method:'POST',body:{email:$('email').value.trim(),password},token:null}); try { await load(); } catch(error) { const token=session?.access_token; clear(); if(token) await api('/auth/v1/logout?scope=local',{method:'POST',token}).catch(()=>{}); throw error; } status('Administrator access verified.'); }); });
$('refresh').addEventListener('click', () => { void run(async () => { await load(); status('Access and audit history refreshed.'); }); });
$('logout').addEventListener('click', () => { void run(async () => { const token=session?.access_token; clear(); if(token) await api('/auth/v1/logout?scope=local',{method:'POST',token}); status('Signed out.'); }); });
$('cancel').addEventListener('click', () => { pending=null; $('decision').close(); });
$('decision').addEventListener('cancel', () => { pending=null; });
$('decision-form').addEventListener('submit', event => { event.preventDefault(); const decision=pending, reason=$('reason').value.trim(); if(!decision || !reason || reason.length>500) return; void run(async () => { await renew(); await api(decision.path,{method:'POST',body:{...decision.body,[decision.path.endsWith('decide_clinician_access')?'decision_reason':'change_reason']:reason}}); pending=null; $('reason').value=''; $('decision').close(); await load(); status('Decision recorded in the access audit log.'); }); });
document.addEventListener('visibilitychange', () => { if(document.hidden) $('password').value=''; });
