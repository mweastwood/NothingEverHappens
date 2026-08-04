import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/task_repository.dart';

import '../logic/subscription_service.dart';

class UnsyncedBanner extends ConsumerWidget {
  const UnsyncedBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionServiceProvider);
    if (!subscription.isActivePremium) {
      return const SizedBox.shrink();
    }

    final unsyncedCount = ref.watch(unsyncedCountProvider);
    final isFromCache = ref.watch(isFromCacheProvider);

    if (unsyncedCount == 0 && !isFromCache) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? Colors.amber.shade900.withValues(alpha: 0.3)
        : Colors.amber.shade100;
    final borderColor = isDark ? Colors.amber.shade700 : Colors.amber.shade400;
    final textColor = isDark ? Colors.amber.shade200 : Colors.amber.shade900;
    final iconColor = isDark ? Colors.amber.shade300 : Colors.amber.shade800;

    final String message;
    if (unsyncedCount > 0) {
      message =
          'Saved locally to device — $unsyncedCount change${unsyncedCount > 1 ? 's' : ''} pending Cloud sync';
    } else {
      message = 'Offline mode — All changes save to local device storage first';
    }

    return Container(
      key: const Key('unsynced_warning_banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_sync_outlined, color: iconColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Tooltip(
            message:
                'Your data is saved safely on your device in local Firebase Firestore cache and will automatically sync when connected.',
            child: Icon(Icons.info_outline, color: iconColor, size: 16),
          ),
        ],
      ),
    );
  }
}
