const { assertSucceeds, assertFails, initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const fs = require('fs');
const path = require('path');

describe('Firestore Security Rules', () => {
  let testEnv;

  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: 'demo-nothing-ever-happens-test',
      firestore: {
        rules: fs.readFileSync(path.resolve(__dirname, '../db/firestore.rules'), 'utf8'),
        host: '127.0.0.1',
        port: 8080,
      },
    });
  });

  after(async () => {
    await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  // Helper to run operations with rules disabled (to seed data)
  async function seedData(callback) {
    await testEnv.withSecurityRulesDisabled(callback);
  }

  describe('Users collection', () => {
    it('allows a user to read and write their own profile', async () => {
      const aliceContext = testEnv.authenticatedContext('alice');
      const db = aliceContext.firestore();

      await assertSucceeds(db.collection('users').doc('alice').set({
        displayName: 'Alice',
        email: 'alice@example.com'
      }));

      await assertSucceeds(db.collection('users').doc('alice').get());
    });

    it('denies a user from writing to another user\'s profile', async () => {
      const aliceContext = testEnv.authenticatedContext('alice');
      const db = aliceContext.firestore();

      await assertFails(db.collection('users').doc('bob').set({
        displayName: 'Bob Clone'
      }));
    });
  });

  describe('Families collection', () => {
    it('allows any authenticated user to create a family', async () => {
      const aliceContext = testEnv.authenticatedContext('alice');
      const db = aliceContext.firestore();

      await assertSucceeds(db.collection('families').doc('fam-1').set({
        name: 'The Simpsons',
        members: {
          'alice': { role: 'parent', displayName: 'Alice' }
        }
      }));
    });

    it('allows family members to read their family document', async () => {
      // Seed family
      await seedData(async (context) => {
        const db = context.firestore();
        await db.collection('families').doc('fam-1').set({
          name: 'The Simpsons',
          members: {
            'alice': { role: 'parent', displayName: 'Alice' }
          }
        });
      });

      const aliceContext = testEnv.authenticatedContext('alice');
      const db = aliceContext.firestore();
      await assertSucceeds(db.collection('families').doc('fam-1').get());
    });

    it('denies non-members from reading a family document', async () => {
      await seedData(async (context) => {
        const db = context.firestore();
        await db.collection('families').doc('fam-1').set({
          name: 'The Simpsons',
          members: {
            'alice': { role: 'parent', displayName: 'Alice' }
          }
        });
      });

      const bobContext = testEnv.authenticatedContext('bob');
      const db = bobContext.firestore();
      await assertFails(db.collection('families').doc('fam-1').get());
    });

    it('allows an invited user to accept an invite by adding themselves to family members', async () => {
      await seedData(async (context) => {
        const db = context.firestore();
        await db.collection('families').doc('fam-1').set({
          name: 'The Simpsons',
          members: {
            'alice': { role: 'parent', displayName: 'Alice' }
          }
        });
      });

      // Bob wants to join (Bob is not currently in the family)
      const bobContext = testEnv.authenticatedContext('bob');
      const db = bobContext.firestore();

      // This is the update operation that would have crashed the rules evaluator
      // if using `resource.data.members[request.auth.uid]` because bob is not in members.
      // Now it should pass the rules check because:
      // bob (request.auth.uid) is in request.resource.data.members, and not in resource.data.members.
      await assertSucceeds(
        db.collection('families').doc('fam-1').update({
          'members.bob': { role: 'non-parent', displayName: 'Bob' }
        })
      );
    });
  });

  describe('Invites collection', () => {
    it('allows a family parent to create an invite', async () => {
      // Seed the family with alice as parent
      await seedData(async (context) => {
        const db = context.firestore();
        await db.collection('families').doc('fam-1').set({
          name: 'The Simpsons',
          members: {
            'alice': { role: 'parent', displayName: 'Alice' }
          }
        });
      });

      const aliceContext = testEnv.authenticatedContext('alice', { email: 'alice@example.com' });
      const db = aliceContext.firestore();

      await assertSucceeds(
        db.collection('invites').doc('invite-1').set({
          familyId: 'fam-1',
          familyName: 'The Simpsons',
          fromEmail: 'alice@example.com',
          toEmail: 'bob@example.com',
          role: 'non-parent',
          status: 'pending'
        })
      );
    });

    it('denies a non-parent from creating an invite', async () => {
      // Seed the family with bob as non-parent
      await seedData(async (context) => {
        const db = context.firestore();
        await db.collection('families').doc('fam-1').set({
          name: 'The Simpsons',
          members: {
            'bob': { role: 'non-parent', displayName: 'Bob' }
          }
        });
      });

      const bobContext = testEnv.authenticatedContext('bob', { email: 'bob@example.com' });
      const db = bobContext.firestore();

      await assertFails(
        db.collection('invites').doc('invite-1').set({
          familyId: 'fam-1',
          familyName: 'The Simpsons',
          fromEmail: 'bob@example.com',
          toEmail: 'alice@example.com',
          role: 'non-parent',
          status: 'pending'
        })
      );
    });
  });
});
