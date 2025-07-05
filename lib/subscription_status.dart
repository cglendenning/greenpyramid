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

class _SubscriptionStatusState extends State<SubscriptionStatus> with TickerProviderStateMixin {
  CustomerInfo? _customerInfo;
  bool _loading = true;
  String? _error;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize pulse animation for the resubscribe button
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _fetchSubscriptionStatus();
  }

  Future<void> _fetchSubscriptionStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Purchases.invalidateCustomerInfoCache();
      
      // Force a sync with the store to get the latest subscription status
      print('[DEBUG] Forcing sync with store...');
      await Purchases.syncPurchases();
      
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

    // Use allPurchaseDates[planId] for Last Renewal with fallback for Android
    // NOTE: For accurate purchase dates on Android, set up Google Real-Time Developer Notifications
    // in RevenueCat dashboard: https://www.revenuecat.com/docs/platform-resources/server-notifications
    String? planPurchaseDateStr = _customerInfo?.allPurchaseDates[planId];
    DateTime? planPurchaseDate = planPurchaseDateStr != null ? DateTime.tryParse(planPurchaseDateStr) : null;
    
    // Fallback for Android: try to get purchase date from entitlement
    if (planPurchaseDate == null && entitlement != null) {
      try {
        // Use entitlement's latestPurchaseDate as primary fallback (most accurate)
        if (entitlement.latestPurchaseDate != null) {
          planPurchaseDate = DateTime.tryParse(entitlement.latestPurchaseDate!);
          print('[DEBUG] - Using entitlement latestPurchaseDate as fallback: $planPurchaseDate');
        } else {
          // Use entitlement's originalPurchaseDate as secondary fallback
          planPurchaseDate = DateTime.tryParse(entitlement.originalPurchaseDate);
          print('[DEBUG] - Using entitlement originalPurchaseDate as fallback: $planPurchaseDate');
        }
      } catch (e) {
        print('[DEBUG] - Error parsing entitlement purchase dates: $e');
      }
    }
    
    // Additional fallback: try to get from latest expiration date minus subscription period
    if (planPurchaseDate == null && parsedExpiration != null) {
      try {
        // For monthly subscriptions, subtract 1 month from expiration
        // This is a rough estimate but better than "Unknown"
        final estimatedPurchaseDate = parsedExpiration.subtract(const Duration(days: 30));
        if (estimatedPurchaseDate.isBefore(DateTime.now())) {
          planPurchaseDate = estimatedPurchaseDate;
          print('[DEBUG] - Using estimated purchase date (expiration - 30 days): $planPurchaseDate');
        }
      } catch (e) {
        print('[DEBUG] - Error calculating estimated purchase date: $e');
      }
    }
    
    String purchased = planPurchaseDate != null ? DateFormat.yMMMMd().add_jm().format(planPurchaseDate.toLocal()) : 'Unknown';

    // Check if subscription is cancelled but not expired yet
    bool isCancelledButNotExpired = false;
    
    // Debug logging to help understand the subscription state
    print('[DEBUG] Subscription Status Debug:');
    print('[DEBUG] - isActive: $isActive');
    print('[DEBUG] - activeSubs: $activeSubs');
    print('[DEBUG] - allEntitlements: ${allEntitlements.keys}');
    print('[DEBUG] - allProductIds: $allProductIds');
    print('[DEBUG] - parsedExpiration: $parsedExpiration');
    
    // Let's explore more CustomerInfo properties to find cancellation status
    print('[DEBUG] - CustomerInfo toString: ${_customerInfo.toString()}');
    print('[DEBUG] - All entitlements (including inactive): ${_customerInfo?.entitlements.all.keys}');
    print('[DEBUG] - Latest expiration date: ${_customerInfo?.latestExpirationDate}');
    print('[DEBUG] - All purchase dates: ${_customerInfo?.allPurchaseDates}');
    print('[DEBUG] - Non subscription transactions: ${_customerInfo?.nonSubscriptionTransactions}');
    print('[DEBUG] - Plan ID for purchase date lookup: $planId');
    print('[DEBUG] - Purchase date from allPurchaseDates: $planPurchaseDateStr');
    print('[DEBUG] - Parsed purchase date: $planPurchaseDate');
    
    // Try to access unsubscribeAt field if available in CustomerInfo
    try {
      // Check if CustomerInfo has an unsubscribeAt field
      final customerInfoString = _customerInfo.toString();
      print('[DEBUG] - CustomerInfo full string: $customerInfoString');
      
      // Look for unsubscribeAt in the string representation
      if (customerInfoString.contains('unsubscribeAt')) {
        print('[DEBUG] - Found unsubscribeAt in CustomerInfo!');
      }
    } catch (e) {
      print('[DEBUG] - Error checking CustomerInfo for unsubscribeAt: $e');
    }
    
    // Check if there are any inactive entitlements that might indicate cancelled subscriptions
    final allEntitlementsMap = _customerInfo?.entitlements.all ?? {};
    print('[DEBUG] - All entitlements map: $allEntitlementsMap');
    
    // Look for any entitlement that has a future expiration but is not active
    // Also check for unsubscribeAt field if available
    for (final entry in allEntitlementsMap.entries) {
      final entitlement = entry.value;
      print('[DEBUG] - Entitlement ${entry.key}: ${entitlement.toString()}');
      print('[DEBUG] -   - isActive: ${entitlement.isActive}');
      print('[DEBUG] -   - expirationDate: ${entitlement.expirationDate}');
      print('[DEBUG] -   - willRenew: ${entitlement.willRenew}');
      print('[DEBUG] -   - latestPurchaseDate: ${entitlement.latestPurchaseDate}');
      print('[DEBUG] -   - originalPurchaseDate: ${entitlement.originalPurchaseDate}');
      
      // Try to access unsubscribeAt field (might be available in newer RevenueCat versions)
      try {
        // Use reflection or dynamic access to check for unsubscribeAt
        final entitlementMap = entitlement.toString();
        print('[DEBUG] -   - Full entitlement data: $entitlementMap');
        
                 // Check if willRenew is false and we have a future expiration
         if (entitlement.willRenew == false && entitlement.expirationDate != null) {
           final expDate = DateTime.tryParse(entitlement.expirationDate!);
           if (expDate != null && expDate.isAfter(DateTime.now())) {
             print('[DEBUG] -   - FOUND CANCELLED BUT NOT EXPIRED! (willRenew = false)');
             isCancelledButNotExpired = true;
             break;
           }
         }
         
         // Additional check: if we have active subscriptions but the entitlement shows as inactive
         // This might indicate a cancelled subscription that hasn't been synced yet
         if (activeSubs.isNotEmpty && !entitlement.isActive && entitlement.expirationDate != null) {
           final expDate = DateTime.tryParse(entitlement.expirationDate!);
           if (expDate != null && expDate.isAfter(DateTime.now())) {
             print('[DEBUG] -   - FOUND CANCELLED BUT NOT EXPIRED! (active subs but inactive entitlement)');
             isCancelledButNotExpired = true;
             break;
           }
         }
        
        // Also check the old logic as fallback
        if (!entitlement.isActive && entitlement.expirationDate != null) {
          final expDate = DateTime.tryParse(entitlement.expirationDate!);
          if (expDate != null && expDate.isAfter(DateTime.now())) {
            print('[DEBUG] -   - FOUND CANCELLED BUT NOT EXPIRED! (inactive entitlement)');
            isCancelledButNotExpired = true;
            break;
          }
        }
      } catch (e) {
        print('[DEBUG] -   - Error accessing entitlement properties: $e');
      }
    }
    
    // Fallback to original logic if no entitlements found
    if (!isCancelledButNotExpired) {
      isCancelledButNotExpired = !isActive && parsedExpiration != null && parsedExpiration.isAfter(DateTime.now());
    }
    
    print('[DEBUG] - Final isCancelledButNotExpired: $isCancelledButNotExpired');

    // Start pulse animation if subscription is cancelled but not expired
    if (isCancelledButNotExpired && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!isCancelledButNotExpired && _pulseController.isAnimating) {
      _pulseController.stop();
    }

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
        _infoRow(isCancelledButNotExpired ? 'Expires On' : (isActive ? 'Next Renewal' : 'Access Until'), renewal),
        _infoRow('Last Renewal', purchased),
        const SizedBox(height: 32),
        Center(
          child: ElevatedButton.icon(
            onPressed: _fetchSubscriptionStatus,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ),
        if (isActive && !isCancelledButNotExpired) ...[
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
        if (isCancelledButNotExpired)
          Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: Column(
              children: [
                // Humorous message about the cancellation
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.withOpacity(0.1),
                        Colors.red.withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.sentiment_dissatisfied, color: Colors.orange, size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Oh no! You\'re leaving us? 😢',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your subscription is cancelled but you\'ll have access until $renewal. We\'ll miss you! 💔',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Resubscribe button with humor and pulse animation
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            // Navigate to paywall to resubscribe
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => Paywall()),
                            );
                            // Refresh status after returning
                            _fetchSubscriptionStatus();
                            
                            // Show celebration if user resubscribed
                            if (result == true) {
                              _showResubscriptionCelebration();
                            }
                          },
                          icon: const Icon(Icons.favorite, color: Colors.white),
                          label: const Text(
                            'Actually, I\'ll Stay! 💚',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff66cc5d),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 12),
                
                // Small print about uncancelling
                const Text(
                  'Tap above to resubscribe and continue your journey!',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
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

  void _showResubscriptionCelebration() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.celebration,
                size: 64,
                color: Color(0xff66cc5d),
              ),
              const SizedBox(height: 16),
              const Text(
                'Welcome Back! 🎉',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff66cc5d),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'We\'re so glad you decided to stay! Your subscription is now active again.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Awesome! 💚',
                style: TextStyle(
                  color: Color(0xff66cc5d),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
} 