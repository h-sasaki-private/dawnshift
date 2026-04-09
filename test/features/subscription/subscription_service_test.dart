import 'dart:convert';

import 'package:dawnshift/core/models/subscription_status.dart';
import 'package:dawnshift/features/onboarding/onboarding_repository.dart';
import 'package:dawnshift/features/routine/routine_repository.dart';
import 'package:dawnshift/features/subscription/subscription_service.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSharedPreferences implements SharedPreferencesStore {
  final _boolValues = <String, bool>{};
  final _stringValues = <String, String>{};

  @override
  bool? getBool(String key) => _boolValues[key];

  @override
  String? getString(String key) => _stringValues[key];

  @override
  Future<bool> remove(String key) async {
    _boolValues.remove(key);
    _stringValues.remove(key);
    return true;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    _boolValues[key] = value;
    return true;
  }

  @override
  Future<bool> setString(String key, String value) async {
    _stringValues[key] = value;
    return true;
  }
}

class FakeRevenueCatClient implements RevenueCatClient {
  FakeRevenueCatClient({
    this.customerInfo = const RevenueCatCustomerInfo(
      entitlementIsActive: false,
    ),
    this.purchaseResult = const RevenueCatCustomerInfo(
      entitlementIsActive: true,
    ),
    this.restoreResult = const RevenueCatCustomerInfo(
      entitlementIsActive: true,
    ),
  });

  RevenueCatCustomerInfo customerInfo;
  RevenueCatCustomerInfo purchaseResult;
  RevenueCatCustomerInfo restoreResult;
  bool throwOnGetCustomerInfo = false;
  bool configured = false;
  var purchaseCalls = 0;
  var restoreCalls = 0;

  @override
  Future<void> configure({required String apiKey, required String appUserId}) async {
    configured = true;
  }

  @override
  Future<RevenueCatCustomerInfo> getCustomerInfo() async {
    if (throwOnGetCustomerInfo) {
      throw Exception('offline');
    }
    return customerInfo;
  }

  @override
  Future<RevenueCatCustomerInfo> purchasePremium() async {
    purchaseCalls += 1;
    return purchaseResult;
  }

  @override
  Future<RevenueCatCustomerInfo> restorePurchases() async {
    restoreCalls += 1;
    return restoreResult;
  }
}

void main() {
  group('RevenueCatSubscriptionService', () {
    late FakeFirestore firestore;
    late FakeSharedPreferences preferences;
    late FakeRevenueCatClient revenueCatClient;
    late RevenueCatSubscriptionService service;

    setUp(() {
      firestore = FakeFirestore();
      preferences = FakeSharedPreferences();
      revenueCatClient = FakeRevenueCatClient();
      service = RevenueCatSubscriptionService(
        store: firestore,
        preferences: preferences,
        uid: 'user-123',
        apiKey: 'public_test_key',
        revenueCatClient: revenueCatClient,
      );
    });

    test('SDK の状態を取得して Firestore とローカルキャッシュへ同期する', () async {
      revenueCatClient.customerInfo = RevenueCatCustomerInfo(
        entitlementIsActive: true,
        entitlementId: 'premium',
        productIdentifier: 'monthly_premium',
      );

      final status = await service.refreshStatus();
      final remote = await firestore.get(service.collectionPath, service.documentId);

      expect(status.isPremium, isTrue);
      expect(status.plan, SubscriptionPlan.premium);
      expect(remote?['plan'], 'premium');
      expect(remote?['is_active'], isTrue);
      expect(remote?['product_id'], 'monthly_premium');
      expect(
        SubscriptionStatus.fromJson(
          jsonDecode(preferences.getString(service.cacheKey)!) as Map<String, dynamic>,
        ),
        status,
      );
    });

    test('SDK に到達できない場合はキャッシュ済みの状態を返す', () async {
      await preferences.setString(
        service.cacheKey,
        jsonEncode(SubscriptionStatus.premium().toJson()),
      );
      revenueCatClient.throwOnGetCustomerInfo = true;

      final status = await service.getCurrentStatus();

      expect(status.isPremium, isTrue);
      expect(status.plan, SubscriptionPlan.premium);
    });

    test('購入フロー完了後にプレミアム状態へ更新する', () async {
      revenueCatClient.purchaseResult = RevenueCatCustomerInfo(
        entitlementIsActive: true,
        entitlementId: 'premium',
        productIdentifier: 'annual_premium',
      );

      final status = await service.purchasePremium();

      expect(revenueCatClient.purchaseCalls, 1);
      expect(status.isPremium, isTrue);
      expect(status.productId, 'annual_premium');
    });
  });
}
