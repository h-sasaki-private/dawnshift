enum SubscriptionPlan { free, premium }

class SubscriptionStatus {
  SubscriptionStatus({
    required this.plan,
    required this.isActive,
    required this.entitlementId,
    required this.syncedAt,
    this.productId,
    this.expirationDate,
  });

  factory SubscriptionStatus.free({DateTime? syncedAt}) => SubscriptionStatus(
    plan: SubscriptionPlan.free,
    isActive: false,
    entitlementId: 'premium',
    syncedAt: syncedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
  );

  factory SubscriptionStatus.premium({
    String entitlementId = 'premium',
    String? productId,
    DateTime? expirationDate,
    DateTime? syncedAt,
  }) => SubscriptionStatus(
    plan: SubscriptionPlan.premium,
    isActive: true,
    entitlementId: entitlementId,
    productId: productId,
    expirationDate: expirationDate,
    syncedAt: syncedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
  );

  final SubscriptionPlan plan;
  final bool isActive;
  final String entitlementId;
  final String? productId;
  final DateTime? expirationDate;
  final DateTime syncedAt;

  bool get isPremium => plan == SubscriptionPlan.premium && isActive;

  Map<String, dynamic> toJson() => {
    'plan': plan.name,
    'is_active': isActive,
    'entitlement_id': entitlementId,
    'product_id': productId,
    'expiration_date': expirationDate?.toIso8601String(),
    'synced_at': syncedAt.toIso8601String(),
  };

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    final planName = json['plan'] as String? ?? 'free';
    return SubscriptionStatus(
      plan: planName == SubscriptionPlan.premium.name
          ? SubscriptionPlan.premium
          : SubscriptionPlan.free,
      isActive: json['is_active'] as bool? ?? false,
      entitlementId: json['entitlement_id'] as String? ?? 'premium',
      productId: json['product_id'] as String?,
      expirationDate: _parseDateTime(json['expiration_date']),
      syncedAt:
          _parseDateTime(json['synced_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value);
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is SubscriptionStatus &&
        other.plan == plan &&
        other.isActive == isActive &&
        other.entitlementId == entitlementId &&
        other.productId == productId &&
        other.expirationDate == expirationDate &&
        other.syncedAt == syncedAt;
  }

  @override
  int get hashCode => Object.hash(
    plan,
    isActive,
    entitlementId,
    productId,
    expirationDate,
    syncedAt,
  );
}
