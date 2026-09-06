import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'secrets.dart';

/// D-070: billing via RevenueCat, ported from Kansei's `revenue_cat_service.dart`.
/// RevenueCat manages the paid tier only (D-057) — trial state never passes
/// through this class. Configured with the Firebase uid via [login] so
/// purchases tie to the same identity `functions/lib/revenuecat_webhook.js`
/// keys entitlement transitions on.
class SubscriptionService {
  static bool _initialized = false;

  static String get _platformProductId =>
      Platform.isIOS ? revenueCatAppleProductId : revenueCatGoogleProductId;

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.error);
      final apiKey =
          Platform.isIOS ? revenueCatApplePublicKey : revenueCatGooglePublicKey;
      await Purchases.configure(PurchasesConfiguration(apiKey));
      _initialized = true;
    } catch (e) {
      debugPrint('SubscriptionService initialization failed: $e');
    }
  }

  static Future<void> login(String uid) async {
    await Purchases.logIn(uid);
  }

  static Future<void> logout() async {
    try {
      await Purchases.logOut();
    } catch (e) {
      debugPrint('SubscriptionService logout failed: $e');
    }
  }

  static Future<CustomerInfo?> syncAndGetCustomerInfo() async {
    try {
      await Purchases.invalidateCustomerInfoCache();
      await Purchases.syncPurchases();
      return await Purchases.getCustomerInfo();
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isEntitled() async {
    final info = await syncAndGetCustomerInfo();
    return info?.entitlements.active.containsKey(revenueCatEntitlementId) ?? false;
  }

  /// Fetches the $29.99/mo product directly by its platform-specific ID
  /// (D-022) — no offerings configuration needed.
  static Future<StoreProduct?> getMonthlyProduct() async {
    final products = await Purchases.getProducts([_platformProductId]);
    return products.firstOrNull;
  }

  /// Throws on hard errors so callers can surface the actual RC error
  /// message; returns null if the user cancelled.
  static Future<CustomerInfo?> purchaseProduct(StoreProduct product) async {
    try {
      final result = await Purchases.purchase(PurchaseParams.storeProduct(product));
      return result.customerInfo;
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) == PurchasesErrorCode.purchaseCancelledError) {
        return null;
      }
      rethrow;
    }
  }

  static Future<CustomerInfo?> restore() async {
    try {
      return await Purchases.restorePurchases();
    } catch (e) {
      debugPrint('SubscriptionService restore error: $e');
      return null;
    }
  }
}
