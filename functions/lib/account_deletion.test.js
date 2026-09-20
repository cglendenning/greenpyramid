import assert from 'node:assert/strict';
import test from 'node:test';
import { deleteAccountTree } from './account_deletion.js';

class FakeDoc {
  constructor(store, path) {
    this.store = store;
    this.path = path;
    this.ref = this;
  }

  async listCollections() {
    const prefix = `${this.path}/`;
    const names = new Set();
    for (const path of this.store.data.keys()) {
      if (!path.startsWith(prefix)) continue;
      const name = path.slice(prefix.length).split('/')[0];
      if (name) names.add(name);
    }
    return [...names].map((name) => new FakeCollection(this.store, `${this.path}/${name}`));
  }

  async delete() {
    this.store.data.delete(this.path);
  }
}

class FakeCollection {
  constructor(store, path) {
    this.store = store;
    this.path = path;
  }

  doc(id) {
    return new FakeDoc(this.store, `${this.path}/${id}`);
  }

  async get() {
    const prefix = `${this.path}/`;
    const ids = new Set();
    for (const path of this.store.data.keys()) {
      if (!path.startsWith(prefix)) continue;
      const id = path.slice(prefix.length).split('/')[0];
      if (id) ids.add(id);
    }
    return { docs: [...ids].map((id) => this.doc(id)) };
  }
}

class FakeStore {
  constructor(data) {
    this.data = new Set(data);
  }

  collection(name) {
    return new FakeCollection(this, name);
  }
}

test('account deletion removes nested data and the auth identity', async () => {
  const store = new FakeStore([
    'users/u1',
    'users/u1/profile/main',
    'users/u1/tasks/t1',
    'users/u1/tasks/t1/notes/n1',
    'users/u1/recentActivity/a1',
    'users/u2/profile/main',
  ]);
  const auth = { deleted: null, deleteUser: async (uid) => { auth.deleted = uid; } };

  const result = await deleteAccountTree(store, auth, 'u1');

  assert.deepEqual(result, { deleted: true });
  assert.equal(auth.deleted, 'u1');
  assert.equal([...store.data].some((path) => path.startsWith('users/u1')), false);
  assert.equal(store.data.has('users/u2/profile/main'), true);
});

test('account deletion rejects a missing uid before touching storage', async () => {
  const store = new FakeStore(['users/u1']);
  const auth = { deleteUser: async () => { throw new Error('must not run'); } };
  await assert.rejects(deleteAccountTree(store, auth, ''), /account_uid_required/);
  assert.equal(store.data.has('users/u1'), true);
});
