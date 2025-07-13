import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:life_ops/navbar.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'dart:io';

class Cancel extends StatefulWidget {
  @override
  _CancelState createState() => _CancelState();
}

class _CancelState extends State<Cancel> with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late AnimationController _pulseController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _pulseAnimation;
  bool _isCancelling = false;
  bool _showFinalWarning = false;

  @override
  void initState() {
    super.initState();

    // Shake animation for the "please don't go" effect
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );

    // Pulse animation for the heart
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start pulsing
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _shakeTheScreen() {
    _shakeController.forward().then((_) {
      _shakeController.reverse();
    });
  }

  Future<void> _cancelSubscription() async {
    setState(() {
      _isCancelling = true;
    });

    try {
      // Get customer info first
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();

      if (customerInfo.activeSubscriptions.isEmpty) {
        _showDialog('No Active Subscription',
            'You don\'t have an active subscription to cancel.');
        setState(() {
          _isCancelling = false;
        });
        return;
      }

      // Show final warning
      setState(() {
        _showFinalWarning = true;
      });

      // Wait a moment for dramatic effect
      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        _isCancelling = false;
        _showFinalWarning = false;
      });

      // Show instructions for cancelling through the store
      _showCancelInstructions();
    } catch (e) {
      setState(() {
        _isCancelling = false;
        _showFinalWarning = false;
      });
      _showDialog(
          'Error', 'An error occurred while checking your subscription: $e');
    }
  }

  void _showCancelInstructions() {
    String instructions = '';

    if (Platform.isIOS) {
      instructions = 'To cancel your subscription:\n\n'
          '1. Open Settings on your iPhone\n'
          '2. Tap your Apple ID at the top\n'
          '3. Tap "Subscriptions"\n'
          '4. Find "Green Pyramid" and tap it\n'
          '5. Tap "Cancel Subscription"\n\n'
          'You\'ll continue to have access until the end of your current billing period.';
    } else {
      instructions = 'To cancel your subscription:\n\n'
          '1. Open Google Play Store\n'
          '2. Tap your profile icon\n'
          '3. Tap "Payments & subscriptions"\n'
          '4. Tap "Subscriptions"\n'
          '5. Find "Green Pyramid" and tap it\n'
          '6. Tap "Cancel subscription"\n\n'
          'You\'ll continue to have access until the end of your current billing period.';
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Subscription'),
          content: SingleChildScrollView(
            child: Text(instructions),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  void _showDialog(String title, String message, {bool isSuccess = false}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (isSuccess) {
                  Navigator.of(context).pop(); // Go back to previous screen
                }
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    FirebaseAnalytics analytics = FirebaseAnalytics.instance;
    analytics.logEvent(name: 'cancel_subscription_screen');

    return SafeArea(
      child: Scaffold(
        appBar: const NavBar(),
        body: AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_shakeAnimation.value, 0),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 40),

                    // Humorous header
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.red.withOpacity(0.1),
                            Colors.orange.withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          // Animated heart
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: const Icon(
                                  Icons.favorite,
                                  size: 64,
                                  color: Colors.red,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Wait! Don\'t Leave! 😢',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Your AI coach is getting emotional...',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Humorous reasons to stay
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'But... but... but... 😭',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildReasonItem(
                              '🤖', 'Your AI coach will miss you terribly'),
                          _buildReasonItem(
                              '📊', 'All that progress data will go to waste'),
                          _buildReasonItem(
                              '💪', 'Who will motivate you at 3 AM?'),
                          _buildReasonItem(
                              '🧠', 'The Green Pyramid methodology needs you'),
                          _buildReasonItem('🎯',
                              'Your goals are so close to being achieved'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Final warning when cancelling
                    if (_showFinalWarning)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.warning,
                              color: Colors.red,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Last Chance! 🚨',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Are you absolutely sure? Your AI coach is literally crying right now...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 32),

                    // Cancel button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isCancelling
                            ? null
                            : () {
                                _shakeTheScreen();
                                _cancelSubscription();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        child: _isCancelling
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Cancelling...'),
                                ],
                              )
                            : const Text(
                                'Show Cancel Instructions',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Keep subscription button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xff66cc5d),
                          side: const BorderSide(color: Color(0xff66cc5d)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Actually, I\'ll Stay! 💚',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Small print
                    const Text(
                      'You\'ll still have access until the end of your current billing period.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black38,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildReasonItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
