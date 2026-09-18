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
 *   node backend/functions/tool/sanitize_corrupted_tasks.js [--dry-run] [--userId=<userId>]
 */

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function main() {
  const args = process.argv.slice(2);
  const isDryRun = args.includes('--dry-run');
  const userArg = args.find((a) => a.startsWith('--userId='));
  const targetUserId = userArg
    ? userArg.split('=')[1]
    : 'z1NuzlWEHVY27tUgXGNFZMaSPlw1';

  console.log(`--- Firestore Instance Sanitizer ---`);
  console.log(`Mode: ${isDryRun ? 'DRY RUN (no writes)' : 'LIVE UPDATE'}`);
  console.log(`Target User ID: ${targetUserId}`);

  const instancesRef = db
    .collection('users')
    .doc(targetUserId)
    .collection('instances');

  const snapshot = await instancesRef.where('status', '==', 'pending').get();
  console.log(`Found ${snapshot.docs.length} pending instances for user ${targetUserId}`);

  let dismissedToHeal = 0;
  let completedToHeal = 0;
  let batch = db.batch();
  let opsInBatch = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const statusReason = data.statusReason;
    const completedAt = data.completedAt;
    const completedByUserId = data.completedByUserId;
    const scheduledDate = data.scheduledDate;

    let updates = null;

    if (statusReason === 'user_dismissed') {
      updates = {
        status: 'skipped',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      dismissedToHeal++;
      console.log(
        `[HEAL -> SKIPPED] "${data.title}" (id: ${doc.id}, date: ${JSON.stringify(scheduledDate)})`,
      );
    } else if (
      statusReason === 'user_completed' ||
      (completedAt && completedByUserId)
    ) {
      updates = {
        status: 'completed',
        statusReason: 'user_completed',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      completedToHeal++;
      console.log(
        `[HEAL -> COMPLETED] "${data.title}" (id: ${doc.id}, date: ${JSON.stringify(scheduledDate)})`,
      );
    }

    if (updates && !isDryRun) {
      batch.update(doc.ref, updates);
      opsInBatch++;

      if (opsInBatch >= 450) {
        await batch.commit();
        batch = db.batch();
        opsInBatch = 0;
      }
    }
  }

  if (!isDryRun && opsInBatch > 0) {
    await batch.commit();
  }

  console.log(`\nSummary:`);
  console.log(`- Dismissed instances healed to skipped: ${dismissedToHeal}`);
  console.log(`- Completed instances healed to completed: ${completedToHeal}`);
  console.log(`- Total healed: ${dismissedToHeal + completedToHeal}`);
  if (isDryRun) {
    console.log(`\nRun without --dry-run to commit these changes to Firestore.`);
  } else {
    console.log(`\nChanges committed to Firestore.`);
  }
}

main().catch((err) => {
  console.error('Sanitization failed:', err);
  process.exit(1);
});
