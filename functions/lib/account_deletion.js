/**
 * Deletes the complete Firestore account tree before removing the Firebase
 * Auth identity. The uid is always supplied by verified middleware; callers
 * must never accept a uid from the request body.
 */
export async function deleteAccountTree(store, auth, uid) {
  if (typeof uid !== 'string' || uid.trim().length === 0) {
    throw new Error('account_uid_required');
  }

  const root = store.collection('users').doc(uid);
  await deleteDocumentTree(root);
  try {
    await auth.deleteUser(uid);
  } catch (error) {
    if (error?.code !== 'auth/user-not-found') throw error;
  }
  return { deleted: true };
}

async function deleteDocumentTree(ref) {
  for (const collection of await ref.listCollections()) {
    const snapshot = await collection.get();
    for (const doc of snapshot.docs) {
      await deleteDocumentTree(doc.ref);
    }
  }
  await ref.delete();
}
