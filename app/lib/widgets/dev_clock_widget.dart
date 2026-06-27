import 'package:flutter/material.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import '../main.dart';

class DevClockWidget extends StatelessWidget {
  final double bottomOffset;

  const DevClockWidget({super.key, this.bottomOffset = 0.0});

  @override
  Widget build(BuildContext context) {
    if (AppConfig.environment == AppEnvironment.prod) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<DateTime?>(
      valueListenable: AppClock.timeNotifier,
      builder: (context, mockTime, _) {
        if (mockTime == null) {
          return const SizedBox.shrink();
        }

        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomOffset,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade900.withValues(alpha: 0.9),
                  border: const Border(
                    top: BorderSide(color: Colors.orangeAccent, width: 2),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '🚨 Mock Clock: ${mockTime.year}-${mockTime.month.toString().padLeft(2, '0')}-${mockTime.day.toString().padLeft(2, '0')} ${mockTime.hour.toString().padLeft(2, '0')}:${mockTime.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.orange.shade900,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                            ),
                            onPressed: () =>
                                AppClock.advanceTime(const Duration(days: 1)),
                            child: const Text(
                              '+1 Day',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                            ),
                            onPressed: () => AppClock.reset(),
                            child: const Text(
                              'Reset',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
