import 'dart:async';
import 'dart:convert';

import 'package:dawnshift/core/models/subscription_status.dart';
import 'package:dawnshift/features/onboarding/onboarding_repository.dart';
import 'package:dawnshift/features/sleep/sleep_record_repository.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as purchases;

abstract class SubscriptionService {
  Stream<SubscriptionStatus> get statusChanges;
  Future<SubscriptionStatus> getCurrentStatus();
  Future<SubscriptionStatus> refreshStatus();
  Future<SubscriptionStatus> purchasePremium();
  Future<SubscriptionStatus> restorePurchases();
}

class RevenueCatCustomerInfo {
  const RevenueCatCustomerInfo({
    required this.entitlementIsActive,
    this.entitlementId = 'premium',
    this.productIdentifier,
    this.expirationDate,
  });

  final bool entitlementIsActive;
  final String entitlementId;
  final String? productIdentifier;
  final DateTime? expirationDate;
}

abstract class RevenueCatClient {
  Future<void> configure({required String apiKey, required String appUserId});
  Future<RevenueCatCustomerInfo> getCustomerInfo();
  Future<RevenueCatCustomerInfo> purchasePremium();
  Future<RevenueCatCustomerInfo> restorePurchases();
}

class PurchasesRevenueCatClient implements RevenueCatClient {
  PurchasesRevenueCatClient({this.entitlementId = 'premium'});

  final String entitlementId;

  @override
  Future<void> configure({required String apiKey, required String appUserId}) async {
    if (apiKey.isEmpty) {
      return;
    }

    final configuration = purchases.PurchasesConfiguration(apiKey)
      ..appUserID = appUserId;
    await purchases.Purchases.configure(configuration);
  }

  @override
  Future<RevenueCatCustomerInfo> getCustomerInfo() async {
    final customerInfo = await purchases.Purchases.getCustomerInfo();
    return _mapCustomerInfo(customerInfo);
  }

  @override
  Future<RevenueCatCustomerInfo> purchasePremium() async {
    final offerings = await purchases.Purchases.getOfferings();
    final package = offerings.current?.availablePackages.firstOrNull;
    if (package == null) {
      throw StateError('RevenueCat の offering が見つかりません。');
    }

    final result = await purchases.Purchases.purchasePackage(package);
    return _mapCustomerInfo(result.customerInfo);
  }

  @override
  Future<RevenueCatCustomerInfo> restorePurchases() async {
    final customerInfo = await purchases.Purchases.restorePurchases();
    return _mapCustomerInfo(customerInfo);
  }

  RevenueCatCustomerInfo _mapCustomerInfo(purchases.CustomerInfo customerInfo) {
    final entitlement = customerInfo.entitlements.all[entitlementId];
    return RevenueCatCustomerInfo(
      entitlementIsActive: entitlement?.isActive == true,
      entitlementId: entitlement?.identifier ?? entitlementId,
      productIdentifier:
          entitlement?.productIdentifier ??
          customerInfo.activeSubscriptions.firstOrNull,
      expirationDate: _parseRevenueCatDate(entitlement?.expirationDate),
    );
  }

  DateTime? _parseRevenueCatDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.parse(value);
  }
}

class RevenueCatSubscriptionService implements SubscriptionService {
  RevenueCatSubscriptionService({
    required FirestoreInterface store,
    required SharedPreferencesStore preferences,
    required String uid,
    required String apiKey,
    RevenueCatClient? revenueCatClient,
    this.entitlementId = 'premium',
  }) : _store = store,
       _preferences = preferences,
       _uid = uid,
       _apiKey = apiKey,
       _revenueCatClient =
           revenueCatClient ??
           PurchasesRevenueCatClient(entitlementId: entitlementId);

  final FirestoreInterface _store;
  final SharedPreferencesStore _preferences;
  final String _uid;
  final String _apiKey;
  final String entitlementId;
  final RevenueCatClient _revenueCatClient;
  final _controller = StreamController<SubscriptionStatus>.broadcast();
  bool _configured = false;

  String get collectionPath => 'users/$_uid/subscription';
  String get documentId => 'status';
  String get cacheKey => 'subscription_status_$_uid';

  @override
  Stream<SubscriptionStatus> get statusChanges => _controller.stream;

  @override
  Future<SubscriptionStatus> getCurrentStatus() async {
    final cached = _readCachedStatus();
    if (cached != null) {
      return cached;
    }

    return refreshStatus();
  }

  @override
  Future<SubscriptionStatus> refreshStatus() async {
    try {
      await _ensureConfigured();
      final info = await _revenueCatClient.getCustomerInfo();
      return _persist(_mapInfo(info));
    } catch (_) {
      return _loadFallbackStatus();
    }
  }

  @override
  Future<SubscriptionStatus> purchasePremium() async {
    await _ensureConfigured();
    final info = await _revenueCatClient.purchasePremium();
    return _persist(_mapInfo(info));
  }

  @override
  Future<SubscriptionStatus> restorePurchases() async {
    await _ensureConfigured();
    final info = await _revenueCatClient.restorePurchases();
    return _persist(_mapInfo(info));
  }

  Future<void> _ensureConfigured() async {
    if (_configured || _apiKey.isEmpty) {
      _configured = true;
      return;
    }

    await _revenueCatClient.configure(apiKey: _apiKey, appUserId: _uid);
    _configured = true;
  }

  SubscriptionStatus _mapInfo(RevenueCatCustomerInfo info) {
    final now = DateTime.now();
    if (info.entitlementIsActive) {
      return SubscriptionStatus.premium(
        entitlementId: info.entitlementId,
        productId: info.productIdentifier,
        expirationDate: info.expirationDate,
        syncedAt: now,
      );
    }

    return SubscriptionStatus.free(syncedAt: now);
  }

  Future<SubscriptionStatus> _persist(SubscriptionStatus status) async {
    await _preferences.setString(cacheKey, jsonEncode(status.toJson()));
    try {
      await _store.set(collectionPath, documentId, status.toJson());
    } catch (_) {
      // Firestore SDK 側のオフラインキューに任せる前提のため、UI は継続させる。
    }
    _controller.add(status);
    return status;
  }

  SubscriptionStatus? _readCachedStatus() {
    final cached = _preferences.getString(cacheKey);
    if (cached == null) {
      return null;
    }

    return SubscriptionStatus.fromJson(
      jsonDecode(cached) as Map<String, dynamic>,
    );
  }

  Future<SubscriptionStatus> _loadFallbackStatus() async {
    final cached = _readCachedStatus();
    if (cached != null) {
      return cached;
    }

    final remote = await _store.get(collectionPath, documentId);
    if (remote != null) {
      final status = SubscriptionStatus.fromJson(remote);
      await _preferences.setString(cacheKey, jsonEncode(status.toJson()));
      return status;
    }

    return SubscriptionStatus.free();
  }
}
