/**
 * Node.js Bundle Interop Integration Test
 *
 * Verifies that the compiled dart2js bundle (lib/index.js) can be loaded
 * in Node.js and that exported methods and scheduled functions resolve
 * JavaScript Promises correctly without throwing:
 *   NoSuchMethodError: method not found: 'then' (a.then is not a function)
 */

const assert = require('assert');
const path = require('path');

const bundlePath = path.resolve(__dirname, '../lib/index.js');
const funcs = require(bundlePath);

async function runTests() {
  console.log('Running Node.js Bundle Interop Integration Tests...');

  // 1. Verify expected exports
  const expectedExports = [
    'deleteUserAccount',
    'reportExternalTaskEvent',
    'cleanupExpiredHistory',
    'status',
    'scheduleFamilyTasks',
    'processFamilySchedule',
    'processHistoryCleanup',
    'processFamilyScheduleDirect'
  ];

  for (const name of expectedExports) {
    assert(
      typeof funcs[name] !== 'undefined',
      `Expected export '${name}' was not found in lib/index.js`
    );
  }
  console.log('✔ All expected functions and scheduled handlers exported');

  // Helper to create chained queries
  const createMockQuery = (docs = []) => {
    const q = {
      where: () => createMockQuery(docs),
      limit: (n) => createMockQuery(docs.slice(0, n)),
      get: () => Promise.resolve({
        empty: docs.length === 0,
        size: docs.length,
        docs: docs.map(d => ({
          id: d.id || 'doc_test',
          exists: true,
          ref: { id: d.id || 'doc_test' },
          data: () => d
        }))
      })
    };
    return q;
  };

  // 2. Test processFamilyScheduleDirect with mock Firestore DB
  const mockTaskDoc = {
    id: 'task_1',
    name: 'Clean bedroom',
    familyId: 'fam_test',
    frequency: 'daily',
    active: true,
    deleted: false
  };

  const mockDb = {
    collection: (name) => ({
      doc: (id) => ({
        id: id,
        get: () => Promise.resolve({
          id: id,
          exists: true,
          data: () => ({ name: 'Test Family' }),
          ref: { id: id }
        }),
        collection: (sub) => createMockQuery(sub === 'tasks' ? [mockTaskDoc] : [])
      }),
      where: () => createMockQuery([mockTaskDoc]),
      limit: () => createMockQuery([mockTaskDoc]),
      get: () => createMockQuery([mockTaskDoc]).get()
    }),
    batch: () => ({
      set: () => {},
      update: () => {},
      delete: () => {},
      commit: () => Promise.resolve()
    })
  };

  const directResultPromise = funcs.processFamilyScheduleDirect(
    mockDb,
    'fam_test',
    '2026-09-19T00:00:00.000Z'
  );

  assert(
    directResultPromise && typeof directResultPromise.then === 'function',
    'processFamilyScheduleDirect must return a native thenable Promise'
  );

  const directResult = await directResultPromise;
  assert(directResult, 'Result must be returned');
  assert.strictEqual(directResult.familyId, 'fam_test');
  console.log('✔ processFamilyScheduleDirect executes and resolves native Promises cleanly');

  // 3. Test processHistoryCleanup with mock Firestore DB
  let historyDocs = [
    { id: 'hist_1', expiresAt: 1725000000000 },
    { id: 'hist_2', expiresAt: 1725500000000 }
  ];

  const mockCleanupDb = {
    collectionGroup: (name) => ({
      where: () => ({
        where: () => ({
          limit: () => ({
            get: () => {
              const current = [...historyDocs];
              historyDocs = [];
              return Promise.resolve({
                empty: current.length === 0,
                size: current.length,
                docs: current.map(d => ({
                  id: d.id,
                  exists: true,
                  ref: { id: d.id },
                  data: () => d
                }))
              });
            }
          })
        }),
        limit: () => ({
          get: () => {
            const current = [...historyDocs];
            historyDocs = [];
            return Promise.resolve({
              empty: current.length === 0,
              size: current.length,
              docs: current.map(d => ({
                id: d.id,
                exists: true,
                ref: { id: d.id },
                data: () => d
              }))
            });
          }
        })
      })
    }),
    batch: () => {
      const deleted = [];
      return {
        delete: (ref) => deleted.push(ref),
        commit: () => Promise.resolve()
      };
    }
  };

  const cleanupPromise = funcs.processHistoryCleanup(
    mockCleanupDb,
    1726000000000,
    10,
    5
  );

  assert(
    cleanupPromise && typeof cleanupPromise.then === 'function',
    'processHistoryCleanup must return a native thenable Promise'
  );

  const cleanupResult = await cleanupPromise;
  assert(cleanupResult, 'Cleanup result must be returned');
  assert.strictEqual(cleanupResult.success, true);
  console.log('✔ processHistoryCleanup executes and resolves native Promises cleanly');

  // 4. Test error handling when underlying Firestore query rejects
  const failingDb = {
    collection: () => ({
      doc: () => ({
        id: 'fam_fail',
        get: () => Promise.reject(new Error('Simulated network fault')),
        collection: () => ({
          get: () => Promise.reject(new Error('Simulated network fault'))
        })
      })
    })
  };

  const failingResult = await funcs.processFamilyScheduleDirect(
    failingDb,
    'fam_fail',
    '2026-09-19T00:00:00.000Z'
  );

  assert(
    failingResult && failingResult.error,
    'Expected error to be caught and recorded in summary rather than crashing on a.then'
  );
  assert(
    failingResult.error.includes('Simulated network fault'),
    `Expected simulated failure error message, got: ${failingResult.error}`
  );
  assert(
    !failingResult.error.includes("NoSuchMethodError: method not found: 'then'"),
    `Error should not be NoSuchMethodError: ${failingResult.error}`
  );
  console.log('✔ Error handling caught and recorded rejection without a.then exception');

  // 5. Verify scheduled handler exports
  assert(typeof funcs.scheduleFamilyTasks === 'function', 'scheduleFamilyTasks must be a function');
  assert(typeof funcs.cleanupExpiredHistory === 'function', 'cleanupExpiredHistory must be a function');
  console.log('✔ Scheduled functions are properly configured');

  // 6. Verify subcollection query execution on native JS document references
  const subcollectionDb = {
    collection: () => ({
      doc: () => ({
        id: 'fam_sub',
        get: () => Promise.resolve({
          id: 'fam_sub',
          exists: true,
          data: () => ({ name: 'Sub Test' }),
          ref: {
            id: 'fam_sub',
            collection: () => createMockQuery([mockTaskDoc])
          }
        }),
        collection: () => createMockQuery([mockTaskDoc])
      })
    }),
    batch: () => ({
      set: () => {},
      update: () => {},
      delete: () => {},
      commit: () => Promise.resolve()
    })
  };

  const subResult = await funcs.processFamilyScheduleDirect(
    subcollectionDb,
    'fam_sub',
    '2026-09-19T00:00:00.000Z'
  );
  assert(subResult && subResult.familyId === 'fam_sub', 'Subcollection DB query should succeed without type cast error');
  console.log('✔ Subcollection resolution on native JS document references succeeded cleanly');

  console.log('\nAll Node.js Bundle Interop Integration Tests passed successfully!');
}

runTests().catch((err) => {
  console.error('\n❌ Node.js Bundle Interop Integration Tests FAILED:', err);
  process.exit(1);
});
