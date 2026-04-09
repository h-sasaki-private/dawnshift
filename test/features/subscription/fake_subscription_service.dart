import 'dart:async';

import 'package:dawnshift/core/models/subscription_status.dart';
import 'package:dawnshift/features/subscription/subscription_service.dart';

class FakeSubscriptionService implements SubscriptionService {
  FakeSubscriptionService({SubscriptionStatus? initialStatus})
    : _currentStatus = initialStatus ?? SubscriptionStatus.free();

  final _controller = StreamController<SubscriptionStatus>.broadcast();
  SubscriptionStatus _currentStatus;
  var purchaseCalls = 0;
  var restoreCalls = 0;
  var refreshCalls = 0;

  @override
  Stream<SubscriptionStatus> get statusChanges => _controller.stream;

  @override
  Future<SubscriptionStatus> getCurrentStatus() async => _currentStatus;

  @override
  Future<SubscriptionStatus> refreshStatus() async {
    refreshCalls += 1;
    return _currentStatus;
  }

  @override
  Future<SubscriptionStatus> purchasePremium() async {
    purchaseCalls += 1;
    return setStatus(SubscriptionStatus.premium());
  }

  @override
  Future<SubscriptionStatus> restorePurchases() async {
    restoreCalls += 1;
    return _currentStatus;
  }

  Future<SubscriptionStatus> setStatus(SubscriptionStatus status) async {
    _currentStatus = status;
    _controller.add(status);
    return status;
  }

  void dispose() {
    _controller.close();
  }
}
