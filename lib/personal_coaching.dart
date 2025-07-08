import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:image_picker/image_picker.dart';

class PersonalCoaching extends StatefulWidget {
  const PersonalCoaching({super.key});

  @override
  State<PersonalCoaching> createState() => _PersonalCoachingState();
}

class _PersonalCoachingState extends State<PersonalCoaching> {
  List<String> attachments = [];

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Coaching'),
        actions: <Widget>[
          IconButton(
            onPressed: send,
            icon: const Icon(Icons.send),
          )
        ],
      ),
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xffF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xffE9ECEF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'What You\'ll Get:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff1782FF),
                    ),
                  ),
                  SizedBox(height: 12),
                  _BenefitItem(
                    icon: Icons.psychology,
                    title: 'Personalized Strategy',
                    description: 'Custom approach tailored to your specific situation and goals',
                  ),
                  _BenefitItem(
                    icon: Icons.schedule,
                    title: 'Weekly Sessions',
                    description: 'Regular check-ins to keep you accountable and on track',
                  ),
                  _BenefitItem(
                    icon: Icons.support_agent,
                    title: 'Direct Access',
                    description: 'Priority support and guidance when you need it most',
                  ),
                  _BenefitItem(
                    icon: Icons.trending_up,
                    title: 'Accelerated Results',
                    description: 'Faster progress with expert guidance and proven methods',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Tell me about your goals:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xff555555),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Subject',
                ),
              ),
            ),
            SizedBox(
              height: 300,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _bodyController,
                  maxLines: 20,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: <Widget>[
                  const SizedBox(height: 16),
                  const Text(
                    'I\'ll respond within 24 hours to discuss your goals and how we can work together.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xff888888),
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
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

  void _openImagePicker() async {
    final picker = ImagePicker();
    XFile? pick = await picker.pickImage(source: ImageSource.gallery);
    if (pick != null) {
      setState(() {
        attachments.add(pick.path);
      });
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      attachments.removeAt(index);
    });
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