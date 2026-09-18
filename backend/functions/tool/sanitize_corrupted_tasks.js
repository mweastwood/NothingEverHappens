#!/usr/bin/env node

/**
 * Script to sanitize corrupted pending task instances in Firestore.
 *
 * Instances that have `status: pending` but:
 * 1. `statusReason: user_dismissed` are updated to `status: skipped`.
 * 2. `completedAt` != null and `completedByUserId` != null (or `statusReason: user_completed`)
 *    are updated to `status: completed` and `statusReason: user_completed`.
 *
 * Usage:
 *   node backend/functions/tool/sanitize_corrupted_tasks.js [--dry-run] [--userId=<userId>] [--projectId=<projectId>]
 */

const { execSync } = require('child_process');

function getAccessToken() {
  if (process.env.ACCESS_TOKEN) return process.env.ACCESS_TOKEN;
  try {
    return execSync('gcloud auth print-access-token', { stdio: ['ignore', 'pipe', 'ignore'] })
      .toString()
      .trim();
  } catch (e) {
    throw new Error('Unable to obtain access token from gcloud. Set ACCESS_TOKEN or run gcloud auth login.');
  }
}

function parseFirestoreValue(val) {
  if (!val) return null;
  if ('stringValue' in val) return val.stringValue;
  if ('integerValue' in val) return parseInt(val.integerValue, 10);
  if ('timestampValue' in val) return val.timestampValue;
  if ('booleanValue' in val) return val.booleanValue;
  if ('mapValue' in val) {
    const res = {};
    for (const [k, v] of Object.entries(val.mapValue.fields || {})) {
      res[k] = parseFirestoreValue(v);
    }
    return res;
  }
  if ('arrayValue' in val) {
    return (val.arrayValue.values || []).map(parseFirestoreValue);
  }
  return null;
}

async function main() {
  const args = process.argv.slice(2);
  const isDryRun = args.includes('--dry-run');
  const userArg = args.find((a) => a.startsWith('--userId='));
  const targetUserId = userArg
    ? userArg.split('=')[1]
    : 'z1NuzlWEHVY27tUgXGNFZMaSPlw1';
  const projArg = args.find((a) => a.startsWith('--projectId='));
  const projectId = projArg ? projArg.split('=')[1] : 'nothing-ever-happens-prod';

  const token = getAccessToken();

  console.log(`--- Firestore Instance Sanitizer ---`);
  console.log(`Project: ${projectId}`);
  console.log(`Mode: ${isDryRun ? 'DRY RUN (no writes)' : 'LIVE UPDATE'}`);
  console.log(`Target User ID: ${targetUserId}\n`);

  const queryUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users/${targetUserId}:runQuery`;
  const queryBody = {
    structuredQuery: {
      from: [{ collectionId: 'instances' }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'status' },
          op: 'EQUAL',
          value: { stringValue: 'pending' },
        },
      },
    },
  };

  const resp = await fetch(queryUrl, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(queryBody),
  });

  if (!resp.ok) {
    const errText = await resp.text();
    throw new Error(`Firestore query failed (${resp.status}): ${errText}`);
  }

  const results = await resp.json();
  const docs = results.filter((r) => r.document).map((r) => r.document);
  console.log(`Found ${docs.length} pending instance(s) in Firestore for user ${targetUserId}.\n`);

  let dismissedToHeal = [];
  let completedToHeal = [];

  for (const doc of docs) {
    const fields = doc.fields || {};
    const title = parseFirestoreValue(fields.title) || 'Untitled';
    const scheduledDate = parseFirestoreValue(fields.scheduledDate);
    const statusReason = parseFirestoreValue(fields.statusReason);
    const completedAt = parseFirestoreValue(fields.completedAt);
    const completedByUserId = parseFirestoreValue(fields.completedByUserId);
    const docPath = doc.name;
    const docId = docPath.split('/').pop();

    const dateStr = scheduledDate ? `${scheduledDate.year}-${String(scheduledDate.month).padStart(2, '0')}-${String(scheduledDate.day).padStart(2, '0')}` : 'unknown';

    if (statusReason === 'user_dismissed') {
      dismissedToHeal.push({ docPath, docId, title, dateStr, statusReason, completedAt });
    } else if (statusReason === 'user_completed' || (completedAt && completedByUserId)) {
      completedToHeal.push({ docPath, docId, title, dateStr, statusReason, completedAt });
    }
  }

  console.log(`=== Instances to Heal to SKIPPED (user_dismissed) [${dismissedToHeal.length}] ===`);
  for (const item of dismissedToHeal) {
    console.log(`  - [${item.dateStr}] "${item.title}" (id: ${item.docId}, completedAt: ${item.completedAt})`);
  }

  console.log(`\n=== Instances to Heal to COMPLETED (user_completed) [${completedToHeal.length}] ===`);
  for (const item of completedToHeal) {
    console.log(`  - [${item.dateStr}] "${item.title}" (id: ${item.docId}, completedAt: ${item.completedAt})`);
  }

  const totalToHeal = dismissedToHeal.length + completedToHeal.length;
  console.log(`\nSummary:`);
  console.log(`- Pending instances with user_dismissed: ${dismissedToHeal.length} -> will be marked SKIPPED`);
  console.log(`- Pending instances with completedAt:    ${completedToHeal.length} -> will be marked COMPLETED`);
  console.log(`- Total corrupted instances to heal:     ${totalToHeal}`);

  if (totalToHeal === 0) {
    console.log('\nNo corrupted instances found! Database is already clean.');
    return;
  }

  if (isDryRun) {
    console.log('\nDRY RUN complete. Run without --dry-run to commit these updates to Firestore.');
    return;
  }

  console.log('\nCommitting updates to Firestore...');
  const writes = [];

  for (const item of dismissedToHeal) {
    writes.push({
      update: {
        name: item.docPath,
        fields: {
          status: { stringValue: 'skipped' },
          statusReason: { stringValue: 'user_dismissed' },
          updatedAt: { timestampValue: new Date().toISOString() },
        },
      },
      updateMask: {
        fieldPaths: ['status', 'statusReason', 'updatedAt'],
      },
    });
  }

  for (const item of completedToHeal) {
    writes.push({
      update: {
        name: item.docPath,
        fields: {
          status: { stringValue: 'completed' },
          statusReason: { stringValue: 'user_completed' },
          updatedAt: { timestampValue: new Date().toISOString() },
        },
      },
      updateMask: {
        fieldPaths: ['status', 'statusReason', 'updatedAt'],
      },
    });
  }

  // Batch commit in chunks of up to 450 writes
  const commitUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`;
  for (let i = 0; i < writes.length; i += 450) {
    const chunk = writes.slice(i, i + 450);
    const commitResp = await fetch(commitUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ writes: chunk }),
    });

    if (!commitResp.ok) {
      const errText = await commitResp.text();
      throw new Error(`Commit failed (${commitResp.status}): ${errText}`);
    }
  }

  console.log(`Successfully committed ${writes.length} updates to Firestore!`);
}

main().catch((err) => {
  console.error('Sanitization failed:', err);
  process.exit(1);
});
