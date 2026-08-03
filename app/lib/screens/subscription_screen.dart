import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../logic/subscription_service.dart';
import '../logic/auth_repository.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isProcessing = false;

  Future<void> _upgradeToFamily(BuildContext context) async {
    setState(() {
      _isProcessing = true;
    });
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final user = authRepo.currentUser;
      if (user != null) {
        if (!kIsWeb) {
          try {
            final offerings = await Purchases.getOfferings();
            final current = offerings.current;
            if (current != null && current.availablePackages.isNotEmpty) {
              final package = current.availablePackages.firstWhere(
                (p) => p.identifier.contains('family'),
                orElse: () => current.availablePackages.first,
              );
              await Purchases.purchase(PurchaseParams.package(package));
            }
          } catch (e) {
            debugPrint('RevenueCat purchase error / fallback: $e');
          }
        }

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'subscriptionTier': 'family',
        }, SetOptions(merge: true));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Upgraded to Family Plan!')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error purchasing: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _restorePurchases(BuildContext context) async {
    try {
      if (!kIsWeb) {
        await Purchases.restorePurchases();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchases restored successfully.')),
        );
      }
    } catch (e) {
      debugPrint('Error restoring purchases: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subscription = ref.watch(subscriptionServiceProvider);
    final priceAsync = ref.watch(familyPlanPriceProvider);
    final priceString = priceAsync.value ?? '\$1.00';

    String tierName;
    IconData tierIcon;
    Color tierColor;

    switch (subscription.tier) {
      case SubscriptionTier.family:
        tierName = 'Family Plan';
        tierIcon = Icons.stars;
        tierColor = Colors.amber;
        break;
      case SubscriptionTier.standard:
        tierName = 'Standard Plan';
        tierIcon = Icons.star;
        tierColor = theme.colorScheme.primary;
        break;
      case SubscriptionTier.free:
        tierName = 'Free Tier';
        tierIcon = Icons.star_border;
        tierColor = theme.colorScheme.outline;
        break;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Subscriptions')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Current Subscription Status Card
          Card(
            margin: EdgeInsets.zero,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: tierColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(tierIcon, color: tierColor, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Tier',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tierName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(
                      subscription.isActivePremium ? 'Active' : 'Free',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: subscription.isActivePremium
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    backgroundColor: subscription.isActivePremium
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Available Plans',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Free Tier Card
          _PlanCard(
            title: 'Free Tier',
            price: 'Free',
            isCurrent: subscription.tier == SubscriptionTier.free,
            features: const [
              'Unlimited local task creation',
              'Basic schedule recurrence rules',
              'Capacity tracking & settings',
            ],
          ),
          const SizedBox(height: 12),

          // Family Plan Card
          _PlanCard(
            title: 'Family Plan',
            price: '$priceString/mo',
            isCurrent: subscription.tier == SubscriptionTier.family,
            isRecommended: true,
            features: const [
              'Real-time family group task sharing',
              'Up to 10 family members sync',
              'Shared task assignment & activity log',
              'Cloud backup & multi-device sync',
            ],
          ),
          const SizedBox(height: 32),

          // Upgrade Button
          if (subscription.tier != SubscriptionTier.family) ...[
            if (_isProcessing)
              const Center(child: CircularProgressIndicator())
            else
              FilledButton.icon(
                key: const Key('subscription_screen_upgrade_button'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => _upgradeToFamily(context),
                icon: const Icon(Icons.star_outline),
                label: Text(
                  'Upgrade to Family Plan ($priceString/mo)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],

          TextButton(
            onPressed: () => _restorePurchases(context),
            child: const Text('Restore Purchases'),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final bool isCurrent;
  final bool isRecommended;
  final List<String> features;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.isCurrent,
    this.isRecommended = false,
    required this.features,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: isRecommended ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: isRecommended
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isRecommended) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'RECOMMENDED',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  price,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
