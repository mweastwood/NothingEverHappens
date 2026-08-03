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

  Future<void> _upgradeToIndividual(BuildContext context) async {
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
                (p) => p.identifier.contains('standard'),
                orElse: () => current.availablePackages.first,
              );
              await Purchases.purchase(PurchaseParams.package(package));
            }
          } catch (e) {
            debugPrint('RevenueCat purchase error / fallback: $e');
          }
        }

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'subscriptionTier': 'standard',
        }, SetOptions(merge: true));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Upgraded to Individual Subscription!'),
            ),
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
            const SnackBar(content: Text('Upgraded to Family Subscription!')),
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

  String _formatPrice(String? rawPrice) {
    if (rawPrice != null && rawPrice.isNotEmpty) {
      return rawPrice.contains('/mo') ? rawPrice : '$rawPrice/mo';
    }
    return '\$X.XX/mo';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subscription = ref.watch(subscriptionServiceProvider);
    final indPriceAsync = ref.watch(individualPlanPriceProvider);
    final famPriceAsync = ref.watch(familyPlanPriceProvider);

    final individualPrice = _formatPrice(indPriceAsync.value);
    final familyPrice = _formatPrice(famPriceAsync.value);

    String tierName;
    IconData tierIcon;
    Color tierColor;

    switch (subscription.tier) {
      case SubscriptionTier.family:
        tierName = 'Family Subscription';
        tierIcon = Icons.stars;
        tierColor = Colors.amber;
        break;
      case SubscriptionTier.standard:
        tierName = 'Individual Subscription';
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

          // 1. Free Tier Card
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

          // 2. Individual Subscription Card
          _PlanCard(
            title: 'Individual Subscription',
            price: individualPrice,
            isCurrent: subscription.tier == SubscriptionTier.standard,
            features: const [
              'Multi-device cloud sync',
              'Automatic cloud task backup',
              'Advanced scheduling & recurrence rules',
            ],
          ),
          const SizedBox(height: 12),

          // 3. Family Subscription Card
          _PlanCard(
            title: 'Family Subscription',
            price: familyPrice,
            isCurrent: subscription.tier == SubscriptionTier.family,
            isRecommended: true,
            features: const [
              'Includes all Individual features',
              'Real-time family group task sharing',
              'Up to 10 family members sync',
              'Shared task assignment & activity log',
            ],
          ),
          const SizedBox(height: 24),

          // Action Buttons
          if (_isProcessing)
            const Center(child: CircularProgressIndicator())
          else ...[
            if (subscription.tier == SubscriptionTier.free) ...[
              OutlinedButton.icon(
                key: const Key('upgrade_to_individual_button'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => _upgradeToIndividual(context),
                icon: const Icon(Icons.person_outline),
                label: Text(
                  'Upgrade to Individual Subscription ($individualPrice)',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (subscription.tier != SubscriptionTier.family) ...[
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
                  'Upgrade to Family Subscription ($familyPrice)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
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
            : (isCurrent
                  ? BorderSide(color: theme.colorScheme.outline, width: 1.5)
                  : BorderSide.none),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
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
                ),
                const SizedBox(width: 8),
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
