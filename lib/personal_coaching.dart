import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:life_ops/navbar.dart';

class PersonalCoaching extends StatefulWidget {
  const PersonalCoaching({super.key});

  @override
  State<PersonalCoaching> createState() => _PersonalCoachingState();
}

class _PersonalCoachingState extends State<PersonalCoaching> {
  List<String> attachments = [];
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  final _subjectController = TextEditingController(
    text: 'Personal Coaching Inquiry - Green Pyramid App User',
  );

  final _bodyController = TextEditingController(
    text: '''Hi Craig,

I'm interested in personal coaching with you. I've been using the Green Pyramid app and would like to take my progress to the next level with one-on-one guidance.

Here's a bit about me and what I'm looking to achieve:

[Please share your current situation, goals, and what specific areas you'd like to focus on]

I'm ready to invest in myself and make real changes. Looking forward to hearing from you!

Best regards,
[Your name]''',
  );

  @override
  void initState() {
    super.initState();
    analytics.logEvent(name: 'personal_coaching');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NavBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Get Coached by Craig',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xff1782FF),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Work directly with Craig as your personal coach to accelerate your transformation.',
              style: TextStyle(
                fontSize: 18,
                color: Color(0xff555555),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xffF8F9FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xffE9ECEF)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'What You\'ll Get:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff1782FF),
                    ),
                  ),
                  SizedBox(height: 16),
                  _BenefitItem(
                    icon: Icons.psychology,
                    title: 'Personalized Strategy',
                    description:
                        'Custom approach tailored to your specific situation and goals',
                  ),
                  SizedBox(height: 12),
                  _BenefitItem(
                    icon: Icons.schedule,
                    title: 'Weekly Sessions',
                    description:
                        'Regular check-ins to keep you accountable and on track',
                  ),
                  SizedBox(height: 12),
                  _BenefitItem(
                    icon: Icons.support_agent,
                    title: 'Direct Access',
                    description:
                        'Priority support and guidance when you need it most',
                  ),
                  SizedBox(height: 12),
                  _BenefitItem(
                    icon: Icons.trending_up,
                    title: 'Accelerated Results',
                    description:
                        'Faster progress with expert guidance and proven methods',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // New Schedule Call Button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xff1782FF),
                    Color(0xff66CC5D),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.video_call,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Are We A Fit?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Let\'s chat for 15 minutes to see if we\'re a good fit for working together.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openCalendlyBooking(context),
                      icon: const Icon(Icons.calendar_today,
                          color: Color(0xff1782FF)),
                      label: const Text(
                        'Book It',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff1782FF),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xff1782FF),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xffE9ECEF)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.email,
                        color: Color(0xff1782FF),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Or send me an email',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff1782FF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tell me about your goals:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff555555),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _subjectController,
                    decoration: InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xff1782FF), width: 2),
                      ),
                      filled: true,
                      fillColor: const Color(0xffF8F9FA),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: TextField(
                      controller: _bodyController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                        labelText: 'Message',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xff1782FF), width: 2),
                        ),
                        filled: true,
                        fillColor: const Color(0xffF8F9FA),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: send,
                      icon: const Icon(Icons.send, color: Colors.white),
                      label: const Text(
                        'Send Email',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff1782FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'I\'ll respond within 24 hours to discuss your goals and how we can work together.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xff888888),
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _openCalendlyBooking(BuildContext context) {
    analytics.logEvent(name: 'calendly_booking_opened');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CalendlyBookingScreen(),
      ),
    );
  }

  Future<void> send() async {
    final Email email = Email(
      body: _bodyController.text,
      subject: _subjectController.text,
      recipients: ['cglendenning123@gmail.com'],
      isHTML: false,
    );

    String platformResponse;

    try {
      await FlutterEmailSender.send(email);
      platformResponse = 'Email sent successfully!';
    } catch (error) {
      debugPrint(error.toString());
      platformResponse = error.toString();
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(platformResponse),
        backgroundColor: platformResponse.contains('successfully')
            ? const Color(0xff4CAF50)
            : Colors.red,
      ),
    );
  }
}

class CalendlyBookingScreen extends StatefulWidget {
  const CalendlyBookingScreen({super.key});

  @override
  State<CalendlyBookingScreen> createState() => _CalendlyBookingScreenState();
}

class _CalendlyBookingScreenState extends State<CalendlyBookingScreen> {
  late WebViewController _controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    final calendlyHtml = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    html, body {
      margin: 0;
      padding: 0;
      width: 100vw;
      height: 100vh;
      overflow-x: hidden;
      background: #fff;
    }
    .calendly-iframe {
      width: 100vw;
      height: 100vh;
      border: none;
      overflow-x: hidden;
      max-width: 100vw;
      box-sizing: border-box;
      display: block;
    }
  </style>
</head>
<body>
  <iframe
    src="https://calendly.com/c_glendenning/15min"
    class="calendly-iframe"
    allowfullscreen>
  </iframe>
</body>
</html>
''';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            // Allow all navigation within Calendly
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(calendlyHtml);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Schedule Your Free Call'),
        backgroundColor: const Color(0xff1782FF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (isLoading)
              const Center(
                child: CircularProgressIndicator(
                  color: Color(0xff1782FF),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xff1782FF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xff1782FF),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff333333),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xff666666),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
