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
    'processFamilyScheduleDirect',
    'processExternalTaskEventDirect',
    'queryWhereDirect'
  ];

  for (const name of expectedExports) {
    assert(
      typeof funcs[name] !== 'undefined',
      `Expected export '${name}' was not found in lib/index.js`
    );
  }
  console.log('✔ All expected functions and scheduled handlers exported');

  // Helper to create chained queries
  const batchSets = [];
  const createMockQuery = (docs = []) => {
    const q = {
      doc: (id) => ({
        id: id || 'doc_test',
        get: () => Promise.resolve({
          id: id || 'doc_test',
          exists: false,
          data: () => null,
          ref: { id: id || 'doc_test' }
        }),
        collection: (sub) => createMockQuery([])
      }),
      where: () => createMockQuery(docs),
      limit: (n) => createMockQuery(docs.slice(0, n)),
      get: () => Promise.resolve({
        empty: docs.length === 0,
        size: docs.length,
        docs: docs.map(d => ({
          id: d.id || 'doc_test',
          exists: true,
          ref: {
            id: d.id || 'doc_test',
            collection: (sub) => createMockQuery([])
          },
          data: () => d
        }))
      })
    };
    return q;
  };

  // 2. Test processFamilyScheduleDirect with mock Firestore DB
  const mockTaskDoc = {
    id: 'S-47f3989d-3f6d-4830-aa5f-f3e3eb12e1df',
    title: 'Clean Kitchen',
    description: '',
    familyCompletionMode: 'anyone',
    preferredBy: {},
    isMaster: false,
    futureInstancesCount: 5,
    lastSpawnedDate: { year: 2026, month: 9, day: 12 },
    priority: 'medium',
    schedules: [
      {
        id: 'R-e1da46fa-9236-4141-80ad-eb1119481ff9',
        scheduleId: 'S-47f3989d-3f6d-4830-aa5f-f3e3eb12e1df',
        type: 'weekly',
        interval: 1,
        startDate: { year: 2026, month: 8, day: 16 },
        schedulingPolicy: { type: 'fixedCalendar' },
        missedOccurrencePolicy: { type: 'keepAround', policy: 'preferOlder' },
        dueRelativeTime: { hour: 17, minute: 0, dayOffset: 0 },
        startRelativeTime: { hour: 9, minute: 0, dayOffset: 0 },
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7]
      }
    ],
    assignedUserId: 'z1NuzlWEHVY27tUgXGNFZMaSPlw1',
    activeOccurrenceIndex: 0,
    updatedAt: new Date(),
    skipIfNoCapacity: false,
    estimatedDuration: 15,
    labelIds: ['L-1e2a7255-64af-4ad1-bd93-ee70825fc41c'],
    isFamily: true
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
      set: (ref, data) => batchSets.push({ ref, data }),
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
  assert.strictEqual(directResult.tasksEvaluated, 1, 'Should evaluate 1 family task');
  assert(directResult.instancesSpawned > 0, 'Should spawn instances for family task');
  assert(!directResult.error, 'Should have no errors during scheduling');
  assert(batchSets.length > 0, 'Should write spawned instances to batch');
  console.log('✔ processFamilyScheduleDirect executes, evaluates isFamily tasks, and spawns instances cleanly');

  // 3. Test processHistoryCleanup with mock Firestore DB
  let historyDocs = [
    { id: 'hist_1', expiresAt: 1725000000000 },
    { id: 'hist_2', expiresAt: 1725500000000 }
  ];

  const capturedCleanupWhereArgs = [];
  const mockCleanupDb = {
    collectionGroup: (name) => ({
      where: (field, op, value) => {
        capturedCleanupWhereArgs.push({ field, op, value });
        return {
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
        };
      }
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

  // 7. Verify documents with single field 'o' and numeric string dates in tasks
  const fieldODoc = {
    id: 'S-field-o-test',
    title: 'Field O Task',
    description: '',
    familyCompletionMode: 'anyone',
    preferredBy: {},
    isMaster: false,
    futureInstancesCount: 5,
    lastSpawnedDate: { year: 2026, month: 9, day: 12 },
    priority: 'medium',
    schedules: [
      {
        id: 'R-field-o-rule',
        scheduleId: 'S-field-o-test',
        type: 'weekly',
        interval: 1,
        startDate: { year: 2026, month: 8, day: 16 },
        schedulingPolicy: { type: 'fixedCalendar' },
        missedOccurrencePolicy: { type: 'keepAround', policy: 'preferOlder' },
        dueRelativeTime: { hour: 17, minute: 0, dayOffset: 0 },
        startRelativeTime: { hour: 9, minute: 0, dayOffset: 0 },
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7]
      }
    ],
    updatedAt: '2026',
    o: { nestedData: 'value' },
    isFamily: true
  };

  const fieldODB = {
    collection: () => ({
      doc: () => ({
        id: 'fam_field_o',
        get: () => Promise.resolve({
          id: 'fam_field_o',
          exists: true,
          data: () => ({ name: 'Field O Family', o: { nestedData: 'value' } }),
          ref: {
            id: 'fam_field_o',
            collection: () => createMockQuery([fieldODoc])
          }
        }),
        collection: () => createMockQuery([fieldODoc])
      })
    }),
    batch: () => ({
      set: () => {},
      update: () => {},
      delete: () => {},
      commit: () => Promise.resolve()
    })
  };

  const fieldOResult = await funcs.processFamilyScheduleDirect(
    fieldODB,
    'fam_field_o',
    '2026-09-19T00:00:00.000Z'
  );
  assert(fieldOResult && fieldOResult.familyId === 'fam_field_o', 'Field O DB query should succeed');
  assert.strictEqual(fieldOResult.tasksEvaluated, 1, 'Should evaluate task with field o and year 2026 updatedAt date');
  console.log('✔ Documents with single field o and string ISO dates evaluated cleanly');

  // 8. Verify where query parameter conversion for Map/structured fields (Issue #820)
  const capturedWhereArgs = [];
  const existingInstanceDoc = {
    id: 'inst_existing_123',
    scheduledDate: { year: 2026, month: 9, day: 25 },
    status: 'pending',
    completedByUserIds: []
  };

  const mockTaskEventsDb = {
    collection: (name) => ({
      doc: (id) => ({
        id: id,
        collection: (subName) => ({
          where: (field, op, value) => {
            capturedWhereArgs.push({ field, op, value });
            return {
              where: (f2, op2, v2) => {
                capturedWhereArgs.push({ field: f2, op: op2, value: v2 });
                return {
                  where: (f3, op3, v3) => {
                    capturedWhereArgs.push({ field: f3, op: op3, value: v3 });
                    return {
                      limit: (n) => ({
                        get: () => Promise.resolve({
                          empty: false,
                          size: 1,
                          docs: [{
                            id: existingInstanceDoc.id,
                            exists: true,
                            ref: {
                              id: existingInstanceDoc.id,
                              update: (data) => Promise.resolve()
                            },
                            data: () => existingInstanceDoc
                          }]
                        })
                      })
                    };
                  },
                  limit: (n) => createMockQuery()
                };
              },
              limit: (n) => createMockQuery()
            };
          },
          doc: (id) => ({
            id: id || 'inst_gen_1',
            set: () => Promise.resolve()
          })
        })
      })
    })
  };

  const taskEventPayload = {
    userId: 'user_123',
    providerId: 'petal_count',
    entityType: 'supplement',
    externalId: 'preset_prenatal_morning',
    date: '2026-09-25',
    action: 'completed'
  };

  const eventResult = await funcs.processExternalTaskEventDirect(
    mockTaskEventsDb,
    taskEventPayload,
    '2026-09-25T12:00:00.000Z'
  );

  assert(eventResult && eventResult.success, 'processExternalTaskEventDirect must succeed');
  assert.strictEqual(eventResult.createdNewInstance, false, 'Should update existing instance without creating duplicate');
  assert.strictEqual(eventResult.instanceId, 'inst_existing_123');

  // Verify scheduledDate map conversion in where query clause
  const dateWhereClause = capturedWhereArgs.find(w => w.field === 'scheduledDate');
  assert(dateWhereClause, 'Expected where clause on scheduledDate');
  assert.strictEqual(dateWhereClause.op, '==');
  assert.strictEqual(typeof dateWhereClause.value, 'object', 'Query value must be an object');
  assert.strictEqual(dateWhereClause.value.year, 2026, 'year must match 2026');
  assert.strictEqual(dateWhereClause.value.month, 9, 'month must match 9');
  assert.strictEqual(dateWhereClause.value.day, 25, 'day must match 25');
  assert.strictEqual(Object.prototype.toString.call(dateWhereClause.value), '[object Object]', 'Query value must be a native JavaScript Object');
  assert.strictEqual(Array.isArray(dateWhereClause.value), false, 'Query value must not be an array');
  assert(Object.keys(dateWhereClause.value).includes('year'), 'Object.keys must enumerate properties');
  assert(Object.keys(dateWhereClause.value).includes('month'), 'Object.keys must enumerate properties');
  assert(Object.keys(dateWhereClause.value).includes('day'), 'Object.keys must enumerate properties');
  console.log('✔ JsQuery.where converts Dart Map values to native JavaScript Objects for structured query matching');


  // 9. Verify processExternalTaskEventDirect rejecting cleanly with an error (as rejected Promise)
  let rejectedError = null;
  try {
    await funcs.processExternalTaskEventDirect(
      mockTaskEventsDb,
      { userId: 'user_123' }, // Missing providerId, entityType, externalId, date, action
      '2026-09-25T12:00:00.000Z'
    );
  } catch (err) {
    rejectedError = err;
  }
  assert(rejectedError !== null, 'processExternalTaskEventDirect must reject Promise on invalid payload');
  assert(
    rejectedError.message && rejectedError.message.includes('Missing or invalid required string field'),
    `Expected validation error message but got: ${rejectedError.message}`
  );

  let nullPayloadError = null;
  try {
    await funcs.processExternalTaskEventDirect(mockTaskEventsDb, null);
  } catch (err) {
    nullPayloadError = err;
  }
  assert(nullPayloadError !== null, 'processExternalTaskEventDirect must reject Promise on null payload');
  console.log('✔ processExternalTaskEventDirect cleanly rejects invalid payloads as a rejected Promise');

  // 10. Verify processExternalTaskEventDirect resilient timestamp parsing for now
  for (const nowVal of [
    new Date('2026-09-25T12:00:00.000Z'),
    '1727265600000',
    1727265600000,
    '2026-09-25T12:00:00.000Z'
  ]) {
    const res = await funcs.processExternalTaskEventDirect(
      mockTaskEventsDb,
      taskEventPayload,
      nowVal
    );
    assert(res && res.success, `processExternalTaskEventDirect should succeed with now=${nowVal}`);
  }
  console.log('✔ processExternalTaskEventDirect parses DateTime, Date, numeric string, and epoch now values cleanly');

  // 11. Verify JsQuery.where conversion with DateTime, Iterable/List (in / array-contains-any), and non-String map keys
  const capturedDirectQueries = [];
  const createChainableQuery = () => ({
    where: (f, op, val) => {
      capturedDirectQueries.push({ field: f, op, value: val });
      return createChainableQuery();
    },
    limit: () => createChainableQuery(),
    get: () => Promise.resolve({ empty: true, size: 0, docs: [] })
  });
  const mockQueryDb = {
    collection: () => createChainableQuery()
  };

  await funcs.queryWhereDirect(mockQueryDb, [
    {
      field: 'status',
      op: 'in',
      value: ['pending', 'in_progress', 'completed']
    },
    {
      field: 'tags',
      op: 'array-contains-any',
      value: ['chore', 'home', 'daily']
    },
    {
      field: 'updatedAt',
      op: '<=',
      value: 1727280000000,
      isDateTime: true
    },
    {
      field: 'metadata',
      op: '==',
      isNonStringKeys: true
    }
  ]);

  const inClause = capturedDirectQueries.find(w => w.field === 'status');
  assert(inClause, 'Expected where clause on status');
  assert.strictEqual(inClause.op, 'in');
  assert(Array.isArray(inClause.value), 'Query value for "in" operator must be a native JavaScript Array');
  assert.deepStrictEqual(inClause.value, ['pending', 'in_progress', 'completed']);

  const arrayContainsClause = capturedDirectQueries.find(w => w.field === 'tags');
  assert(arrayContainsClause, 'Expected where clause on tags');
  assert.strictEqual(arrayContainsClause.op, 'array-contains-any');
  assert(Array.isArray(arrayContainsClause.value), 'Query value for "array-contains-any" must be a native JavaScript Array');
  assert.deepStrictEqual(arrayContainsClause.value, ['chore', 'home', 'daily']);

  const dateClause = capturedDirectQueries.find(w => w.field === 'updatedAt');
  assert(dateClause, 'Expected where clause on updatedAt');
  assert.strictEqual(dateClause.op, '<=');
  const isDirectDateOrTimestamp =
    dateClause.value instanceof Date ||
    (typeof dateClause.value.toMillis === 'function' && dateClause.value.toMillis() === 1727280000000) ||
    (typeof dateClause.value.toDate === 'function' && dateClause.value.toDate().getTime() === 1727280000000);
  assert(
    isDirectDateOrTimestamp,
    'Query value for DateTime must be converted to native JavaScript Date or Firestore Timestamp'
  );

  const nonStringKeyClause = capturedDirectQueries.find(w => w.field === 'metadata');
  assert(nonStringKeyClause, 'Expected where clause on metadata');
  assert.strictEqual(typeof nonStringKeyClause.value, 'object');
  assert.strictEqual(nonStringKeyClause.value['1'], 'first');
  assert.strictEqual(nonStringKeyClause.value['2'], 'second');
  console.log('✔ JsQuery.where converts Iterable/List, DateTime, and non-String Map keys cleanly');

  console.log('\nAll Node.js Bundle Interop Integration Tests passed successfully!');
}

runTests().catch((err) => {
  console.error('\n❌ Node.js Bundle Interop Integration Tests FAILED:', err);
  process.exit(1);
});
