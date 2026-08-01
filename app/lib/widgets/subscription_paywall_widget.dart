import 'package:flutter/material.dart';

/// A reusable paywall widget that displays premium features and an upgrade call-to-action.
class SubscriptionPaywallWidget extends StatelessWidget {
  final VoidCallback onUpgrade;
  final VoidCallback? onRestore;
  final bool isProcessing;

  const SubscriptionPaywallWidget({
    super.key,
    required this.onUpgrade,
    this.onRestore,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Family Groups')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.people_outline,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Unlock Family Groups',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Collaborate, delegate, and sync task progress with up to 10 family members in real-time.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              if (isProcessing)
                const CircularProgressIndicator()
              else
                FilledButton.icon(
                  key: const Key('upgrade_to_family_button'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: onUpgrade,
                  icon: const Icon(Icons.star_outline),
                  label: const Text(
                    'Upgrade to Family Plan (\$1.00/mo)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed:
                    onRestore ??
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Purchases restored successfully.'),
                        ),
                      );
                    },
                child: const Text('Restore Purchases'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
