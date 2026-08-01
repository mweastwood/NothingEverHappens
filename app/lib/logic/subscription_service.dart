import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_repository.dart';
import 'task_repository.dart';

enum SubscriptionTier { free, standard, family }

class SubscriptionState {
  final SubscriptionTier tier;

  const SubscriptionState({required this.tier});

  bool get isActivePremium => tier != SubscriptionTier.free;
  bool get isFamilyPlan => tier == SubscriptionTier.family;

  SubscriptionState copyWith({SubscriptionTier? tier}) {
    return SubscriptionState(tier: tier ?? this.tier);
  }
}

class SubscriptionService extends StateNotifier<SubscriptionState> {
  final Ref _ref;
  final FirebaseFirestore? _firestore;
  StreamSubscription<DocumentSnapshot>? _firestoreSub;
  bool _initialized = false;

  SubscriptionService(this._ref, {FirebaseFirestore? firestore})
    : _firestore = firestore ?? _safeGetFirestore(),
      super(const SubscriptionState(tier: SubscriptionTier.free)) {
    _init();
  }

  static FirebaseFirestore? _safeGetFirestore() {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  static const String _revenueCatApiKey = String.fromEnvironment(
    'REVENUECAT_API_KEY',
    defaultValue: 'goog_mock_api_key',
  );

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;

    // Configure RevenueCat SDK on Android/iOS
    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (!kIsWeb && !isTest) {
      try {
        await Purchases.setLogLevel(LogLevel.debug);
        await Purchases.configure(PurchasesConfiguration(_revenueCatApiKey));
      } catch (e) {
        debugPrint("RevenueCat configuration error: $e");
      }

      // Listen for customer info updates
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _updateEntitlements(customerInfo);
      });
    }

    // Listen to Auth changes to configure/identify user
    if (isTest) return;

    _ref.listen<AsyncValue<dynamic>>(authStateProvider, (previous, next) async {
      final user = next.value;
      if (user != null) {
        await _identifyUser(user.uid);
      } else {
        await _resetUser();
      }
    });

    final currentUser = _ref.read(authRepositoryProvider).currentUser;
    if (currentUser != null) {
      await _identifyUser(currentUser.uid);
    }
  }

  Future<void> _identifyUser(String uid) async {
    if (kIsWeb) {
      // Web listens to Firestore document updates (written by webhook)
      listenToUserSubscriptionInFirestore(uid);
      return;
    }

    try {
      final result = await Purchases.logIn(uid);
      _updateEntitlements(result.customerInfo);
    } catch (e) {
      debugPrint("RevenueCat login error: $e");
    }
  }

  void _setSubscriptionState(SubscriptionState newState) {
    if (state.tier != newState.tier || !state.isActivePremium) {
      state = newState;
      _updateFirestoreNetworkState(newState.tier);
    }
  }

  void _updateFirestoreNetworkState(SubscriptionTier tier) {
    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest || _firestore == null) return;

    if (tier == SubscriptionTier.free) {
      _firestore.disableNetwork().catchError((e) {
        debugPrint("Error disabling Firestore network: $e");
      });
    } else {
      _firestore.enableNetwork().catchError((e) {
        debugPrint("Error enabling Firestore network: $e");
      });
    }
  }

  Future<void> _resetUser() async {
    _firestoreSub?.cancel();
    if (!kIsWeb) {
      try {
        await Purchases.logOut();
      } catch (_) {}
    }
    _setSubscriptionState(const SubscriptionState(tier: SubscriptionTier.free));
  }

  void _updateEntitlements(CustomerInfo info) {
    SubscriptionTier detectedTier = SubscriptionTier.free;

    final standardActive = info.entitlements.all['standard']?.isActive ?? false;
    final familyActive = info.entitlements.all['family']?.isActive ?? false;

    if (familyActive) {
      detectedTier = SubscriptionTier.family;
    } else if (standardActive) {
      detectedTier = SubscriptionTier.standard;
    }

    _setSubscriptionState(SubscriptionState(tier: detectedTier));
    _syncTierToFirestore(detectedTier);
  }

  void listenToUserSubscriptionInFirestore(String uid) {
    if (_firestore == null) return;
    _firestoreSub?.cancel();
    _firestoreSub = _firestore.collection('users').doc(uid).snapshots().listen((
      doc,
    ) {
      if (doc.exists) {
        final data = doc.data();
        final tierStr = data?['subscriptionTier'] as String?;
        SubscriptionTier detectedTier = SubscriptionTier.free;
        if (tierStr == 'family') {
          detectedTier = SubscriptionTier.family;
        } else if (tierStr == 'standard') {
          detectedTier = SubscriptionTier.standard;
        }
        _setSubscriptionState(SubscriptionState(tier: detectedTier));
      } else {
        _setSubscriptionState(
          const SubscriptionState(tier: SubscriptionTier.free),
        );
      }
    });
  }

  Future<void> _syncTierToFirestore(SubscriptionTier tier) async {
    if (_firestore == null) return;
    final user = _ref.read(authRepositoryProvider).currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'subscriptionTier': tier.name,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint("Error syncing subscription tier to Firestore: $e");
      }
    }
  }

  @override
  void dispose() {
    _firestoreSub?.cancel();
    super.dispose();
  }
}

final subscriptionServiceProvider =
    StateNotifierProvider<SubscriptionService, SubscriptionState>((ref) {
      final firestore = ref.watch(firestoreProvider);
      return SubscriptionService(ref, firestore: firestore);
    });
