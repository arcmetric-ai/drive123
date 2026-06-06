class InstructorBillingPlan {
  const InstructorBillingPlan({
    required this.planKey,
    required this.displayName,
    this.description,
    required this.amountCents,
    required this.currency,
    required this.billingInterval,
    required this.accessDays,
    required this.featureCodes,
  });

  factory InstructorBillingPlan.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['feature_codes'];
    return InstructorBillingPlan(
      planKey: json['plan_key'] as String? ?? '',
      displayName: json['display_name'] as String? ?? 'Pass',
      description: json['description'] as String?,
      amountCents: (json['amount_cents'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'cad',
      billingInterval: json['billing_interval'] as String? ?? 'day',
      accessDays: (json['access_days'] as num?)?.toInt() ?? 1,
      featureCodes: rawFeatures is List
          ? rawFeatures.whereType<String>().toList(growable: false)
          : const <String>[],
    );
  }

  final String planKey;
  final String displayName;
  final String? description;
  final int amountCents;
  final String currency;
  final String billingInterval;
  final int accessDays;
  final List<String> featureCodes;

  String get priceLabel {
    final dollars = amountCents / 100;
    final whole = dollars == dollars.roundToDouble();
    final amount =
        whole ? dollars.toStringAsFixed(0) : dollars.toStringAsFixed(2);
    final normalizedCurrency = currency.trim().toUpperCase();
    if (normalizedCurrency == 'CAD') return 'CA\$$amount';
    if (normalizedCurrency == 'USD') return 'US\$$amount';
    return '$normalizedCurrency $amount';
  }

  String get intervalLabel {
    switch (billingInterval) {
      case 'month':
        return 'Monthly';
      case 'year':
        return 'Yearly';
      default:
        return 'Day';
    }
  }
}

class InstructorBillingEntitlement {
  const InstructorBillingEntitlement({
    required this.planKey,
    required this.status,
    this.accessExpiresAt,
    this.cancelAtPeriodEnd = false,
  });

  factory InstructorBillingEntitlement.fromJson(Map<String, dynamic> json) {
    final expiresRaw = json['access_expires_at'] as String?;
    return InstructorBillingEntitlement(
      planKey: json['plan_key'] as String? ?? '',
      status: json['status'] as String? ?? 'expired',
      accessExpiresAt:
          expiresRaw == null ? null : DateTime.tryParse(expiresRaw),
      cancelAtPeriodEnd: json['cancel_at_period_end'] == true,
    );
  }

  final String planKey;
  final String status;
  final DateTime? accessExpiresAt;
  final bool cancelAtPeriodEnd;

  bool get isActive {
    final expiry = accessExpiresAt;
    return (status == 'active' || status == 'trialing') &&
        expiry != null &&
        expiry.isAfter(DateTime.now().toUtc());
  }
}
