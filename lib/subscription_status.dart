import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:life_ops/navbar.dart';
import 'package:intl/intl.dart';
import 'package:life_ops/cancel.dart';
import 'package:life_ops/paywall.dart';

class SubscriptionStatus extends StatefulWidget {
  @override
  State<SubscriptionStatus> createState() => _SubscriptionStatusState();
}

class _SubscriptionStatusState extends State<SubscriptionStatus> {
  CustomerInfo? _customerInfo;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSubscriptionStatus();
  }

  Future<void> _fetchSubscriptionStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Purchases.invalidateCustomerInfoCache();
      CustomerInfo info = await Purchases.getCustomerInfo();
      print('[DEBUG] CustomerInfo: ' + info.toString());
      setState(() {
        _customerInfo = info;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to fetch subscription status: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _error == null) {
      final activeSubs = _customerInfo?.activeSubscriptions ?? [];
      final allEntitlements = _customerInfo?.entitlements.active ?? {};
      if (activeSubs.isEmpty && allEntitlements.isEmpty) {
        // Route to paywall after build completes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => Paywall()),
          );
        });
      }
    }
    return SafeArea(
      child: Scaffold(
        appBar: const NavBar(),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                  : _buildStatus(context),
        ),
      ),
    );
  }

  Widget _buildStatus(BuildContext context) {
    final activeSubs = _customerInfo?.activeSubscriptions ?? [];
    final allEntitlements = _customerInfo?.entitlements.active ?? {};
    final allProductIds = _customerInfo?.allPurchasedProductIdentifiers ?? [];
    final latestExpiration = _customerInfo?.latestExpirationDate;

    if (activeSubs.isEmpty && allEntitlements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.info_outline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No active subscription found.', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    // Find the most recent entitlement (if any)
    final entitlement = allEntitlements.isNotEmpty ? allEntitlements.values.first : null;
    if (entitlement != null) {
      // Debug output for entitlement and originalPurchaseDate
      print('[DEBUG] Entitlement: ' + entitlement.toString());
      print('[DEBUG] Entitlement originalPurchaseDate: ' + entitlement.originalPurchaseDate.toString());
    }
    final planId = entitlement?.productIdentifier ?? (activeSubs.isNotEmpty ? activeSubs.first : (allProductIds.isNotEmpty ? allProductIds.last : 'Unknown'));
    final isActive = activeSubs.isNotEmpty;
    final expirationDate = entitlement?.expirationDate ?? latestExpiration;

    DateTime? parsedExpiration = expirationDate != null ? DateTime.tryParse(expirationDate) : null;

    String status = isActive ? 'Active' : 'Cancelled';
    String plan = planId;
    String renewal = parsedExpiration != null ? DateFormat.yMMMMd().add_jm().format(parsedExpiration.toLocal()) : 'Unknown';

    // Use allPurchaseDates[planId] for Last Renewal
    String? planPurchaseDateStr = _customerInfo?.allPurchaseDates[planId];
    DateTime? planPurchaseDate = planPurchaseDateStr != null ? DateTime.tryParse(planPurchaseDateStr) : null;
    String purchased = planPurchaseDate != null ? DateFormat.yMMMMd().add_jm().format(planPurchaseDate.toLocal()) : 'Unknown';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(
              isActive ? Icons.verified : Icons.cancel,
              color: isActive ? Colors.green : Colors.red,
              size: 32,
            ),
            const SizedBox(width: 12),
            Text(
              'Subscription Status',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 32),
        _infoRow('Plan', plan),
        _infoRow('Status', status),
        _infoRow(isActive ? 'Next Renewal' : 'Access Until', renewal),
        _infoRow('Last Renewal', purchased),
        const SizedBox(height: 32),
        Center(
          child: ElevatedButton.icon(
            onPressed: _fetchSubscriptionStatus,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ),
        if (isActive) ...[
          const SizedBox(height: 32),
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.cancel),
              label: const Text('Cancel Subscription'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Cancel()),
                );
                // Refresh status after returning
                _fetchSubscriptionStatus();
              },
            ),
          ),
        ],
        if (!isActive && parsedExpiration != null && parsedExpiration.isAfter(DateTime.now()))
          Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: Text(
              'Your subscription is cancelled but you will have access until $renewal.',
              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
} 