import { readFileSync } from 'node:fs';
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, deleteDoc } from 'firebase/firestore';

let environment;

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: 'demo-greenpyramid',
    firestore: {
      rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

after(async () => environment?.cleanup());

test('D-146-AC-01: owned content operations succeed, protected fields fail', async () => {
  const db = environment.authenticatedContext('owner').firestore();
  const task = doc(db, 'users/owner/tasks/task-1');
  await assertSucceeds(setDoc(task, { category: 'Health', taskdescription: 'Walk' }));
  await assertSucceeds(updateDoc(task, { taskdescription: 'Walk outside' }));
  await assertSucceeds(deleteDoc(task));

  const profile = doc(db, 'users/owner/profile/main');
  await assertSucceeds(setDoc(profile, { categories: [], timezone: 'UTC' }));
  for (const field of [
    'entitlement', 'trialExpiresAt', 'spendCapUsd', 'totalSpendUsd',
    'spendReservations', 'deliveryState', 'modelConfiguration',
  ]) {
    await assertFails(updateDoc(profile, { [field]: 'client-forged' }));
  }
});

test('D-146-AC-01: users cannot read or mutate another account or global config', async () => {
  const db = environment.authenticatedContext('owner').firestore();
  const otherProfile = doc(db, 'users/other/profile/main');
  await assertFails(setDoc(otherProfile, { categories: [] }));
  await assertFails(updateDoc(otherProfile, { categories: [] }));
  await assertFails(deleteDoc(otherProfile));
  await assertFails(setDoc(doc(db, 'config/council'), { model: 'claude-haiku-4-5' }));
});

test('D-149-AC-01: clients cannot create installation or inbox delivery state', async () => {
  const db = environment.authenticatedContext('owner').firestore();
  await assertFails(setDoc(doc(db, 'users/owner/installations/i1'), {
    installationId: 'i1', token: 'forged-token', enabled: true, revision: 1,
  }));
  await assertFails(setDoc(doc(db, 'users/owner/inbox/message1'), {
    messageKey: 'message1', type: 'tailored', title: 'forged', read: false,
  }));
});
