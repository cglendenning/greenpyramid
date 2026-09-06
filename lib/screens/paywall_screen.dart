import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../services/entitlement_service.dart';
import '../services/secrets.dart';
import '../services/subscription_service.dart';
import '../theme/app_colors.dart';

/// D-013/D-070: shown only at a value-triggered moment (never a launch or
/// session-start interstitial) — today, that moment is reaching for the
/// Council's re-clarification entry point without an active trial or
/// subscription (D-061/D-016). [reason] names that moment in the header so
/// every presentation is traceable to a specific next step, per D-013's
/// acceptance criteria.
class PaywallScreen extends StatefulWidget {
  final String reason;
  const PaywallScreen({super.key, required this.reason});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  StoreProduct? _product;
  bool _loading = true;
  bool _purchasing = false;
  bool _restoring = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    try {
      final product = await SubscriptionService.getMonthlyProduct();
      if (!mounted) return;
      setState(() {
        _product = product;
        _loading = false;
        if (product == null) {
          _errorMessage = 'Subscription is temporarily unavailable. Please try again later.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Subscription is temporarily unavailable. Please try again later.';
      });
    }
  }

  Future<bool> _confirmActive(CustomerInfo? info) async {
    if (info == null || !info.entitlements.active.containsKey(revenueCatEntitlementId)) {
      return false;
    }
    await EntitlementService.instance.markSubscribedLocally();
    return true;
  }

  Future<void> _onSubscribe() async {
    if (_product == null || _purchasing) return;
    setState(() {
      _purchasing = true;
      _errorMessage = null;
    });
    try {
      final info = await SubscriptionService.purchaseProduct(_product!);
      if (!mounted) return;
      if (await _confirmActive(info)) {
        Navigator.pop(context, true);
        return;
      }
      // Purchase returned but entitlement not yet active locally — force a
      // fresh sync and recheck before giving up.
      final synced = await SubscriptionService.syncAndGetCustomerInfo();
      if (!mounted) return;
      if (await _confirmActive(synced)) {
        Navigator.pop(context, true);
        return;
      }
      setState(() => _purchasing = false);
    } on PlatformException catch (e) {
      if (!mounted) return;
      final synced = await SubscriptionService.syncAndGetCustomerInfo();
      if (!mounted) return;
      if (await _confirmActive(synced)) {
        Navigator.pop(context, true);
        return;
      }
      final code = PurchasesErrorHelper.getErrorCode(e);
      setState(() {
        _purchasing = false;
        _errorMessage = '[${code.name}] ${e.message ?? e.toString()}';
      });
    }
  }

  Future<void> _onRestore() async {
    if (_restoring) return;
    setState(() {
      _restoring = true;
      _errorMessage = null;
    });
    final info = await SubscriptionService.restore();
    if (!mounted) return;
    if (await _confirmActive(info)) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _restoring = false;
      _errorMessage = 'No active subscription found.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final priceString = _product?.priceString ?? '\$29.99';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.reason,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                'A subscription keeps your categories and essences '
                'perpetually clarified — the Council, tailored '
                'notifications, and everything the advisors help you see.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _loading ? '...' : priceString,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 40, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 6),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text('/ month', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    ),
                  ],
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_loading || _purchasing || _product == null) ? null : _onSubscribe,
                  child: _purchasing
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Subscribe'),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _restoring ? null : _onRestore,
                  child: Text(
                    _restoring ? 'Restoring...' : 'Restore purchase',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
              const Center(
                child: Text('Cancel anytime.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
