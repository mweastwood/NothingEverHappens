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

    it('denies a user from writing to another user\'s profile if not in same family or not a parent', async () => {
      const aliceContext = testEnv.authenticatedContext('alice');
      const db = aliceContext.firestore();

      await assertFails(db.collection('users').doc('bob').set({
        displayName: 'Bob Clone'
      }));
    });

    it('allows a family parent to update a member\'s profile in the same family', async () => {
      await seedData(async (context) => {
        const db = context.firestore();
        await db.collection('families').doc('fam-1').set({
          name: 'The Simpsons',
          members: {
            'alice': { role: 'parent', displayName: 'Alice' },
            'bob': { role: 'non-parent', displayName: 'Bob' }
          }
        });
        await db.collection('users').doc('bob').set({
          displayName: 'Bob',
          familyId: 'fam-1',
          familyRole: 'non-parent'
        });
      });

      const aliceContext = testEnv.authenticatedContext('alice');
      const db = aliceContext.firestore();

      await assertSucceeds(db.collection('users').doc('bob').update({
        familyRole: 'parent'
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

  describe('Instances collection', () => {
    it('allows a user to read and write their own private instances', async () => {
      const aliceContext = testEnv.authenticatedContext('alice');
      const db = aliceContext.firestore();

      await assertSucceeds(db.collection('users').doc('alice').collection('instances').doc('inst-1').set({
        title: 'Alice Task'
      }));

      await assertSucceeds(db.collection('users').doc('alice').collection('instances').doc('inst-1').get());
    });

    it('denies a user from writing to another user\'s private instances', async () => {
      const aliceContext = testEnv.authenticatedContext('alice');
      const db = aliceContext.firestore();

      await assertFails(db.collection('users').doc('bob').collection('instances').doc('inst-1').set({
        title: 'Bob Clone Task'
      }));
    });

    it('allows family members to read, create and update family instances, but only parents to delete', async () => {
      // Seed family
      await seedData(async (context) => {
        const db = context.firestore();
        await db.collection('families').doc('fam-1').set({
          name: 'The Simpsons',
          members: {
            'alice': { role: 'parent', displayName: 'Alice' },
            'bob': { role: 'non-parent', displayName: 'Bob' }
          }
        });
      });

      // Alice (parent)
      const aliceContext = testEnv.authenticatedContext('alice');
      const aliceDb = aliceContext.firestore();

      // Bob (non-parent)
      const bobContext = testEnv.authenticatedContext('bob');
      const bobDb = bobContext.firestore();

      // Create instance (Bob can create)
      await assertSucceeds(bobDb.collection('families').doc('fam-1').collection('instances').doc('inst-1').set({
        title: 'Clean room'
      }));

      // Read instance (Alice can read)
      await assertSucceeds(aliceDb.collection('families').doc('fam-1').collection('instances').doc('inst-1').get());

      // Update instance (Bob can update)
      await assertSucceeds(bobDb.collection('families').doc('fam-1').collection('instances').doc('inst-1').update({
        status: 'completed'
      }));

      // Delete instance: Bob (non-parent) fails
      await assertFails(bobDb.collection('families').doc('fam-1').collection('instances').doc('inst-1').delete());

      // Delete instance: Alice (parent) succeeds
      await assertSucceeds(aliceDb.collection('families').doc('fam-1').collection('instances').doc('inst-1').delete());
    });
  });

  describe('Recipes collection', () => {
    it('allows a user to read and write their own private recipes', async () => {
      const aliceContext = testEnv.authenticatedContext('alice');
      const db = aliceContext.firestore();

      await assertSucceeds(db.collection('users').doc('alice').collection('recipes').doc('recipe-1').set({
        title: 'Pancakes',
        servings: 4
      }));

      await assertSucceeds(db.collection('users').doc('alice').collection('recipes').doc('recipe-1').get());
    });

    it('denies a user from writing to another user\'s private recipes', async () => {
      const aliceContext = testEnv.authenticatedContext('alice');
      const db = aliceContext.firestore();

      await assertFails(db.collection('users').doc('bob').collection('recipes').doc('recipe-1').set({
        title: 'Waffles'
      }));
    });

    it('allows family members to read and write family recipes', async () => {
      await seedData(async (context) => {
        const db = context.firestore();
        await db.collection('families').doc('fam-1').set({
          name: 'The Simpsons',
          members: {
            'alice': { role: 'parent', displayName: 'Alice' },
            'bob': { role: 'non-parent', displayName: 'Bob' }
          }
        });
      });

      const aliceContext = testEnv.authenticatedContext('alice');
      const aliceDb = aliceContext.firestore();
      const bobContext = testEnv.authenticatedContext('bob');
      const bobDb = bobContext.firestore();

      // Bob creates recipe
      await assertSucceeds(bobDb.collection('families').doc('fam-1').collection('recipes').doc('recipe-1').set({
        title: 'Family Pasta'
      }));

      // Alice reads recipe
      await assertSucceeds(aliceDb.collection('families').doc('fam-1').collection('recipes').doc('recipe-1').get());

      // Alice updates recipe
      await assertSucceeds(aliceDb.collection('families').doc('fam-1').collection('recipes').doc('recipe-1').update({
        servings: 6
      }));
    });
  });

  describe('History collection', () => {
    it('allows a user to read and write their own private history entries', async () => {
      const aliceContext = testEnv.authenticatedContext('alice');
      const db = aliceContext.firestore();

      await assertSucceeds(db.collection('users').doc('alice').collection('history').doc('delta-1').set({
        action: 'taskCompleted',
        taskId: 'task-123',
        expiresAt: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000)
      }));

      await assertSucceeds(db.collection('users').doc('alice').collection('history').doc('delta-1').get());
    });

    it('denies a user from reading or writing another user\'s private history entries', async () => {
      const aliceContext = testEnv.authenticatedContext('alice');
      const db = aliceContext.firestore();

      await assertFails(db.collection('users').doc('bob').collection('history').doc('delta-1').set({
        action: 'taskCompleted',
        taskId: 'task-123'
      }));

      await assertFails(db.collection('users').doc('bob').collection('history').doc('delta-1').get());
    });

    it('allows family members to read and create family history, but denies update and delete (append-only)', async () => {
      await seedData(async (context) => {
        const db = context.firestore();
        await db.collection('families').doc('fam-1').set({
          name: 'The Simpsons',
          members: {
            'alice': { role: 'parent', displayName: 'Alice' },
            'bob': { role: 'non-parent', displayName: 'Bob' }
          }
        });
      });

      const aliceContext = testEnv.authenticatedContext('alice');
      const aliceDb = aliceContext.firestore();
      const bobContext = testEnv.authenticatedContext('bob');
      const bobDb = bobContext.firestore();

      // Bob creates family history entry
      await assertSucceeds(bobDb.collection('families').doc('fam-1').collection('history').doc('delta-1').set({
        action: 'familyTaskCompleted',
        taskId: 'task-fam-1',
        expiresAt: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000)
      }));

      // Alice reads family history entry
      await assertSucceeds(aliceDb.collection('families').doc('fam-1').collection('history').doc('delta-1').get());

      // Alice tries to update history entry (denied: append-only)
      await assertFails(aliceDb.collection('families').doc('fam-1').collection('history').doc('delta-1').update({
        action: 'tampered'
      }));

      // Alice (parent) tries to delete history entry (denied: append-only for clients)
      await assertFails(aliceDb.collection('families').doc('fam-1').collection('history').doc('delta-1').delete());
    });
  });
});

