import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/task_repository.dart';
import '../logic/subscription_service.dart';
import 'unsynced_details_sheet.dart';

class UnsyncedBanner extends ConsumerStatefulWidget {
  const UnsyncedBanner({super.key});

  @override
  ConsumerState<UnsyncedBanner> createState() => _UnsyncedBannerState();
}

class _UnsyncedBannerState extends ConsumerState<UnsyncedBanner> {
  int _lastCount = 0;
  bool _isVisible = false;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _updateVisibility({
    required bool hasSubscription,
    required bool isCache,
    required int count,
  }) {
    if (!hasSubscription || (count == 0 && !isCache)) {
      _debounceTimer?.cancel();
      _debounceTimer = null;
      if (_isVisible) {
        _isVisible = false;
      }
      return;
    }

    if (_isVisible) {
      _debounceTimer?.cancel();
      _debounceTimer = null;
      return;
    }

    _debounceTimer ??= Timer(const Duration(seconds: 60), () {
      if (mounted) {
        setState(() {
          _isVisible = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final subscription = ref.watch(subscriptionServiceProvider);
    final hasSubscription = subscription.isActivePremium;
    final unsyncedCount = ref.watch(unsyncedCountProvider);
    final isFromCache = ref.watch(isFromCacheProvider);

    _updateVisibility(
      hasSubscription: hasSubscription,
      isCache: isFromCache,
      count: unsyncedCount,
    );

    if (unsyncedCount > 0) {
      _lastCount = unsyncedCount;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? Colors.amber.shade900.withValues(alpha: 0.3)
        : Colors.amber.shade100;
    final borderColor = isDark ? Colors.amber.shade700 : Colors.amber.shade400;
    final textColor = isDark ? Colors.amber.shade200 : Colors.amber.shade900;
    final iconColor = isDark ? Colors.amber.shade300 : Colors.amber.shade800;

    final displayCount = unsyncedCount > 0 ? unsyncedCount : _lastCount;
    final String message;
    if (displayCount > 0) {
      message =
          'Saved locally to device — $displayCount change${displayCount > 1 ? 's' : ''} pending Cloud sync';
    } else {
      message = 'Offline mode — All changes save to local device storage first';
    }

    return ClipRect(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: Curves.fastOutSlowIn,
        alignment: Alignment.topCenter,
        child: _isVisible
            ? AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOutCubic,
                opacity: _isVisible ? 1.0 : 0.0,
                child: Container(
                  key: const Key('unsynced_warning_banner'),
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => UnsyncedDetailsSheet.show(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.cloud_sync_outlined,
                              color: iconColor,
                              size: 18,
                            ),
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
                                  'Tap to inspect pending unsynced changes and sync manually.',
                              child: Icon(
                                Icons.info_outline,
                                color: iconColor,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : const SizedBox(width: double.infinity, height: 0),
      ),
    );
  }
}
