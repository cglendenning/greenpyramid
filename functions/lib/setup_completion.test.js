import test from 'node:test';
import assert from 'node:assert/strict';
import { completeSetup, validateSetupDraft } from './setup_completion.js';
import { claimSetupRequest } from './setup_idempotency.js';
class Ref {
 constructor(store,path){this.store=store;this.path=path;}
 collection(n){return new Ref(this.store,`${this.path}/${n}`);} doc(n){return new Ref(this.store,`${this.path}/${n}`);}
 async get(){return {exists:this.path in this.store.data,data:()=>this.store.data[this.path]};}
 async set(d,o){this.store.data[this.path]=o?.merge?{...this.store.data[this.path],...d}:d;}
}
class Store {
 constructor(){this.data={};this.queue=Promise.resolve();} collection(n){return new Ref(this,n);}
 runTransaction(fn){const result=this.queue.then(async()=>{const writes=[];const value=await fn({get:r=>r.get(),set:(r,d,o)=>writes.push([r,d,o])});for(const [r,d,o] of writes)await r.set(d,o);return value;});this.queue=result.catch(()=>{});return result;}
}
const id='00000000-0000-0000-0000-000000000001';
function draft(){const ns=['Health','Family','Craft','Learning','Friends','Service'];return {firstName:'Craig',vision:'',categories:ns.map((name,i)=>({name,position:i+1,description:'A meaningful part of my life.'})),habits:Object.fromEntries(ns.map(n=>[n,[`Practice ${n.toLowerCase()}`]])),foundational:ns.slice(0,3).map((categoryName,i)=>({categoryId:i+1,categoryName,essence:''}))};}
function seed(s,state=draft()){s.data[`users/u/councilSessions/${id}`]={type:'setup',isComplete:false,setupDraft:{state}};}
test('D-001-AC-01: concurrent completion and replay preserve one server timestamp',async()=>{const s=new Store();seed(s);const values=await Promise.all([completeSetup(s,'u',id,new Date('2026-09-13')),completeSetup(s,'u',id,new Date('2026-09-14'))]);assert.deepEqual(values[0],values[1]);assert.equal(s.data['users/u'].setupCompletionId,id);assert.equal(s.data['users/u'].setupCompletedAt.toISOString(),'2026-09-13T00:00:00.000Z');assert.equal(values[0].requestId,id);assert.equal(values[0].trialGrantPending,true);assert.equal(s.data['users/u/profile/main'].categories[0].cat,'Health');assert.equal(s.data['users/u/profile/main'].firstName,'Craig');});
test('D-001-AC-01: incomplete setup never commits completion',async()=>{const s=new Store();seed(s,{...draft(),firstName:''});await assert.rejects(completeSetup(s,'u',id),/first_name_required/);assert.equal(s.data['users/u'],undefined);});
test('D-001-AC-01: another uid cannot complete the saved draft',async()=>{const s=new Store();seed(s);await assert.rejects(completeSetup(s,'someone-else',id),/invalid_setup_session/);});
test('D-001-AC-01: retries claim one dispatch and recover the acknowledged output',async()=>{const s=new Store();const body={sessionId:id};const cs=await Promise.all([claimSetupRequest(s,'u',id,'/deriveCategories',body),claimSetupRequest(s,'u',id,'/deriveCategories',body)]);assert.deepEqual(cs.map(c=>c.state),['claimed','pending']);await cs[0].ref.set({fingerprint:cs[0].fingerprint,state:'completed',status:200,response:{categories:[]}});assert.equal((await claimSetupRequest(s,'u',id,'/deriveCategories',body)).state,'completed');await assert.rejects(claimSetupRequest(s,'u',id,'/deriveCategories',{sessionId:'changed'}),/payload_conflict/);});
test('D-001-AC-03: empty personal depth is valid; invalid category/habit structures fail',()=>{assert.equal(validateSetupDraft(draft()).vision,'');for(const mutate of [s=>s.categories[1].position=1,s=>s.categories[1].name='Health',s=>s.habits.Health=[],s=>s.habits.Health=['x'.repeat(41)],s=>s.habits.Health=['A','B','C']]){const value=draft();mutate(value);assert.throws(()=>validateSetupDraft(value));}});
